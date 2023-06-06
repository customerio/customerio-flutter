package io.customer.customer_io

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Module class corresponds to modules concept in native SDKs. Any module added to native SDKs
 * should be treated as module in Flutter SDK and should be used to hold all relevant methods at
 * single place.
 */
internal interface CustomerIOPluginModule : MethodChannel.MethodCallHandler {
    /**
     * Unique name of module to identify between other modules
     */
    val moduleName: String

    /**
     * Flutter communication channel to communicate with Native SDK
     */
    val flutterCommunicationChannel: MethodChannel

    /**
     * Called whenever root FlutterPlugin has been associated with a FlutterEngine instance.
     *
     * @see [FlutterPlugin.onAttachedToEngine] for more details
     */
    fun onAttachedToEngine() {
        flutterCommunicationChannel.setMethodCallHandler(this)
    }

    /**
     * Called whenever root FlutterPlugin has been removed from a FlutterEngine instance.
     *
     * @see [FlutterPlugin.onDetachedFromEngine] for more details
     */
    fun onDetachedFromEngine() {
        flutterCommunicationChannel.setMethodCallHandler(null)
    }
}
