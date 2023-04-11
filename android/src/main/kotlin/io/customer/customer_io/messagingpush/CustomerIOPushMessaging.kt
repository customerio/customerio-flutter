package io.customer.customer_io.messagingpush

import android.content.Context
import io.customer.customer_io.CustomerIOPluginModule
import io.customer.customer_io.constant.Keys
import io.customer.customer_io.getAsTypeOrNull
import io.customer.customer_io.invokeNative
import io.customer.messagingpush.CustomerIOFirebaseMessagingService
import io.customer.sdk.CustomerIOShared
import io.customer.sdk.extensions.takeIfNotBlank
import io.customer.sdk.util.Logger
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

class CustomerIOPushMessaging(
    private val applicationContext: Context,
    messenger: BinaryMessenger,
) : CustomerIOPluginModule, MethodChannel.MethodCallHandler {
    override val moduleName: String = "PushMessaging"
    private val flutterCommunicationChannel = MethodChannel(messenger, "customer_io_messaging_push")

    private val logger: Logger
        get() = CustomerIOShared.instance().diStaticGraph.logger

    override fun onAttachedToEngine() {
        flutterCommunicationChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine() {
        flutterCommunicationChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
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

    private fun onMessageReceived(
        message: Map<String, Any>?,
        handleNotificationTrigger: Boolean?,
    ): Boolean {
        try {
            if (message == null) {
                throw IllegalArgumentException("Message cannot be null")
            }

            // Generate destination string, see docs on receiver method for more details
            val destination = (message["to"] as? String)?.takeIfNotBlank()
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
