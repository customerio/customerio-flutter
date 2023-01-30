package io.customer.customer_io

import android.app.Activity
import android.app.Application
import android.content.Context
import androidx.annotation.NonNull
import io.customer.customer_io.constant.Keys
import io.customer.messaginginapp.MessagingInAppModuleConfig
import io.customer.messaginginapp.ModuleMessagingInApp
import io.customer.messaginginapp.type.InAppEventListener
import io.customer.messaginginapp.type.InAppMessage
import io.customer.messagingpush.MessagingPushModuleConfig
import io.customer.messagingpush.ModuleMessagingPushFCM
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOConfig
import io.customer.sdk.CustomerIOShared
import io.customer.sdk.data.model.Region
import io.customer.sdk.extensions.getProperty
import io.customer.sdk.extensions.getString
import io.customer.sdk.extensions.takeIfNotBlank
import io.customer.sdk.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android implementation of plugin that will let Flutter developers to
 * interact with a Android platform
 * */
class CustomerIoPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var flutterCommunicationChannel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    private val logger: Logger
        get() = CustomerIOShared.instance().diStaticGraph.logger

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
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

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterCommunicationChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "customer_io")
        flutterCommunicationChannel.setMethodCallHandler(this)
    }

    private fun MethodCall.toNativeMethodCall(
        result: Result, performAction: (params: Map<String, Any>) -> Unit
    ) {
        try {
            val params = this.arguments as? Map<String, Any> ?: emptyMap()
            performAction(params)
            result.success(true)
        } catch (e: Exception) {
            result.error(this.method, e.localizedMessage, null)
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            Keys.Methods.INITIALIZE -> {
                call.toNativeMethodCall(result) {
                    initialize(it)
                }
            }
            Keys.Methods.IDENTIFY -> {
                call.toNativeMethodCall(result) {
                    identify(it)
                }
            }
            Keys.Methods.SCREEN -> {
                call.toNativeMethodCall(result) {
                    screen(it)
                }
            }
            Keys.Methods.TRACK -> {
                call.toNativeMethodCall(result) {
                    track(it)
                }
            }
            Keys.Methods.SET_DEVICE_ATTRIBUTES -> {
                call.toNativeMethodCall(result) {
                    setDeviceAttributes(it)
                }
            }
            Keys.Methods.SET_PROFILE_ATTRIBUTES -> {
                call.toNativeMethodCall(result) {
                    setProfileAttributes(it)
                }
            }
            Keys.Methods.CLEAR_IDENTIFY -> {
                clearIdentity()
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun clearIdentity() {
        CustomerIO.instance().clearIdentify()
    }

    private fun identify(params: Map<String, Any>) {
        val identifier = params.getString(Keys.Tracking.IDENTIFIER)
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()
        CustomerIO.instance().identify(identifier, attributes)
    }

    private fun track(params: Map<String, Any>) {
        val name = params.getString(Keys.Tracking.EVENT_NAME)
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        if (attributes.isEmpty()) {
            CustomerIO.instance().track(name)
        } else {
            CustomerIO.instance().track(name, attributes)
        }
    }

    private fun setDeviceAttributes(params: Map<String, Any>) {
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        CustomerIO.instance().deviceAttributes = attributes
    }

    private fun setProfileAttributes(params: Map<String, Any>) {
        val attributes = params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: return

        CustomerIO.instance().profileAttributes = attributes
    }

    private fun screen(params: Map<String, Any>) {
        val name = params.getString(Keys.Tracking.EVENT_NAME)
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        if (attributes.isEmpty()) {
            CustomerIO.instance().screen(name)
        } else {
            CustomerIO.instance().screen(name, attributes)
        }
    }

    private fun initialize(configData: Map<String, Any>) {
        val application: Application = context.applicationContext as Application
        val siteId = configData.getString(Keys.Environment.SITE_ID)
        val apiKey = configData.getString(Keys.Environment.API_KEY)
        val region = configData.getProperty<String>(
            Keys.Environment.REGION
        )?.takeIfNotBlank()
        val enableInApp = configData.getProperty<Boolean>(
            Keys.Environment.ENABLE_IN_APP
        )

        CustomerIO.Builder(
            siteId = siteId,
            apiKey = apiKey,
            region = Region.getRegion(region),
            appContext = application,
            config = configData
        ).apply {
            addCustomerIOModule(module = configureModuleMessagingPushFCM(configData))
            if (enableInApp == true) {
                addCustomerIOModule(
                    module = ModuleMessagingInApp(
                        config = MessagingInAppModuleConfig.Builder()
                            .setEventListener(CustomerIOInAppEventListener { method, args ->
                                this@CustomerIoPlugin.activity?.runOnUiThread {
                                    flutterCommunicationChannel.invokeMethod(method, args)
                                }
                            }).build(),
                    )
                )
            }
        }.build()
        logger.info("Customer.io instance initialized successfully")
    }

    private fun configureModuleMessagingPushFCM(config: Map<String, Any?>?): ModuleMessagingPushFCM {
        return ModuleMessagingPushFCM(
            config = MessagingPushModuleConfig.Builder().apply {
                config?.getProperty<Boolean>(CustomerIOConfig.Companion.Keys.AUTO_TRACK_PUSH_EVENTS)
                    ?.let { value ->
                        setAutoTrackPushEvents(autoTrackPushEvents = value)
                    }
            }.build(),
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterCommunicationChannel.setMethodCallHandler(null)
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
