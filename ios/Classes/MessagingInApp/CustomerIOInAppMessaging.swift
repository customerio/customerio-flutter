import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation

public class CustomerIOInAppMessaging: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private let logger: Logger = DIGraphShared.shared.logger
    private let inboxListener = FlutterNotificationInboxChangeListener.shared
    private var isInboxChangeListenerSetup = false

    private var inbox: NotificationInbox {
        MessagingInApp.shared.inbox
    }

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
        // Only set up once to avoid duplicate listeners
        guard !isInboxChangeListenerSetup else {
            return
        }

        // All listener setup must run on MainActor
        Task { @MainActor in
            inboxListener.setEventEmitter { [weak self] messages in
                guard let self = self else { return }
                self.invokeDartMethod("inboxMessagesChanged", ["messages": messages.map { $0.toDictionary() }])
            }
            self.inbox.addChangeListener(inboxListener)

            // Set flag after successful setup (allows retry if setup was called before SDK initialized)
            self.isInboxChangeListenerSetup = true
        }
    }

    private func clearInboxChangeListener() {
        guard isInboxChangeListenerSetup else {
            return
        }
        isInboxChangeListenerSetup = false

        // All listener cleanup must run on MainActor
        Task { @MainActor in
            self.inbox.removeChangeListener(inboxListener)
            inboxListener.clearEventEmitter()
        }
    }

    /// Subscribes to inbox messages updates.
    /// This sets up the native listener which will emit the current messages immediately,
    /// then emit again whenever messages change.
    private func subscribeToInboxMessages() {
        setupInboxChangeListener()
    }

    private func fetchInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
        guard let message = parseInboxMessage(from: call) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid message data", details: nil))
            return
        }

        inbox.markMessageOpened(message: message)
        result(true)
    }

    private func markInboxMessageUnopened(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let message = parseInboxMessage(from: call) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid message data", details: nil))
            return
        }

        inbox.markMessageUnopened(message: message)
        result(true)
    }

    private func markInboxMessageDeleted(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let message = parseInboxMessage(from: call) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid message data", details: nil))
            return
        }

        inbox.markMessageDeleted(message: message)
        result(true)
    }

    private func trackInboxMessageClicked(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let message = parseInboxMessage(from: call) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid message data", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let actionName = args?["actionName"] as? String
        inbox.trackMessageClicked(message: message, actionName: actionName)
        result(true)
    }

    // MARK: - Helper Methods

    func configureModule(params: [String: AnyHashable]) {
        if let inAppConfig = try? MessagingInAppConfigBuilder.build(from: params) {
            MessagingInApp.initialize(withConfig: inAppConfig)
            MessagingInApp.shared.setEventListener(CustomerIOInAppEventListener(invokeDartMethod: invokeDartMethod))
        } else {
            DIGraphShared.shared.logger.error("[InApp] Failed to initialize module: invalid config")
        }
    }

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
}

// MARK: - CustomerIOInAppMessaging Extension

extension CustomerIOInAppMessaging {
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
}
