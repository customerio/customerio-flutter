import CioMessagingInApp

class CustomerIOInAppEventListener {
    private let invokeDartMethod: (String, Any?) -> Void

    init(invokeDartMethod: @escaping (String, Any?) -> Void) {
        self.invokeDartMethod = invokeDartMethod
    }
}

extension CustomerIOInAppEventListener: InAppEventListener {
    func errorWithMessage(message: InAppMessage) {
        invokeDartMethod("errorWithMessage", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }

    func messageActionTaken(message: InAppMessage, actionValue: String, actionName: String) {
        invokeDartMethod("messageActionTaken", [
            "messageId": message.messageId,
            "deliveryId": message.deliveryId,
            "actionValue": actionValue,
            "actionName": actionName
        ])
    }

    func messageDismissed(message: InAppMessage) {
        invokeDartMethod("messageDismissed", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }

    func messageShown(message: InAppMessage) {
        invokeDartMethod("messageShown", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }
}
