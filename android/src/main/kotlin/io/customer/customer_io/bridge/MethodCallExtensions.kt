package io.customer.customer_io.bridge

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles native method call by transforming the arguments and invoking the handler.
 *
 * @param result The result object to send the response back to Flutter.
 * @param transformer A function to transform the incoming arguments.
 * @param handler A function to handle the transformed arguments and produce a result.
 *
 * - If the handler returns `Unit`, it sends `true` to Flutter to avoid errors.
 * - Catches and sends any exceptions as errors to Flutter.
 */
internal fun <Arguments, Result> MethodCall.native(
    result: MethodChannel.Result,
    transformer: (Any?) -> Arguments,
    handler: (Arguments) -> Result,
) = runCatching {
    val args = transformer(arguments)
    val response = handler(args)
    // If the result is Unit, then return true to the Flutter side
    // As returning Unit will throw an error on the Flutter side
    result.success(
        when (response) {
            is Unit -> true
            else -> response
        }
    )
}.onFailure { ex ->
    result.error(method, ex.localizedMessage, ex)
}

/**
 * Handles a native method call that requires no arguments.
 *
 * @param result The result object to send the response back to Flutter.
 * @param handler A function to handle the call and produce a result.
 */
internal fun <Result> MethodCall.nativeNoArgs(
    result: MethodChannel.Result,
    handler: () -> Result,
) = native(result, { }, { handler() })

/**
 * Handles a native method call with arguments passed as a map.
 *
 * @param result The result object to send the response back to Flutter.
 * @param handler A function to handle the map arguments and produce a result.
 */
@Suppress("UNCHECKED_CAST")
internal fun <Result> MethodCall.nativeMapArgs(
    result: MethodChannel.Result,
    handler: (Map<String, Any>) -> Result,
) = native(result, { it as? Map<String, Any> ?: emptyMap() }, handler)
