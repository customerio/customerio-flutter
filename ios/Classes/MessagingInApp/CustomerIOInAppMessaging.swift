import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation

public class CustomerIOInAppMessaging: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private let logger: Logger = DIGraphShared.shared.logger

    // Dedicated lock for inbox listener setup to prevent race conditions
    private let inboxListenerLock = NSLock()
    private var isInboxChangeListenerSetup = false

    public static func register(with _: FlutterPluginRegistrar) {}

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        methodChannel = FlutterMethodChannel(name: "customer_io_messaging_in_app", binaryMessenger: registrar.messenger())

        guard let methodChannel = methodChannel else {
            print("customer_io_messaging_in_app methodChannel is nil")
            return
        }

        registrar.addMethodCallDelegate(self, channel: methodChannel)

        // Register the platform view factory for inline in-app messages
        registrar.register(
            InlineInAppMessageViewFactory(messenger: registrar.messenger()),
            withId: "customer_io_inline_in_app_message_view"
        )
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
        clearInboxChangeListener()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle method calls for this method channel
        switch call.method {
        case "dismissMessage":
            call.nativeNoArgs(result: result) {
                MessagingInApp.shared.dismissMessage()
            }

        case "subscribeToInboxMessages":
            call.nativeNoArgs(result: result) {
                self.subscribeToInboxMessages()
            }

        case "fetchInboxMessages":
            fetchInboxMessages(call: call, result: result)

        case "markInboxMessageOpened":
            markInboxMessageOpened(call: call, result: result)

        case "markInboxMessageUnopened":
            markInboxMessageUnopened(call: call, result: result)

        case "markInboxMessageDeleted":
            markInboxMessageDeleted(call: call, result: result)

        case "trackInboxMessageClicked":
            trackInboxMessageClicked(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /**
     * Sets up the inbox change listener to receive real-time updates.
     * This method can be called multiple times safely and will only set up the listener once.
     * Note: Inbox must be available (SDK initialized) before this can succeed.
     */
    private func setupInboxChangeListener() {
        inboxListenerLock.lock()
        defer { inboxListenerLock.unlock() }

        // Only set up once to avoid duplicate listeners
        guard !isInboxChangeListenerSetup else {
            return
        }

        // Check if SDK is initialized before attempting setup
        guard let inbox = requireInboxInstance() else {
            return
        }

        // Set flag immediately (before Task completes) to prevent race condition.
        // Lock ensures this flag update is visible to concurrent calls, blocking duplicates.
        // Task operations don't throw, so flag won't be stuck in inconsistent state.
        isInboxChangeListenerSetup = true

        // All listener setup must run on MainActor
        Task { @MainActor in
            let listener = FlutterNotificationInboxChangeListener.shared
            listener.setEventEmitter { [weak self] messages in
                guard let self = self else { return }
                self.invokeDartMethod("inboxMessagesChanged", ["messages": messages.map { $0.toDictionary() }])
            }
            inbox.addChangeListener(listener)
        }
    }

    private func clearInboxChangeListener() {
        inboxListenerLock.lock()
        defer { inboxListenerLock.unlock() }

        guard isInboxChangeListenerSetup else {
            return
        }
        isInboxChangeListenerSetup = false

        // All listener cleanup must run on MainActor
        Task { @MainActor in
            let listener = FlutterNotificationInboxChangeListener.shared
            // Only remove if inbox available (use optional chaining)
            requireInboxInstance()?.removeChangeListener(listener)
            // Always clean up emitter and flag, even if inbox unavailable
            listener.clearEventEmitter()
        }
    }

    /// Subscribes to inbox messages updates.
    /// This sets up the native listener which will emit the current messages immediately,
    /// then emit again whenever messages change.
    private func subscribeToInboxMessages() {
        setupInboxChangeListener()
    }

    private func fetchInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let inbox = requireInboxInstance() else {
            result(FlutterError(
                code: "INBOX_NOT_AVAILABLE",
                message: "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.",
                details: nil
            ))
            return
        }

        // Setup listener if not already setup
        setupInboxChangeListener()

        // Fetch messages using async/await
        Task {
            // Fetch all messages without topic filter - filtering handled in Dart for consistency
            let messages = await inbox.getMessages(topic: nil)
            let messagesArray = messages.map { $0.toDictionary() }

            // Return result on main thread (Flutter method channels require this)
            await MainActor.run {
                result(messagesArray)
            }
        }
    }

    private func markInboxMessageOpened(call: FlutterMethodCall, result: @escaping FlutterResult) {
        performInboxMessageAction(call: call, result: result) { inbox, message in
            inbox.markMessageOpened(message: message)
        }
    }

    private func markInboxMessageUnopened(call: FlutterMethodCall, result: @escaping FlutterResult) {
        performInboxMessageAction(call: call, result: result) { inbox, message in
            inbox.markMessageUnopened(message: message)
        }
    }

    private func markInboxMessageDeleted(call: FlutterMethodCall, result: @escaping FlutterResult) {
        performInboxMessageAction(call: call, result: result) { inbox, message in
            inbox.markMessageDeleted(message: message)
        }
    }

    private func trackInboxMessageClicked(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let actionName = args?["actionName"] as? String

        performInboxMessageAction(call: call, result: result) { inbox, message in
            inbox.trackMessageClicked(message: message, actionName: actionName)
        }
    }

    func configureModule(params: [String: AnyHashable]) {
        if let inAppConfig = try? MessagingInAppConfigBuilder.build(from: params) {
            MessagingInApp.initialize(withConfig: inAppConfig)
            MessagingInApp.shared.setEventListener(CustomerIOInAppEventListener(invokeDartMethod: invokeDartMethod))
        } else {
            DIGraphShared.shared.logger.error("[InApp] Failed to initialize module: invalid config")
        }
    }

    // MARK: - Helper Methods

    func invokeDartMethod(_ method: String, _ args: Any?) {
        // When sending messages from native code to Flutter, it's required to do it on main thread.
        // Learn more:
        // * https://docs.flutter.dev/platform-integration/platform-channels#channels-and-platform-threading
        // * https://linear.app/customerio/issue/MBL-358/
        DIGraphShared.shared.threadUtil.runMain { [weak self] in
            guard let self else { return }

            self.methodChannel?.invokeMethod(method, arguments: args)
        }
    }

    /// Returns inbox instance if available, nil otherwise with error logging
    /// Note: Notification Inbox is only available after SDK is initialized
    private func requireInboxInstance() -> NotificationInbox? {
        guard MessagingInApp.shared.implementation != nil else {
            logger.error("Notification Inbox is not available. Ensure CustomerIO SDK is initialized.")
            return nil
        }
        return MessagingInApp.shared.inbox
    }

    /// Parses FlutterMethodCall to InboxMessage with error logging
    private func parseInboxMessage(from call: FlutterMethodCall) -> InboxMessage? {
        guard let args = call.arguments as? [String: Any],
              let messageMap = args["message"] as? [String: Any],
              let inboxMessage = InboxMessageFactory.fromDictionary(messageMap)
        else {
            logger.error("Invalid message data: \(call.arguments ?? "nil")")
            return nil
        }
        return inboxMessage
    }

    /// Helper to validate inbox availability and message data before performing a message action
    /// Returns early if inbox is unavailable or message data is invalid
    private func performInboxMessageAction(
        call: FlutterMethodCall,
        result: @escaping FlutterResult,
        action: (NotificationInbox, InboxMessage) -> Void
    ) {
        guard let inbox = requireInboxInstance() else {
            result(FlutterError(
                code: "INBOX_NOT_AVAILABLE",
                message: "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.",
                details: nil
            ))
            return
        }

        guard let inboxMessage = parseInboxMessage(from: call) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid message data", details: nil))
            return
        }

        action(inbox, inboxMessage)
        result(true)
    }
}
