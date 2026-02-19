package io.customer.customer_io.messaginginapp

import io.customer.messaginginapp.gist.data.model.InboxMessage
import io.customer.messaginginapp.inbox.NotificationInboxChangeListener

class FlutterNotificationInboxChangeListener private constructor() :
    NotificationInboxChangeListener {

    // Event emitter function to send events to React Native layer
    private var eventEmitter: ((Map<String, Any?>) -> Unit)? = null

    // Sets the event emitter function and message converter
    internal fun setEventEmitter(emitter: ((Map<String, Any?>) -> Unit)?) {
        this.eventEmitter = emitter
    }

    // Clears the event emitter to prevent memory leaks
    internal fun clearEventEmitter() {
        this.eventEmitter = null
    }

    private fun emitMessagesUpdate(messages: List<InboxMessage>) {
        // Get the emitter and converter, return early if not set
        val emitter = eventEmitter ?: return

        val payload = mapOf("messages" to messages.map { it.toMap() })
        emitter.invoke(payload)
    }

    override fun onMessagesChanged(messages: List<InboxMessage>) {
        emitMessagesUpdate(messages)
    }

    companion object {
        // Singleton instance with public visibility for direct access
        val instance: FlutterNotificationInboxChangeListener by lazy { FlutterNotificationInboxChangeListener() }
    }
}
