package io.customer.customer_io.messaginginapp

import io.customer.customer_io.CustomerIOPluginModule
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.getAsTypeOrNull
import io.customer.customer_io.invokeNative
import io.customer.messaginginapp.MessagingInAppModuleConfig
import io.customer.messaginginapp.ModuleMessagingInApp
import io.customer.messaginginapp.di.inAppMessaging
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.data.model.Region
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

    companion object {
        /**
         * Adds in-app module to native Android SDK based on the configuration provided by
         * customer app.
         *
         * @param builder instance of CustomerIOBuilder to add push messaging module.
         * @param config configuration provided by customer app for in-app messaging module.
         * @param region region of the customer app.
         */
        internal fun addNativeModuleFromConfig(
            builder: CustomerIOBuilder,
            config: Map<String, Any>,
            region: Region
        ) {
            val siteId = config.getAsTypeOrNull<String>("siteId")
            if (siteId.isNullOrBlank()) {
                SDKComponent.logger.error("Site ID is required to initialize InAppMessaging module")
                return
            }
            val module = ModuleMessagingInApp(
                MessagingInAppModuleConfig.Builder(siteId = siteId, region = region).build(),
            )
            builder.addCustomerIOModule(module)
        }
    }

}