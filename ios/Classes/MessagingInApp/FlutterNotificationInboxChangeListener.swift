import CioMessagingInApp
import Foundation

/// Singleton listener for inbox message changes that forwards updates via an event emitter
class FlutterNotificationInboxChangeListener: NotificationInboxChangeListener {
    // Singleton instance
    static let shared = FlutterNotificationInboxChangeListener()

    // Event emitter function to send events to Flutter layer
    private var eventEmitter: (([InboxMessage]) -> Void)?

    // Private initializer to enforce singleton pattern
    private init() {}

    /// Sets the event emitter function
    func setEventEmitter(_ emitter: @escaping ([InboxMessage]) -> Void) {
        eventEmitter = emitter
    }

    /// Clears the event emitter to prevent memory leaks
    func clearEventEmitter() {
        eventEmitter = nil
    }

    func onMessagesChanged(messages: [InboxMessage]) {
        eventEmitter?(messages)
    }
}
