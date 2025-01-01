package io.customer.customer_io

import android.app.Application
import android.content.Context
import androidx.annotation.NonNull
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.messaginginapp.CustomerIOInAppMessaging
import io.customer.customer_io.messagingpush.CustomerIOPushMessaging
import io.customer.customer_io.utils.getAs
import io.customer.datapipelines.config.ScreenView
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.CioLogLevel
import io.customer.sdk.core.util.Logger
import io.customer.sdk.data.model.Region
import io.customer.sdk.events.Metric
import io.customer.sdk.events.TrackMetric
import io.customer.sdk.events.serializedName
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
class CustomerIOPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var flutterCommunicationChannel: MethodChannel
    private lateinit var context: Context

    private lateinit var modules: List<NativeModuleBridge>

    private val logger: Logger = SDKComponent.logger

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

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "clearIdentify" -> call.nativeNoArgs(result, ::clearIdentify)
            "identify" -> call.nativeMapArgs(result, ::identify)
            "initialize" -> call.nativeMapArgs(result, ::initialize)
            "registerDeviceToken" -> call.nativeMapArgs(result, ::registerDeviceToken)
            "screen" -> call.nativeMapArgs(result, ::screen)
            "setDeviceAttributes" -> call.nativeMapArgs(result, ::setDeviceAttributes)
            "setProfileAttributes" -> call.nativeMapArgs(result, ::setProfileAttributes)
            "track" -> call.nativeMapArgs(result, ::track)
            "trackMetric" -> call.nativeMapArgs(result, ::trackMetric)
            else -> result.notImplemented()
        }
    }

    private fun clearIdentify() {
        CustomerIO.instance().clearIdentify()
    }

    private fun identify(params: Map<String, Any>) {
        val userId = params.getAs<String>(Args.USER_ID)
        val traits = params.getAs<Map<String, Any>>(Args.TRAITS) ?: emptyMap()

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
        val name = requireNotNull(params.getAs<String>(Args.NAME)) {
            "Event name is missing in params: $params"
        }
        val properties = params.getAs<Map<String, Any>>(Args.PROPERTIES)

        if (properties.isNullOrEmpty()) {
            CustomerIO.instance().track(name)
        } else {
            CustomerIO.instance().track(name, properties)
        }
    }

    private fun registerDeviceToken(params: Map<String, Any>) {
        val token = requireNotNull(params.getAs<String>(Args.TOKEN)) {
            "Device token is missing in params: $params"
        }
        CustomerIO.instance().registerDeviceToken(token)
    }

    private fun trackMetric(params: Map<String, Any>) {
        val deliveryId = params.getAs<String>(Args.DELIVERY_ID)
        val deliveryToken = params.getAs<String>(Args.DELIVERY_TOKEN)
        val eventName = params.getAs<String>(Args.METRIC_EVENT)

        if (deliveryId == null || deliveryToken == null || eventName == null) {
            throw IllegalArgumentException("Missing required parameters")
        }

        val event = Metric.values().find { it.serializedName.equals(eventName, true) }
            ?: throw IllegalArgumentException("Invalid metric event name")

        CustomerIO.instance().trackMetric(
            event = TrackMetric.Push(
                deliveryId = deliveryId,
                deviceToken = deliveryToken,
                metric = event
            )
        )
    }

    private fun setDeviceAttributes(params: Map<String, Any>) {
        val attributes = params.getAs<Map<String, Any>>(Args.ATTRIBUTES)

        if (attributes.isNullOrEmpty()) {
            logger.error("Device attributes are missing in params: $params")
            return
        }

        CustomerIO.instance().deviceAttributes = attributes
    }

    private fun setProfileAttributes(params: Map<String, Any>) {
        val attributes = params.getAs<Map<String, Any>>(Args.ATTRIBUTES)

        if (attributes.isNullOrEmpty()) {
            logger.error("Profile attributes are missing in params: $params")
            return
        }

        CustomerIO.instance().profileAttributes = attributes
    }

    private fun screen(params: Map<String, Any>) {
        val title = requireNotNull(params.getAs<String>(Args.TITLE)) {
            "Screen title is missing in params: $params"
        }
        val properties = params.getAs<Map<String, Any>>(Args.PROPERTIES)

        if (properties.isNullOrEmpty()) {
            CustomerIO.instance().screen(title)
        } else {
            CustomerIO.instance().screen(title, properties)
        }
    }

    private fun initialize(args: Map<String, Any>): kotlin.Result<Unit> = runCatching {
        val application: Application = context.applicationContext as Application
        val cdpApiKey = requireNotNull(args.getAs<String>("cdpApiKey")) {
            "CDP API Key is required to initialize Customer.io"
        }

        val logLevelRawValue = args.getAs<String>("logLevel")
        val regionRawValue = args.getAs<String>("region")
        val givenRegion = regionRawValue.let { Region.getRegion(it) }
        val screenViewRawValue = args.getAs<String>("screenViewUse")

        CustomerIOBuilder(
            applicationContext = application,
            cdpApiKey = cdpApiKey
        ).apply {
            logLevelRawValue?.let { logLevel(CioLogLevel.getLogLevel(it)) }
            regionRawValue?.let { region(givenRegion) }
            screenViewRawValue?.let { screenViewUse(ScreenView.getScreenView(it)) }

            args.getAs<String>("migrationSiteId")?.let(::migrationSiteId)
            args.getAs<Boolean>("autoTrackDeviceAttributes")?.let(::autoTrackDeviceAttributes)
            args.getAs<Boolean>("trackApplicationLifecycleEvents")
                ?.let(::trackApplicationLifecycleEvents)

            args.getAs<Int>("flushAt")?.let(::flushAt)
            args.getAs<Int>("flushInterval")?.let(::flushInterval)

            args.getAs<String>("apiHost")?.let(::apiHost)
            args.getAs<String>("cdnHost")?.let(::cdnHost)
            // Configure in-app messaging module based on config provided by customer app
            args.getAs<Map<String, Any>>(key = "inApp")?.let { inAppConfig ->
                modules.filterIsInstance<CustomerIOInAppMessaging>().forEach {
                    it.configureModule(
                        builder = this,
                        config = inAppConfig.plus("region" to givenRegion.code),
                    )
                }
            }
            // Configure push messaging module based on config provided by customer app
            args.getAs<Map<String, Any>>(key = "push").let { pushConfig ->
                modules.filterIsInstance<CustomerIOPushMessaging>().forEach {
                    it.configureModule(
                        builder = this,
                        config = pushConfig ?: emptyMap()
                    )
                }
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

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        modules.forEach {
            it.onAttachedToActivity(binding)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        modules.forEach {
            it.onDetachedFromActivityForConfigChanges()
        }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        modules.forEach {
            it.onReattachedToActivityForConfigChanges(binding)
        }
    }

    override fun onDetachedFromActivity() {
        modules.forEach {
            it.onDetachedFromActivity()
        }
    }

    companion object {
        object Args {
            const val ATTRIBUTES = "attributes"
            const val DELIVERY_ID = "deliveryId"
            const val DELIVERY_TOKEN = "deliveryToken"
            const val METRIC_EVENT = "metricEvent"
            const val NAME = "name"
            const val PROPERTIES = "properties"
            const val TITLE = "title"
            const val TOKEN = "token"
            const val TRAITS = "traits"
            const val USER_ID = "userId"
        }
    }
}
