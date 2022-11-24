package io.customer.customer_io

import android.app.Application
import android.content.Context
import androidx.annotation.NonNull
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.extension.*
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOShared
import io.customer.sdk.data.store.Client
import io.customer.sdk.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android implementation of plugin that will let Flutter developers to
 * interact with a Android platform
 * */
class CustomerIOPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var flutterCommunicationChannel: MethodChannel
    private lateinit var context: Context

    private val logger: Logger
        get() = CustomerIOShared.instance().diGraph.logger

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterCommunicationChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "customer_io")
        flutterCommunicationChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android-${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                initialize(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }


    private fun initialize(call: MethodCall, result: Result) {
        try {
            val application: Application = context.applicationContext as Application
            val configData = call.arguments as? Map<String, Any> ?: emptyMap()
            val siteId = configData.getString(Keys.Environment.SITE_ID)
            val apiKey = configData.getString(Keys.Environment.API_KEY)
            val region = configData.getProperty<String>(
                Keys.Environment.REGION
            )?.takeIfNotBlank().toRegion()

            CustomerIO.Builder(
                siteId = siteId,
                apiKey = apiKey,
                region = region,
                appContext = application,
            ).apply {
                setClient(client = getUserAgentClient(packageConfig = configData))
                setupConfig(configData)
            }.build()
            logger.info("Customer.io instance initialized successfully")
            result.success(true)
        } catch (e: Exception) {
            logger.error("Failed to initialize Customer.io instance from app, ${e.message}")
            result.error("FlutterSegmentException", e.localizedMessage, null);
        }
    }

    private fun getUserAgentClient(packageConfig: Map<String, Any?>?): Client {
        val sourceSDKVersion = packageConfig?.getProperty<String>(
            Keys.PackageConfig.SOURCE_SDK_VERSION
        )?.takeIfNotBlank() ?: "n/a"
        return Client.Flutter(sdkVersion = sourceSDKVersion)
    }

    private fun CustomerIO.Builder.setupConfig(config: Map<String, Any?>?): CustomerIO.Builder {
        if (config == null) return this

        val logLevel = config.getProperty<String>(Keys.Config.LOG_LEVEL).toCIOLogLevel()
        setLogLevel(level = logLevel)
        config.getProperty<String>(Keys.Config.TRACKING_API_URL)?.takeIfNotBlank()?.let { value ->
            setTrackingApiURL(value)
        }
        config.getProperty<Boolean>(Keys.Config.AUTO_TRACK_DEVICE_ATTRIBUTES)?.let { value ->
            autoTrackDeviceAttributes(shouldTrackDeviceAttributes = value)
        }
        config.getProperty<Double>(Keys.Config.BACKGROUND_QUEUE_MIN_NUMBER_OF_TASKS)?.let { value ->
            setBackgroundQueueMinNumberOfTasks(backgroundQueueMinNumberOfTasks = value.toInt())
        }
        config.getProperty<Double>(Keys.Config.BACKGROUND_QUEUE_SECONDS_DELAY)?.let { value ->
            setBackgroundQueueSecondsDelay(backgroundQueueSecondsDelay = value)
        }
        return this
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterCommunicationChannel.setMethodCallHandler(null)
    }
}
