package io.customer.customer_io.messaginginapp

import android.app.Activity
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.messaginginbox.InboxComponent
import io.customer.customer_io.messaginginbox.InboxViewTypes
import io.customer.customer_io.messaginginbox.NotificationInboxViewFactory
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.MessagingInAppModuleConfig
import io.customer.messaginginapp.ModuleMessagingInApp
import io.customer.messaginginapp.di.inAppMessaging
import io.customer.messaginginapp.gist.data.model.InboxMessage
import io.customer.messaginginapp.gist.data.model.response.InboxMessageFactory
import io.customer.messaginginapp.inbox.NotificationInbox
import io.customer.messaginginapp.type.InAppEventListener
import io.customer.messaginginapp.type.InAppMessage
import io.customer.messaginginapp.type.InboxEventListener
import io.customer.sdk.CustomerIO
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.customer.sdk.data.model.Region
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Flutter module implementation for messaging in-app module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOInAppMessaging(
    private val pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge, MethodChannel.MethodCallHandler, ActivityAware {
    override val moduleName: String = "InAppMessaging"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_messaging_in_app")
    private val logger: Logger = SDKComponent.logger
    private val inAppMessagingModule: ModuleMessagingInApp?
        get() = runCatching { CustomerIO.instance().inAppMessaging() }.getOrNull()
    private var activity: WeakReference<Activity>? = null
    private val binaryMessenger = pluginBinding.binaryMessenger
    private val platformViewRegistry = pluginBinding.platformViewRegistry

    // Dedicated lock for inbox listener setup to avoid blocking other operations
    private val inboxListenerLock = Any()
    private val inboxChangeListener = FlutterNotificationInboxChangeListener.instance
    private var isInboxChangeListenerSetup = false
    private var isInboxEventListenerRegistered = false

    /**
     * Returns NotificationInbox instance if available, null otherwise, logging error on failure.
     * Note: Notification Inbox is only available after SDK is initialized.
     */
    private fun requireInboxInstance(): NotificationInbox? {
        val inbox = inAppMessagingModule?.inbox()
        if (inbox == null) {
            logger.error("Notification Inbox is not available. Ensure CustomerIO SDK is initialized.")
        }
        return inbox
    }

    override fun onAttachedToEngine() {
        super.onAttachedToEngine()

        // Register the platform view factory for inline in-app messages
        platformViewRegistry.registerViewFactory(
            "customer_io_inline_in_app_message_view",
            InlineInAppMessageViewFactory(binaryMessenger)
        )

        // Register the platform view factories for the Visual Notification Inbox UI components.
        platformViewRegistry.registerViewFactory(
            InboxViewTypes.BELL,
            NotificationInboxViewFactory(binaryMessenger, InboxComponent.BELL)
        )
        platformViewRegistry.registerViewFactory(
            InboxViewTypes.VIEW,
            NotificationInboxViewFactory(binaryMessenger, InboxComponent.VIEW)
        )
    }

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

    override fun onDetachedFromEngine() {
        clearInboxChangeListener()
        clearInboxEventListener()
        super.onDetachedFromEngine()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "dismissMessage" -> call.nativeNoArgs(result, ::dismissMessage)
            "subscribeToInboxMessages" -> setupInboxChangeListener(call, result)
            "getInboxMessages" -> getInboxMessages(call, result)
            "markInboxMessageOpened" -> call.nativeMapArgs(result, ::markInboxMessageOpened)
            "markInboxMessageUnopened" -> call.nativeMapArgs(result, ::markInboxMessageUnopened)
            "markInboxMessageDeleted" -> call.nativeMapArgs(result, ::markInboxMessageDeleted)
            "trackInboxMessageClicked" -> call.nativeMapArgs(result, ::trackInboxMessageClicked)
            "registerInboxEventListener" -> registerInboxEventListener(result)
            "unregisterInboxEventListener" -> unregisterInboxEventListener(result)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun dismissMessage() {
        inAppMessagingModule?.dismissMessage()
    }

    /**
     * Registers the inbox event forwarder on the SDK while a Dart listener is set.
     * Because the Flutter MethodChannel is async we cannot round-trip a Dart bool
     * back to the SDK's calling thread, so the forwarder reports actions as
     * host-handled (returns true) which suppresses the SDK's default navigation.
     */
    private fun registerInboxEventListener(result: MethodChannel.Result) {
        val module = inAppMessagingModule ?: run {
            result.error(
                "INBOX_NOT_AVAILABLE",
                "In-app messaging module is not available. Ensure CustomerIO SDK is initialized.",
                null
            )
            return
        }
        module.setInboxEventListener(CustomerIOInboxEventListener { method, args ->
            runOnMainThread {
                flutterCommunicationChannel.invokeMethod(method, args)
            }
        })
        synchronized(inboxListenerLock) { isInboxEventListenerRegistered = true }
        result.success(null)
    }

    /**
     * Clears the Dart-backed inbox forwarder by installing a no-op listener whose
     * [InboxEventListener.messageActionTaken] returns false, restoring the SDK's
     * default action handling. (The native API takes a non-null listener.)
     */
    private fun unregisterInboxEventListener(result: MethodChannel.Result) {
        clearInboxEventListener()
        result.success(null)
    }

    /**
     * Restores the SDK's default inbox action handling by installing the no-op listener.
     *
     * Also called on engine detach: the Dart-backed forwarder reports every action as host-handled,
     * so leaving it installed once the engine is gone would suppress the SDK's own navigation with
     * nothing on the Flutter side left to replace it. Only clears a forwarder this plugin instance
     * installed, so an engine that never used the inbox cannot disable another engine's listener.
     */
    private fun clearInboxEventListener() {
        synchronized(inboxListenerLock) {
            if (!isInboxEventListenerRegistered) {
                return
            }
            inAppMessagingModule?.setInboxEventListener(NoOpInboxEventListener)
            isInboxEventListenerRegistered = false
        }
    }

    /**
     * Adds in-app module to native Android SDK based on the configuration provided by
     * customer app.
     *
     * @param builder instance of CustomerIOBuilder to add push messaging module.
     * @param config configuration provided by customer app for in-app messaging module.
     */
    override fun configureModule(
        builder: CustomerIOBuilder,
        config: Map<String, Any>
    ) {
        val siteId = config.getAs<String>("siteId")
        val regionRawValue = config.getAs<String>("region")
        val givenRegion = regionRawValue.let { Region.getRegion(it) }

        if (siteId.isNullOrBlank()) {
            SDKComponent.logger.error("Site ID is required to initialize InAppMessaging module")
            return
        }
        val module = ModuleMessagingInApp(
            MessagingInAppModuleConfig.Builder(siteId = siteId, region = givenRegion)
                .setEventListener(CustomerIOInAppEventListener { method, args ->
                    this.activity?.get()?.runOnUiThread {
                        flutterCommunicationChannel.invokeMethod(method, args)
                    }
                })
                .build(),
        )
        builder.addCustomerIOModule(module)
    }

    /**
     * Sets up the inbox change listener to receive real-time updates.
     * This method can be called multiple times safely and will only set up the listener once.
     * Note: Inbox must be available (SDK initialized) before this can succeed.
     */
    private fun setupInboxChangeListener(call: MethodCall, result: MethodChannel.Result) {
        synchronized(inboxListenerLock) {
            // Only set up once to avoid duplicate listeners
            if (isInboxChangeListenerSetup) {
                result.success(true)
                return
            }

            val inbox = requireInboxInstance() ?: run {
                result.error("INBOX_NOT_AVAILABLE", "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.", null)
                return
            }

            inboxChangeListener.setEventEmitter(
                emitter = { data ->
                    runOnMainThread {
                        flutterCommunicationChannel.invokeMethod("inboxMessagesChanged", data)
                    }
                }
            )
            inbox.addChangeListener(inboxChangeListener)
            isInboxChangeListenerSetup = true
            logger.debug("NotificationInboxChangeListener set up successfully")
            result.success(true)
        }
    }

    private fun clearInboxChangeListener() {
        synchronized(inboxListenerLock) {
            if (!isInboxChangeListenerSetup) {
                return
            }
            requireInboxInstance()?.removeChangeListener(inboxChangeListener)
            inboxChangeListener.clearEventEmitter()
            isInboxChangeListenerSetup = false
        }
    }

    private fun getInboxMessages(call: MethodCall, result: MethodChannel.Result) {
        val inbox = requireInboxInstance() ?: run {
            result.error("INBOX_NOT_AVAILABLE", "Notification Inbox is not available. Ensure CustomerIO SDK is initialized.", null)
            return
        }

        // Extract topic parameter if provided
        val args = call.arguments as? Map<String, Any>
        val topic = args?.get("topic") as? String

        // Fetch messages with topic filter
        // Using async callback avoids blocking main thread (prevents ANR/deadlocks)
        inbox.fetchMessages(topic) { fetchResult ->
            runOnMainThread {
                fetchResult.onSuccess { messages ->
                    result.success(messages.map { it.toMap() })
                }.onFailure { error ->
                    logger.error("Failed to get inbox messages: ${error.message}")
                    result.error("FETCH_ERROR", error.message, null)
                }
            }
        }
    }

    private fun markInboxMessageOpened(params: Map<String, Any>) {
        val message = params.getAs<Map<String, Any>>("message")

        performInboxMessageAction(message) { inbox, inboxMessage ->
            inbox.markMessageOpened(inboxMessage)
        }
    }

    private fun markInboxMessageUnopened(params: Map<String, Any>) {
        val message = params.getAs<Map<String, Any>>("message")

        performInboxMessageAction(message) { inbox, inboxMessage ->
            inbox.markMessageUnopened(inboxMessage)
        }
    }

    private fun markInboxMessageDeleted(params: Map<String, Any>) {
        val message = params.getAs<Map<String, Any>>("message")

        performInboxMessageAction(message) { inbox, inboxMessage ->
            inbox.markMessageDeleted(inboxMessage)
        }
    }

    private fun trackInboxMessageClicked(params: Map<String, Any>) {
        val message = params.getAs<Map<String, Any>>("message")
        val actionName = params.getAs<String>("actionName")

        performInboxMessageAction(message) { inbox, inboxMessage ->
            inbox.trackMessageClicked(inboxMessage, actionName)
        }
    }

    /**
     * Runs block on main/UI thread. Uses activity's runOnUiThread if available,
     * otherwise falls back to Handler(Looper.getMainLooper()).post
     */
    private fun runOnMainThread(block: () -> Unit) {
        val currentActivity = activity?.get()
        if (currentActivity != null) {
            currentActivity.runOnUiThread(block)
        } else {
            // Activity is null - use main looper directly
            android.os.Handler(android.os.Looper.getMainLooper()).post(block)
        }
    }

    /**
     * Helper to validate inbox instance and message data before performing a message action.
     * Throws exceptions if inbox is unavailable or message data is invalid.
     */
    private fun performInboxMessageAction(
        message: Map<String, Any>?,
        action: (NotificationInbox, InboxMessage) -> Unit,
    ) {
        val inbox = requireInboxInstance()
            ?: throw IllegalStateException("Notification Inbox is not available. Ensure CustomerIO SDK is initialized.")
        val inboxMessage = message?.let { InboxMessageFactory.fromMap(it) }
            ?: throw IllegalArgumentException("Invalid message data: $message")
        action(inbox, inboxMessage)
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

/**
 * Forwards Visual Notification Inbox events to Flutter. Registered on the SDK only while a Dart
 * listener is set. `messageActionTaken` forwards fire-and-forget and returns true (host-handled) so
 * the SDK suppresses its default navigation while the Flutter host owns action handling.
 * Uses distinct method names so they don't collide with the in-app callbacks on the shared channel.
 */
class CustomerIOInboxEventListener(private val invokeMethod: (String, Any?) -> Unit) :
    InboxEventListener {
    override fun messageActionTaken(
        message: InboxMessage, actionName: String, actionValue: String
    ): Boolean {
        invokeMethod(
            "inboxMessageActionTaken", mapOf(
                "message" to message.toMap(),
                "actionName" to actionName,
                "actionValue" to actionValue
            )
        )
        // Host (Flutter) owns action handling while a listener is registered.
        return true
    }

    override fun messageShown(message: InboxMessage) {
        invokeMethod("inboxMessageShown", mapOf("message" to message.toMap()))
    }

    override fun messageOpened(message: InboxMessage) {
        invokeMethod("inboxMessageOpened", mapOf("message" to message.toMap()))
    }

    override fun messageDismissed(message: InboxMessage) {
        invokeMethod("inboxMessageDismissed", mapOf("message" to message.toMap()))
    }
}

/**
 * No-op inbox listener used to clear the Dart forwarder. Returning false from
 * [messageActionTaken] restores the SDK's default action handling.
 */
private object NoOpInboxEventListener : InboxEventListener {
    override fun messageActionTaken(
        message: InboxMessage, actionName: String, actionValue: String
    ): Boolean = false
}
