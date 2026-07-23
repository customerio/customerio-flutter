package io.customer.customer_io.liveactivities

import android.graphics.Color
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.utils.getAs
import io.customer.messagingpush.MessagingPushModuleConfig
import io.customer.messagingpush.ModuleMessagingPushFCM
import io.customer.messagingpush.livenotification.LiveNotificationAsset
import io.customer.messagingpush.livenotification.LiveNotificationBranding
import io.customer.messagingpush.livenotification.LiveNotificationData
import io.customer.messagingpush.livenotification.LiveNotificationType
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter module implementation for Live Activities / Live Notifications.
 *
 * Live Notifications are hosted by the FCM push module ([ModuleMessagingPushFCM]); this bridge maps
 * the wrapper's template payloads to [LiveNotificationData] and forwards them at runtime. The module
 * *config* (enabled templates, custom types, branding) is applied onto the same
 * [MessagingPushModuleConfig] the push module builds (see [applyLiveActivitiesConfig]); this handler
 * therefore does not add a module of its own.
 */
// Public so host apps can register a custom Live Notification render callback via
// [setLiveNotificationCallback]; the constructor stays internal (the plugin owns instantiation).
class CustomerIOLiveActivities internal constructor(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge, MethodChannel.MethodCallHandler {
    override val moduleName: String = "LiveActivities"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_live_activities")
    private val logger: Logger = SDKComponent.logger

    // Live Notifications are hosted by the FCM push module. Reach it via the module registry
    // (the SDK-internal MODULE_NAME constant is not accessible, so use the literal value).
    private fun getPushModule(): ModuleMessagingPushFCM? = runCatching {
        SDKComponent.modules[PUSH_FCM_MODULE_NAME] as? ModuleMessagingPushFCM
    }.onFailure {
        logger.error("Live Notifications: push module is not initialized. Ensure the SDK is initialized with live activity templates enabled.")
    }.getOrNull()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> call.nativeMapArgs(result, ::start)
            "update" -> call.nativeMapArgs(result, ::update)
            "end" -> call.nativeMapArgs(result, ::end)
            "startCustom" -> call.nativeMapArgs(result, ::startCustom)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun start(args: Map<String, Any>): String {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val payload = requireNotNull(args.getAs<Map<String, Any>>("payload")) {
            "payload is required"
        }
        return module.startLiveNotification(parseData(payload))
    }

    private fun update(args: Map<String, Any>) {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val activityId = requireNotNull(args.getAs<String>("activityId")) {
            "activityId is required"
        }
        val payload = requireNotNull(args.getAs<Map<String, Any>>("payload")) {
            "payload is required"
        }
        module.updateLiveNotification(activityId, parseData(payload))
    }

    private fun end(args: Map<String, Any>) {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val activityId = requireNotNull(args.getAs<String>("activityId")) {
            "activityId is required"
        }
        module.endLiveNotification(activityId)
    }

    private fun startCustom(args: Map<String, Any>): String {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val activityType = requireNotNull(args.getAs<String>("activityType")) {
            "activityType is required"
        }
        val data = args.getAs<Map<String, Any>>("data") ?: emptyMap()
        return module.startLiveNotification(activityType, data)
    }

    private fun parseData(payload: Map<String, Any>): LiveNotificationData {
        return when (val type = payload.getAs<String>("type")) {
            "segments" -> LiveNotificationData.Segments(
                header = payload.requireString("header"),
                status = payload.requireString("status"),
                substatus = payload.getAs<String>("substatus"),
                segmentsTotal = payload.requireInt("segmentsTotal"),
                segmentsComplete = payload.requireInt("segmentsComplete"),
                trailingText = payload.getAs<String>("trailingText"),
            )

            "countdownTimer" -> LiveNotificationData.CountdownTimer(
                header = payload.requireString("header"),
                title = payload.requireString("title"),
                statusMessage = payload.getAs<String>("statusMessage"),
                endTime = payload.getAs<Number>("endTime")?.toLong(),
            )

            else -> throw IllegalArgumentException("Unknown live activity template type: $type")
        }
    }

    private fun Map<String, Any>.requireString(key: String): String =
        requireNotNull(getAs<String>(key)) { "$key is required" }

    private fun Map<String, Any>.requireInt(key: String): Int =
        requireNotNull(getAs<Number>(key)) { "$key is required" }.toInt()

    /**
     * No-op: Live Notification configuration is applied onto the FCM push module's config builder
     * via [applyLiveActivitiesConfig] rather than by adding a separate module.
     */
    override fun configureModule(builder: CustomerIOBuilder, config: Map<String, Any>) {}

    companion object {
        private const val PUSH_FCM_MODULE_NAME = "MessagingPushFCM"
        private const val MODULE_UNAVAILABLE =
            "Live Notifications are unavailable. Enable live activity templates in the SDK config."

        /**
         * App-provided callback used to render custom (app-defined) Live Notifications. The native
         * push callback can only be set at SDK build time, so the host app must register this
         * *before* initializing the Customer.io SDK from Dart; it is then applied onto the push
         * module's config in [applyLiveActivitiesConfig].
         */
        @Volatile
        private var liveNotificationCallback:
            io.customer.messagingpush.data.communication.CustomerIOPushNotificationCallback? = null

        /**
         * Registers the callback used to render custom Live Notifications. Must be called before the
         * Customer.io SDK is initialized from Dart.
         */
        @JvmStatic
        fun setLiveNotificationCallback(
            callback: io.customer.messagingpush.data.communication.CustomerIOPushNotificationCallback,
        ) {
            liveNotificationCallback = callback
        }

        /**
         * Applies live activity configuration onto the FCM push module's config builder. Live
         * Notifications are hosted by [ModuleMessagingPushFCM], so their config (enabled templates,
         * custom types, branding) is set on the same [MessagingPushModuleConfig].
         *
         * @param builder the push module's config builder.
         * @param config the `liveActivities` config map from the customer app.
         */
        internal fun applyLiveActivitiesConfig(
            builder: MessagingPushModuleConfig.Builder,
            config: Map<String, Any>,
        ) {
            // Custom live notifications require the host app to render them; apply the callback the
            // app registered before SDK init (see [setLiveNotificationCallback]).
            liveNotificationCallback?.let { builder.setNotificationCallback(it) }

            val templateTypes = config.getAs<List<*>>("templates")
                ?.mapNotNull { it as? String }
                ?.mapNotNull { name ->
                    when (name) {
                        "segments" -> LiveNotificationType.SEGMENTS
                        "countdownTimer" -> LiveNotificationType.COUNTDOWN_TIMER
                        else -> null
                    }
                }
                .orEmpty()
            if (templateTypes.isNotEmpty()) {
                builder.enableLiveNotificationTypes(*templateTypes.toTypedArray())
            }

            val customTypes = config.getAs<List<*>>("customTypes")
                ?.mapNotNull { it as? String }
                .orEmpty()
            if (customTypes.isNotEmpty()) {
                builder.enableCustomLiveNotificationTypes(*customTypes.toTypedArray())
            }

            val branding = config.getAs<Map<String, Any>>("branding")
            if (branding != null) {
                val accentColor = branding.getAs<String>("accentColorHex")
                    ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
                    ?: Color.TRANSPARENT
                val logoUrl = branding.getAs<String>("logoUrl")
                val smallIcon = branding.getAs<String>("smallIconResource")
                    ?.let { name ->
                        val context = SDKComponent.android().applicationContext
                        context.resources
                            .getIdentifier(name, "drawable", context.packageName)
                            .takeIf { it != 0 }
                    }
                builder.setLiveNotificationBranding(
                    LiveNotificationBranding(
                        companyName = branding.getAs<String>("companyName").orEmpty(),
                        accentColor = accentColor,
                        smallIcon = smallIcon,
                        logo = logoUrl?.let { LiveNotificationAsset.RemoteUrl(it) },
                    ),
                )
            }
        }
    }
}
