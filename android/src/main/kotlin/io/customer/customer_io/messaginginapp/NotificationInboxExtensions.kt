package io.customer.customer_io.messaginginapp

import io.customer.messaginginapp.gist.data.model.InboxMessage

// Extension functions for InboxMessage serialization
internal fun InboxMessage.toMap(): Map<String, Any?> {
    return mapOf(
        "queueId" to queueId,
        "deliveryId" to deliveryId,
        "expiry" to expiry?.time,
        "sentAt" to sentAt.time,
        "topics" to topics,
        "type" to type,
        "opened" to opened,
        "priority" to priority,
        "properties" to properties
    )
}
