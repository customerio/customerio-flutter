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
class CustomerIoPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var flutterCommunicationChannel: MethodChannel
    private lateinit var context: Context

    private val logger: Logger
        get() = CustomerIOShared.instance().diStaticGraph.logger

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterCommunicationChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "customer_io")
        flutterCommunicationChannel.setMethodCallHandler(this)
    }

    private fun MethodCall.toNativeMethodCall(
        result: Result,
        performAction: (params: Map<String, Any>) -> Unit
    ) {
        try {
            val params = this.arguments as? Map<String, Any> ?: emptyMap()
            performAction(params)
            result.success(true)
        } catch (e: Exception) {
            result.error(this.method, e.localizedMessage, null);
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

    fun track(params: Map<String, Any>) {
        val name = params.getString(Keys.Tracking.EVENT_NAME)
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        if (attributes.isEmpty()) {
            CustomerIO.instance().track(name)
        } else {
            CustomerIO.instance().track(name, attributes)
        }
    }

    fun setDeviceAttributes(params: Map<String, Any>) {
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        CustomerIO.instance().deviceAttributes = attributes
    }

    fun setProfileAttributes(params: Map<String, Any>) {
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: return

        CustomerIO.instance().profileAttributes = attributes
    }

    fun screen(params: Map<String, Any>) {
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
        config.getProperty<Int>(Keys.Config.BACKGROUND_QUEUE_MIN_NUMBER_OF_TASKS)?.let { value ->
            setBackgroundQueueMinNumberOfTasks(backgroundQueueMinNumberOfTasks = value)
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
