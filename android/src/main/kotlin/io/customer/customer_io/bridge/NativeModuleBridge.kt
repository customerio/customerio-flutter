package io.customer.customer_io.bridge

import io.customer.sdk.CustomerIOBuilder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Module class corresponds to modules concept in native SDKs. Any module added to native SDKs
 * should be treated as module in Flutter SDK and should be used to hold all relevant methods at
 * single place.
 */
internal interface NativeModuleBridge : MethodChannel.MethodCallHandler, ActivityAware {
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

    /**
     * Handles incoming method calls from Flutter and invokes the appropriate native method handler.
     * If the method is not implemented, the result is marked as not implemented.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    fun configureModule(builder: CustomerIOBuilder, config: Map<String, Any>)

    override fun onDetachedFromActivity() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {}
}
