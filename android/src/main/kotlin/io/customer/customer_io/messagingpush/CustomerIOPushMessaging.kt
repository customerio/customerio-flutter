package io.customer.customer_io.messagingpush

import android.content.Context
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.utils.getAs
import io.customer.customer_io.utils.takeIfNotBlank
import io.customer.messagingpush.CustomerIOFirebaseMessagingService
import io.customer.messagingpush.MessagingPushModuleConfig
import io.customer.messagingpush.ModuleMessagingPushFCM
import io.customer.messagingpush.config.PushClickBehavior
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Flutter module implementation for messaging push module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOPushMessaging(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge, MethodChannel.MethodCallHandler {
    override val moduleName: String = "PushMessaging"
    private val applicationContext: Context = pluginBinding.applicationContext
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_messaging_push")
    private val logger: Logger = SDKComponent.logger

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRegisteredDeviceToken" -> call.nativeNoArgs(result, ::getRegisteredDeviceToken)
            "onMessageReceived" -> call.nativeMapArgs(result, ::onMessageReceived)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun getRegisteredDeviceToken(): String? {
        return CustomerIO.instance().registeredDeviceToken
    }

    /**
     * Handles push notification received. This is helpful in processing push notifications
     * received outside the CIO SDK.
     */
    private fun onMessageReceived(args: Map<String, Any>): Boolean {
        try {
            // Push payload received from FCM
            val message = args.getAs<Map<String, Any>>("message")
            // Flag to indicate if local notification should be triggered
            val handleNotificationTrigger = args.getAs<Boolean>("handleNotificationTrigger")

            if (message == null) {
                throw IllegalArgumentException("Message cannot be null")
            }

            // Generate destination string, see docs on receiver method for more details
            val destination =
                (message["to"] as? String)?.takeIfNotBlank() ?: UUID.randomUUID().toString()
            return CustomerIOFirebaseMessagingService.onMessageReceived(
                context = applicationContext,
                remoteMessage = message.toFCMRemoteMessage(destination = destination),
                handleNotificationTrigger = handleNotificationTrigger ?: true,
            )
        } catch (ex: Throwable) {
            logger.error("Unable to handle push notification, reason: ${ex.message}")
            throw ex
        }
    }

    /**
     * Adds push messaging module to native Android SDK based on the configuration provided by
     * customer app.
     *
     * @param builder instance of CustomerIOBuilder to add push messaging module.
     * @param config configuration provided by customer app for push messaging module.
     */
    override fun configureModule(
        builder: CustomerIOBuilder,
        config: Map<String, Any>
    ) {
        val androidConfig = config.getAs<Map<String, Any>>(key = "android") ?: emptyMap()
        // Prefer `android` object for push configurations as it's more specific to Android
        // For common push configurations, use `config` object instead of `android`

        // Default push click behavior is to prevent restart of activity in Flutter apps
        val pushClickBehavior = androidConfig.getAs<String>("pushClickBehavior")
            ?.takeIfNotBlank()
            ?.let { value ->
                runCatching { enumValueOf<PushClickBehavior>(value) }.getOrNull()
            } ?: PushClickBehavior.ACTIVITY_PREVENT_RESTART

        val module = ModuleMessagingPushFCM(
            moduleConfig = MessagingPushModuleConfig.Builder().apply {
                setPushClickBehavior(pushClickBehavior = pushClickBehavior)
            }.build(),
        )
        builder.addCustomerIOModule(module)
    }
}
