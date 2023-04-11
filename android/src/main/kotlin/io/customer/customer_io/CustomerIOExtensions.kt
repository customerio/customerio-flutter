package io.customer.customer_io

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
