package io.customer.customer_io.messaginginapp

import android.app.Activity
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.MessagingInAppModuleConfig
import io.customer.messaginginapp.ModuleMessagingInApp
import io.customer.messaginginapp.di.inAppMessaging
import io.customer.messaginginapp.type.InAppEventListener
import io.customer.messaginginapp.type.InAppMessage
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.data.model.Region
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Flutter module implementation for messaging in-app module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOInAppMessaging(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge, MethodChannel.MethodCallHandler, ActivityAware {
    override val moduleName: String = "InAppMessaging"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_messaging_in_app")
    private var activity: WeakReference<Activity>? = null

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dismissMessage" -> call.nativeNoArgs(result, ::dismissMessage)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun dismissMessage() {
        CustomerIO.instance().inAppMessaging().dismissMessage()
    }

    /**
     * Adds in-app module to native Android SDK based on the configuration provided by
     * customer app.
     *
     * @param builder instance of CustomerIOBuilder to add push messaging module.
     * @param config configuration provided by customer app for in-app messaging module.
     */
    override fun configureModule(
        builder: CustomerIOBuilder,
        config: Map<String, Any>
    ) {
        val siteId = config.getAs<String>("siteId")
        val regionRawValue = config.getAs<String>("region")
        val givenRegion = regionRawValue.let { Region.getRegion(it) }

        if (siteId.isNullOrBlank()) {
            SDKComponent.logger.error("Site ID is required to initialize InAppMessaging module")
            return
        }
        val module = ModuleMessagingInApp(
            MessagingInAppModuleConfig.Builder(siteId = siteId, region = givenRegion)
                .setEventListener(CustomerIOInAppEventListener { method, args ->
                    this.activity?.get()?.runOnUiThread {
                        flutterCommunicationChannel.invokeMethod(method, args)
                    }
                })
                .build(),
        )
        builder.addCustomerIOModule(module)
    }
}

class CustomerIOInAppEventListener(private val invokeMethod: (String, Any?) -> Unit) :
    InAppEventListener {
    override fun errorWithMessage(message: InAppMessage) {
        invokeMethod(
            "errorWithMessage", mapOf(
                "messageId" to message.messageId, "deliveryId" to message.deliveryId
            )
        )
    }

    override fun messageActionTaken(
        message: InAppMessage, actionValue: String, actionName: String
    ) {
        invokeMethod(
            "messageActionTaken", mapOf(
                "messageId" to message.messageId,
                "deliveryId" to message.deliveryId,
                "actionValue" to actionValue,
                "actionName" to actionName
            )
        )
    }

    override fun messageDismissed(message: InAppMessage) {
        invokeMethod(
            "messageDismissed", mapOf(
                "messageId" to message.messageId, "deliveryId" to message.deliveryId
            )
        )
    }

    override fun messageShown(message: InAppMessage) {
        invokeMethod(
            "messageShown", mapOf(
                "messageId" to message.messageId, "deliveryId" to message.deliveryId
            )
        )
    }
}