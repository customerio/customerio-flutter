package io.customer.customer_io.messagingpush

import com.google.firebase.messaging.RemoteMessage

/**
 * Returns the value corresponding to the given key after casting to the
 * generic type provided, or null if such a key is not present in the map
 * or cannot be casted to the given type.
 */
internal inline fun <reified T> Map<String, Any>.getAsTypeOrNull(key: String): T? {
    if (containsKey(key)) {
        return get(key) as? T
    }
    return null
}

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
    val notification = getAsTypeOrNull<Map<String, Any>>("notification")
    val data = getAsTypeOrNull<Map<String, Any>>("data")
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
        getAsTypeOrNull<String>("messageId")?.let { id -> setMessageId(id) }
        getAsTypeOrNull<String>("messageType")?.let { type -> setMessageType(type) }
        getAsTypeOrNull<String>("collapseKey")?.let { key -> setCollapseKey(key) }
        getAsTypeOrNull<Int>("ttl")?.let { time -> ttl = time }
        return@with build()
    }
}
