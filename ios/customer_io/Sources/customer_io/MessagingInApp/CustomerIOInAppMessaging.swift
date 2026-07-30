import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation

public class CustomerIOInAppMessaging: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private let logger: Logger = DIGraphShared.shared.logger

    // Task that consumes the inbox messages stream. Storing the task prevents duplicate streams
    // and allows proper cleanup via cancellation.
    private var messagesStreamTask: Task<Void, Never>?

    // The forwarder THIS plugin instance installed on the SDK, or nil if it has none installed.
    // Compared by identity against `InstalledInboxForwarder.current` so teardown only clears a
    // forwarder that is both ours and still the one the SDK holds. A plain "did I register" flag
    // cannot express that: the SDK keeps a single process-wide listener, so a second engine
    // registering silently replaces the first engine's forwarder while the first engine's flag stays
    // set — and its later deinit would then wipe the live listener out from under the second engine.
    private var myInboxForwarder: CustomerIOInboxEventListener?

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

        // Register the platform view factories for the Visual Notification Inbox UI components.
        registrar.register(
            NotificationInboxBellViewFactory(messenger: registrar.messenger()),
            withId: "customer_io_notification_inbox_bell_view"
        )
        registrar.register(
            NotificationInboxViewFactory(messenger: registrar.messenger()),
            withId: "customer_io_notification_inbox_view"
        )
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
        messagesStreamTask?.cancel()
        messagesStreamTask = nil
        // The forwarder reports every action as host-handled, so leaving it installed after the
        // engine is torn down would suppress the SDK's own navigation with no Flutter side left to
        // handle it. Restore default handling here, the iOS equivalent of Android's engine detach.
        clearInboxEventListener()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle method calls for this method channel
        switch call.method {
        case "dismissMessage":
            call.nativeNoArgs(result: result) {
                MessagingInApp.shared.dismissMessage()
            }

        case "subscribeToInboxMessages":
            subscribeToInboxMessages(call: call, result: result)

        case "getInboxMessages":
            getInboxMessages(call: call, result: result)

        case "markInboxMessageOpened":
            markInboxMessageOpened(call: call, result: result)

        case "markInboxMessageUnopened":
            markInboxMessageUnopened(call: call, result: result)

        case "markInboxMessageDeleted":
            markInboxMessageDeleted(call: call, result: result)

        case "trackInboxMessageClicked":
            trackInboxMessageClicked(call: call, result: result)

        case "registerInboxEventListener":
            registerInboxEventListener(result: result)

        case "unregisterInboxEventListener":
            clearInboxEventListener()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Registers the inbox event forwarder on the SDK while a Dart listener is set.
    ///
    /// Because the Flutter MethodChannel is async we cannot round-trip a Dart bool back to the SDK's
    /// calling thread, so the forwarder reports actions as host-handled (returns `true`), which
    /// suppresses the SDK's default navigation.
    ///
    /// Fails with `INBOX_NOT_AVAILABLE` when the module has not been initialized, matching Android.
    /// `MessagingInApp.setInboxEventListener` forwards through `implementation?`, so without this
    /// check a registration made before `CustomerIO.initialize` would report success to Dart, install
    /// nothing, and never deliver an event — with no retry and nothing to signal the listener is dead.
    private func registerInboxEventListener(result: @escaping FlutterResult) {
        guard MessagingInApp.shared.hasBeenInitialized else {
            result(FlutterError(
                code: "INBOX_NOT_AVAILABLE",
                message: "In-app messaging module is not available. Ensure CustomerIO SDK is initialized.",
                details: nil
            ))
            return
        }

        // `[weak self]` is load-bearing: the SDK holds the listener strongly, so passing
        // `invokeDartMethod` directly would have the listener retain this plugin for the life of
        // the process. `deinit` would then never run, and neither would the teardown that
        // restores the SDK's default action handling.
        let forwarder = CustomerIOInboxEventListener { [weak self] method, args in
            self?.invokeDartMethod(method, args)
        }
        InstalledInboxForwarder.lock.lock()
        MessagingInApp.shared.setInboxEventListener(forwarder)
        InstalledInboxForwarder.current = forwarder
        myInboxForwarder = forwarder
        InstalledInboxForwarder.lock.unlock()
        result(nil)
    }

    /// Restores the SDK's default inbox action handling.
    ///
    /// Clears only when this instance's forwarder is the one the SDK currently holds, which keeps two
    /// cases from stepping on a working listener: an engine that never registered cannot restore
    /// default handling for an engine that did (Dart's `setInboxEventListener(null)` always reaches
    /// native), and an engine whose forwarder was already superseded cannot uninstall its replacement
    /// on the way out.
    private func clearInboxEventListener() {
        InstalledInboxForwarder.lock.lock()
        defer { InstalledInboxForwarder.lock.unlock() }

        guard let mine = myInboxForwarder else { return }
        myInboxForwarder = nil
        // Superseded by another engine's forwarder: that engine still owns action handling.
        guard InstalledInboxForwarder.current === mine else { return }
        MessagingInApp.shared.setInboxEventListener(nil)
        InstalledInboxForwarder.current = nil
    }

    /// Subscribes to inbox messages updates using AsyncStream.
    /// This sets up a stream that emits the current messages immediately,
    /// then emits again whenever messages change.
    /// This method can be called multiple times safely and will only set up the stream once.
    private func subscribeToInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Only set up once to avoid duplicate streams
        guard messagesStreamTask == nil else {
            result(true)
            return
        }

        guard let inbox = requireInboxInstance() else {
            result(FlutterError(
                code: "INBOX_NOT_AVAILABLE",
                message: "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.",
                details: nil
            ))
            return
        }

        // Consume messages stream asynchronously
        messagesStreamTask = Task { [weak self] in
            for await messages in inbox.messages(topic: nil) {
                guard let self = self else { return }

                // Emit messages to Flutter
                self.invokeDartMethod("inboxMessagesChanged", ["messages": messages.map { $0.toDictionary() }])
            }
        }
        result(true)
    }

    private func getInboxMessages(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let inbox = requireInboxInstance() else {
            result(FlutterError(
                code: "INBOX_NOT_AVAILABLE",
                message: "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.",
                details: nil
            ))
            return
        }

        // Extract topic parameter if provided
        let args = call.arguments as? [String: Any]
        let topic = args?["topic"] as? String

        // Fetch messages using async/await
        Task {
            do {
                let messages = try await inbox.getMessages(topic: topic)
                let messagesArray = messages.map { $0.toDictionary() }

                // Return result on main thread (Flutter method channels require this)
                await MainActor.run {
                    result(messagesArray)
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(
                        code: "FETCH_ERROR",
                        message: "Failed to fetch inbox messages: \(error.localizedDescription)",
                        details: nil
                    ))
                }
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
            // `[weak self]` for the same reason as the inbox forwarder in `handle`: the SDK retains
            // its event listener strongly, so passing `invokeDartMethod` directly would keep this
            // plugin alive for the life of the process and prevent `deinit` from ever running.
            MessagingInApp.shared.setEventListener(
                CustomerIOInAppEventListener { [weak self] method, args in
                    self?.invokeDartMethod(method, args)
                }
            )
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

/// Process-wide record of the inbox forwarder currently installed on the SDK, or nil when the SDK has
/// its own default action handling.
///
/// Deliberately file-scoped rather than per-plugin-instance state: `MessagingInApp` holds one listener
/// for the whole process, so ownership of that single slot has to be tracked somewhere every Flutter
/// engine can see. The SDK exposes only a setter — there is no way to ask it which listener is
/// installed — so the wrapper keeps the record itself.
///
/// `lock` guards both the record and the SDK setter call, since engines can register from different
/// threads. `current` holds the forwarder strongly, which the SDK already does too; the forwarder
/// captures its plugin instance weakly, so this adds no lifetime of its own.
private enum InstalledInboxForwarder {
    static let lock = NSLock()
    static var current: CustomerIOInboxEventListener?
}
