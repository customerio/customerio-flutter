package io.customer.customer_io.messagingpush

import android.content.Context
import io.customer.customer_io.CustomerIOPluginModule
import io.customer.customer_io.constant.Keys
import io.customer.messagingpush.CustomerIOFirebaseMessagingService
import io.customer.sdk.CustomerIOShared
import io.customer.sdk.extensions.takeIfNotBlank
import io.customer.sdk.util.Logger
import java.util.*

class CustomerIOPushMessaging(
    private val applicationContext: Context,
) : CustomerIOPluginModule {
    override val moduleName: String = "PushMessaging"

    private val logger: Logger
        get() = CustomerIOShared.instance().diStaticGraph.logger

    override fun onMethodCallInvoked(methodName: String): (params: Map<String, Any>) -> Any {
        when (methodName) {
            Keys.Methods.ON_MESSAGE_RECEIVED -> {
                return { arguments ->
                    onMessageReceived(
                        message = arguments.getAsTypeOrNull<Map<String, Any>>("message"),
                        handleNotificationTrigger = arguments.getAsTypeOrNull<Boolean>("handleNotificationTrigger")
                    )
                }
            }
            else -> return super.onMethodCallInvoked(methodName)
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
