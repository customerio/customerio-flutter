package io.customer.customer_io.messagingpush

import android.content.Context
import io.customer.customer_io.CustomerIOPluginModule
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.getAsTypeOrNull
import io.customer.customer_io.invokeNative
import io.customer.messagingpush.CustomerIOFirebaseMessagingService
import io.customer.sdk.CustomerIO
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Flutter module implementation for messaging push module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOPushMessaging(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : CustomerIOPluginModule, MethodChannel.MethodCallHandler {
    override val moduleName: String = "PushMessaging"
    private val applicationContext: Context = pluginBinding.applicationContext
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_messaging_push")
    private val logger: Logger = SDKComponent.logger

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Keys.Methods.GET_REGISTERED_DEVICE_TOKEN -> {
                call.invokeNative(result) {
                    return@invokeNative getRegisteredDeviceToken()
                }
            }
            Keys.Methods.ON_MESSAGE_RECEIVED -> {
                call.invokeNative(result) { args ->
                    return@invokeNative onMessageReceived(
                        message = args.getAsTypeOrNull<Map<String, Any>>("message"),
                        handleNotificationTrigger = args.getAsTypeOrNull<Boolean>("handleNotificationTrigger")
                    )
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getRegisteredDeviceToken(): String? {
        return CustomerIO.instance().registeredDeviceToken
    }

    /**
     * Handles push notification received. This is helpful in processing push notifications
     * received outside the CIO SDK.
     *
     * @param message push payload received from FCM.
     * @param handleNotificationTrigger indicating if the local notification should be triggered.
     */
    private fun onMessageReceived(
        message: Map<String, Any>?,
        handleNotificationTrigger: Boolean?,
    ): Boolean {
        try {
            if (message == null) {
                throw IllegalArgumentException("Message cannot be null")
            }

            // Generate destination string, see docs on receiver method for more details
            val destination = (message["to"] as? String)?.takeIf { it.isNotBlank() }
                ?: UUID.randomUUID().toString()
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
}
