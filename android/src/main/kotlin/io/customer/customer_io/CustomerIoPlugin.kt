package io.customer.customer_io

import android.app.Application
import android.content.Context
import androidx.annotation.NonNull
import io.customer.customer_io.constant.Keys
import io.customer.messaginginapp.ModuleMessagingInApp
import io.customer.messagingpush.MessagingPushModuleConfig
import io.customer.messagingpush.ModuleMessagingPushFCM
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOShared
import io.customer.sdk.SharedWrapperKeys
import io.customer.sdk.data.store.Client
import io.customer.sdk.extensions.*
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

    private fun registerDeviceToken(params: Map<String, Any>) {
        val token = params.getString(Keys.Tracking.TOKEN)
        CustomerIO.instance().registerDeviceToken(token)
    }

    private fun trackMetric(params: Map<String, Any>) {
        val deliveryId = params.getString(Keys.Tracking.DELIVERY_ID)
        val deliveryToken = params.getString(Keys.Tracking.DELIVERY_TOKEN)
        val event = params.getString(Keys.Tracking.METRIC_EVENT).toMetricEvent()

        if (event == null) {
            logger.info("metric event type isn't correct")
            return
        }

        CustomerIO.instance().trackMetric(
            deliveryID = deliveryId,
            deviceToken = deliveryToken,
            event = event
        )
    }

    private fun setDeviceAttributes(params: Map<String, Any>) {
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: emptyMap()

        CustomerIO.instance().deviceAttributes = attributes
    }

    private fun setProfileAttributes(params: Map<String, Any>) {
        val attributes =
            params.getProperty<Map<String, Any>>(Keys.Tracking.ATTRIBUTES) ?: return

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
        val builder = configData.getCustomerIOBuilder(application)

        val organizationId = configData.getProperty<String>(
            SharedWrapperKeys.Environment.ORGANIZATION_ID
        )?.takeIfNotBlank()

        builder.apply {
            setClient(client = getUserAgentClient(packageConfig = configData))
            addCustomerIOModule(module = configureModuleMessagingPushFCM(configData))
            if (!organizationId.isNullOrBlank()) {
                addCustomerIOModule(
                    module = ModuleMessagingInApp(
                        organizationId = organizationId,
                    )
                )
            }
        }.build()
        logger.info("Customer.io instance initialized successfully")
    }

    private fun configureModuleMessagingPushFCM(config: Map<String, Any?>?): ModuleMessagingPushFCM {
        return ModuleMessagingPushFCM(
            config = MessagingPushModuleConfig.Builder().apply {
                config?.getProperty<Boolean>(SharedWrapperKeys.Config.AUTO_TRACK_PUSH_EVENTS)
                    ?.let { value ->
                        setAutoTrackPushEvents(autoTrackPushEvents = value)
                    }
            }.build(),
        )
    }

    private fun getUserAgentClient(packageConfig: Map<String, Any?>?): Client {
        val sourceSDKVersion = packageConfig?.getProperty<String>(
            SharedWrapperKeys.PackageConfig.SOURCE_SDK_VERSION
        )?.takeIfNotBlank() ?: "n/a"
        return Client.Flutter(sdkVersion = sourceSDKVersion)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterCommunicationChannel.setMethodCallHandler(null)
    }
}
