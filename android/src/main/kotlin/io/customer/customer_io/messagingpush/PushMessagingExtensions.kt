package io.customer.customer_io.messagingpush

import com.google.firebase.messaging.RemoteMessage
import io.customer.customer_io.utils.getAs

/**
 * Safely transforms any value to string
 */
private fun Any.toStringOrNull(): String? = try {
    toString()
} catch (ex: Exception) {
    // We don't need to print any error here as this is expected for some values and doesn't
    // break anything
    null
}

/**
 * Extension function to build FCM [RemoteMessage] using RN map. This should be independent from
 * the sender source and should be able to build a valid [RemoteMessage] for our native SDK.
 *
 * @param destination receiver of the message. It is mainly required for sending upstream messages,
 * since we are using RemoteMessage only for broadcasting messages locally, we can use any non-empty
 * string for it.
 */
internal fun Map<String, Any>.toFCMRemoteMessage(destination: String): RemoteMessage {
    val notification = getAs<Map<String, Any>>("notification")
    val data = getAs<Map<String, Any>>("data")
    val messageParams = buildMap {
        notification?.let { result -> putAll(result) }
        // Adding `data` after `notification` so `data` params take more value as we mainly use
        // `data` in rich push
        data?.let { result -> putAll(result) }
    }
    return with(RemoteMessage.Builder(destination)) {
        messageParams.let { params ->
            val paramsIterator = params.iterator()
            while (paramsIterator.hasNext()) {
                val (key, value) = paramsIterator.next()
                // Some values in notification object can be another object and may not support
                // mapping to string values, transforming these values in a try-catch so the code
                // doesn't break due to one bad value
                value.toStringOrNull()?.let { v -> addData(key, v) }
            }
        }
        getAs<String>("messageId")?.let { id -> setMessageId(id) }
        getAs<String>("messageType")?.let { type -> setMessageType(type) }
        getAs<String>("collapseKey")?.let { key -> setCollapseKey(key) }
        getAs<Int>("ttl")?.let { time -> ttl = time }
        return@with build()
    }
}
