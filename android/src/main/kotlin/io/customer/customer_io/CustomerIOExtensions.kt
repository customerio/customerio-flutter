package io.customer.customer_io

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
 * Invokes matching native method in lambda. The lambda parameter receives parameter as arguments
 * and should return the desired result to be passed on to the caller. Any exception in the lambda
 * will result in passing failure in result.
 */
internal fun <R> MethodCall.invokeNative(
    result: MethodChannel.Result,
    performAction: (params: Map<String, Any>) -> R,
) {
    try {
        @Suppress("UNCHECKED_CAST")
        val params = this.arguments as? Map<String, Any> ?: emptyMap()
        result.success(performAction(params))
    } catch (ex: Exception) {
        result.error(this.method, ex.localizedMessage, ex)
    }
}
