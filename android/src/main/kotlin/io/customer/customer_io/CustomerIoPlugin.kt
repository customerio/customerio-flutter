package io.customer.customer_io

import android.app.Activity
import android.app.Application
import android.content.Context
import androidx.annotation.NonNull
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.messaginginapp.CustomerIOInAppMessaging
import io.customer.customer_io.messagingpush.CustomerIOPushMessaging
import io.customer.messaginginapp.type.InAppEventListener
import io.customer.messaginginapp.type.InAppMessage
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.CioLogLevel
import io.customer.sdk.core.util.Logger
import io.customer.sdk.data.model.Region
import io.customer.sdk.events.Metric
import io.customer.sdk.events.TrackMetric
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.lang.ref.WeakReference

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
    private var activity: WeakReference<Activity>? = null

    private lateinit var modules: List<CustomerIOPluginModule>

    private val logger: Logger = SDKComponent.logger

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

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterCommunicationChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "customer_io")
        flutterCommunicationChannel.setMethodCallHandler(this)

        // Initialize modules
        modules = listOf(
            CustomerIOPushMessaging(flutterPluginBinding),
            CustomerIOInAppMessaging(flutterPluginBinding)
        )

        // Attach modules to engine
        modules.forEach {
            it.onAttachedToEngine()
        }
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

            Keys.Methods.TRACK_METRIC -> {
                call.toNativeMethodCall(result) {
                    trackMetric(it)
                }
            }

            Keys.Methods.REGISTER_DEVICE_TOKEN -> {
                call.toNativeMethodCall(result) {
                    registerDeviceToken(it)
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
        val userId = params.getAsTypeOrNull<String>(Keys.Tracking.USER_ID)
        val traits = params.getAsTypeOrNull<Map<String, Any>>(Keys.Tracking.TRAITS) ?: emptyMap()

        if (userId == null && traits.isEmpty()) {
            logger.error("Please provide either an ID or traits to identify.")
            return
        }

        if (userId != null && traits.isNotEmpty()) {
            CustomerIO.instance().identify(userId, traits)
        } else if (userId != null) {
            CustomerIO.instance().identify(userId)
        } else {
            CustomerIO.instance().profileAttributes = traits
        }
    }

    private fun track(params: Map<String, Any>) {
        val name = requireNotNull(params.getAsTypeOrNull<String>(Keys.Tracking.NAME)) {
            "Event name is missing in params: $params"
        }
        val properties = params.getAsTypeOrNull<Map<String, Any>>(Keys.Tracking.PROPERTIES)

        if (properties.isNullOrEmpty()) {
            CustomerIO.instance().track(name)
        } else {
            CustomerIO.instance().track(name, properties)
        }
    }

    private fun registerDeviceToken(params: Map<String, Any>) {
        val token = requireNotNull(params.getAsTypeOrNull<String>(Keys.Tracking.TOKEN)) {
            "Device token is missing in params: $params"
        }
        CustomerIO.instance().registerDeviceToken(token)
    }

    private fun trackMetric(params: Map<String, Any>) {
        val deliveryId = params.getAsTypeOrNull<String>(Keys.Tracking.DELIVERY_ID)
        val deliveryToken = params.getAsTypeOrNull<String>(Keys.Tracking.DELIVERY_TOKEN)
        val eventName = params.getAsTypeOrNull<String>(Keys.Tracking.METRIC_EVENT)

        if (deliveryId == null || deliveryToken == null || eventName == null) {
            throw IllegalArgumentException("Missing required parameters")
        }

        val event = Metric.valueOf(eventName)

        CustomerIO.instance().trackMetric(
            event = TrackMetric.Push(
                deliveryId = deliveryId,
                deviceToken = deliveryToken,
                metric = event
            )
        )
    }

    private fun setDeviceAttributes(params: Map<String, Any>) {
        val attributes = params.getAsTypeOrNull<Map<String, Any>>(Keys.Tracking.ATTRIBUTES)

        if (attributes.isNullOrEmpty()) {
            logger.error("Device attributes are missing in params: $params")
            return
        }

        CustomerIO.instance().deviceAttributes = attributes
    }

    private fun setProfileAttributes(params: Map<String, Any>) {
        val attributes = params.getAsTypeOrNull<Map<String, Any>>(Keys.Tracking.ATTRIBUTES)

        if (attributes.isNullOrEmpty()) {
            logger.error("Profile attributes are missing in params: $params")
            return
        }

        CustomerIO.instance().profileAttributes = attributes
    }

    private fun screen(params: Map<String, Any>) {
        val title = requireNotNull(params.getAsTypeOrNull<String>(Keys.Tracking.TITLE)) {
            "Screen title is missing in params: $params"
        }
        val properties = params.getAsTypeOrNull<Map<String, Any>>(Keys.Tracking.PROPERTIES)

        if (properties.isNullOrEmpty()) {
            CustomerIO.instance().screen(title)
        } else {
            CustomerIO.instance().screen(title, properties)
        }
    }

    private fun initialize(args: Map<String, Any>): kotlin.Result<Unit> = runCatching {
        val application: Application = context.applicationContext as Application
        val cdpApiKey = requireNotNull(args.getAsTypeOrNull<String>("cdpApiKey")) {
            "CDP API Key is required to initialize Customer.io"
        }

        val logLevelRawValue = args.getAsTypeOrNull<String>("logLevel")
        val regionRawValue = args.getAsTypeOrNull<String>("region")
        val givenRegion = regionRawValue.let { Region.getRegion(it) }

        CustomerIOBuilder(
            applicationContext = application,
            cdpApiKey = cdpApiKey
        ).apply {
            logLevelRawValue?.let { logLevel(CioLogLevel.getLogLevel(it)) }
            regionRawValue?.let { region(givenRegion) }

            args.getAsTypeOrNull<String>("migrationSiteId")?.let(::migrationSiteId)
            args.getAsTypeOrNull<Boolean>("autoTrackDeviceAttributes")
                ?.let(::autoTrackDeviceAttributes)
            args.getAsTypeOrNull<Boolean>("trackApplicationLifecycleEvents")
                ?.let(::trackApplicationLifecycleEvents)

            args.getAsTypeOrNull<Int>("flushAt")?.let(::flushAt)
            args.getAsTypeOrNull<Int>("flushInterval")?.let(::flushInterval)

            args.getAsTypeOrNull<String>("apiHost")?.let(::apiHost)
            args.getAsTypeOrNull<String>("cdnHost")?.let(::cdnHost)
            // Configure in-app messaging module based on config provided by customer app
            args.getAsTypeOrNull<Map<String, Any>>(key = "inApp")?.let { inAppConfig ->
                CustomerIOInAppMessaging.addNativeModuleFromConfig(
                    builder = this,
                    config = inAppConfig,
                    region = givenRegion
                )
            }
            // Configure push messaging module based on config provided by customer app
            args.getAsTypeOrNull<Map<String, Any>>(key = "push").let { pushConfig ->
                CustomerIOPushMessaging.addNativeModuleFromConfig(
                    builder = this,
                    config = pushConfig ?: emptyMap()
                )
            }
        }.build()

        logger.info("Customer.io instance initialized successfully from app")
    }.onFailure { ex ->
        logger.error("Failed to initialize Customer.io instance from app, ${ex.message}")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterCommunicationChannel.setMethodCallHandler(null)

        modules.forEach {
            it.onDetachedFromEngine()
        }
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
