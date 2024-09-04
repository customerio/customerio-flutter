package io.customer.customer_io

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Returns the value corresponding to the given key after casting to the generic type provided, or
 * null if such key is not present in the map or value cannot be casted to the given type.
 */
internal inline fun <reified T> Map<String, Any>.getAsTypeOrNull(key: String): T? {
    if (containsKey(key)) {
        return get(key) as? T
    }
    return null
}

/**
 * Invokes lambda method that can be used to call matching native method conveniently. The lambda
 * expression receives function parameters as arguments and should return the desired result. Any
 * exception in the lambda will cause the invoked method to fail with error.
 */
internal fun <R> MethodCall.invokeNative(
    result: MethodChannel.Result,
    performAction: (params: Map<String, Any>) -> R,
) {
    try {
        @Suppress("UNCHECKED_CAST")
        val params = this.arguments as? Map<String, Any> ?: emptyMap()
        val actionResult = performAction(params)
        if (actionResult is Unit) {
            result.success(true)
        } else {
            result.success(actionResult)
        }
    } catch (ex: Exception) {
        result.error(this.method, ex.localizedMessage, ex)
    }
}
