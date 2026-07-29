import CioMessagingInApp

/// Forwards Visual Notification Inbox events from the native SDK to Flutter.
///
/// Registered on the SDK only while a Dart `InboxEventListener` is set (via the
/// `registerInboxEventListener` method call). Because the Flutter MethodChannel
/// is asynchronous, we cannot block the SDK's calling thread to await a Dart
/// bool. Instead `messageActionTaken` forwards the event fire-and-forget and
/// RETURNS `true` — telling the SDK the host handled the action, so the SDK
/// suppresses its default navigation. The Flutter host owns action handling
/// while a listener is registered. Observational callbacks forward
/// fire-and-forget.
class CustomerIOInboxEventListener {
    private let invokeDartMethod: (String, Any?) -> Void

    init(invokeDartMethod: @escaping (String, Any?) -> Void) {
        self.invokeDartMethod = invokeDartMethod
    }
}

extension CustomerIOInboxEventListener: InboxEventListener {
    func messageActionTaken(message: InboxMessage, actionName: String, actionValue: String) -> Bool {
        invokeDartMethod("inboxMessageActionTaken", [
            "message": message.toDictionary(),
            "actionName": actionName,
            "actionValue": actionValue
        ])
        // Host (Flutter) owns action handling while a listener is registered.
        return true
    }

    func messageShown(message: InboxMessage) {
        invokeDartMethod("inboxMessageShown", ["message": message.toDictionary()])
    }

    func messageOpened(message: InboxMessage) {
        invokeDartMethod("inboxMessageOpened", ["message": message.toDictionary()])
    }

    func messageDismissed(message: InboxMessage) {
        invokeDartMethod("inboxMessageDismissed", ["message": message.toDictionary()])
    }
}
