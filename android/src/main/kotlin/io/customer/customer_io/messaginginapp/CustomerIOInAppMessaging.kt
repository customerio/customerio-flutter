package io.customer.customer_io.messaginginapp

import io.customer.customer_io.CustomerIOPluginModule
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.invokeNative
import io.customer.messaginginapp.di.inAppMessaging
import io.customer.sdk.CustomerIO
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter module implementation for messaging in-app module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOInAppMessaging(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : CustomerIOPluginModule, MethodChannel.MethodCallHandler {
    override val moduleName: String = "InAppMessaging"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_messaging_in_app")

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Keys.Methods.DISMISS_MESSAGE -> {
                call.invokeNative(result) {
                    CustomerIO.instance().inAppMessaging().dismissMessage()
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

}