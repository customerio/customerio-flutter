package io.customer.customer_io.liveactivities

import android.graphics.Color
import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.utils.getAs
import io.customer.messagingpush.MessagingPushModuleConfig
import io.customer.messagingpush.ModuleMessagingPushFCM
import io.customer.messagingpush.di.pushModuleConfig
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
    //
    // Deliberately not runCatching: `as?` yields null instead of throwing, so a failure branch keyed
    // on a thrown error would never run and the message below would never be logged.
    private fun getPushModule(): ModuleMessagingPushFCM? {
        val module = SDKComponent.modules[PUSH_FCM_MODULE_NAME] as? ModuleMessagingPushFCM
        if (module == null) {
            logger.error("Live Notifications: push module is not initialized. Ensure the SDK is initialized with live activity templates enabled.")
        }
        return module
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // `start` is handled with the raw result rather than [nativeMapArgs] so it can report a
            // type that isn't enabled under the same error code iOS uses; see [start].
            "start" -> start(call, result)
            "update" -> call.nativeMapArgs(result, ::update)
            "end" -> call.nativeMapArgs(result, ::end)
            else -> super.onMethodCall(call, result)
        }
    }

    /**
     * Starts a live notification and returns its id.
     *
     * Takes [result] directly because [nativeMapArgs] reports every failure under the method name:
     * a type that isn't enabled has to arrive as [TYPE_NOT_REGISTERED_CODE] so the same mistake
     * reads the same way on iOS and Android. That check is not optional — the native
     * `startLiveNotification` mints an id whether or not the type is enabled, and
     * `LiveNotificationHandler` then drops the notification at debug level, so without it the caller
     * gets a real id and nothing ever renders.
     */
    @Suppress("UNCHECKED_CAST")
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<String, Any> ?: emptyMap()
        try {
            val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
            val payload = requireNotNull(args.getAs<Map<String, Any>>("payload")) {
                "payload is required"
            }
            // Custom types have no built-in template, so they take the SDK's untyped map path and are
            // rendered by the app's own callback. Built-ins keep the typed path.
            val isCustom = payload.getAs<String>("type") == CUSTOM_TYPE_DISCRIMINATOR
            val activityType = if (isCustom) {
                requireCustomActivityType()
            } else {
                payload.requireString("type")
            }
            if (activityType !in enabledActivityTypes()) {
                return result.error(
                    TYPE_NOT_REGISTERED_CODE,
                    notRegisteredMessage(activityType),
                    null,
                )
            }
            val id = if (isCustom) {
                module.startLiveNotification(activityType, customData(payload))
            } else {
                module.startLiveNotification(parseData(payload))
            }
            result.success(id)
        } catch (ex: Throwable) {
            result.error(call.method, ex.localizedMessage, ex)
        }
    }

    private fun update(args: Map<String, Any>) {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val activityId = requireNotNull(args.getAs<String>("activityId")) {
            "activityId is required"
        }
        val payload = requireNotNull(args.getAs<Map<String, Any>>("payload")) {
            "payload is required"
        }
        if (payload.getAs<String>("type") == CUSTOM_TYPE_DISCRIMINATOR) {
            module.updateLiveNotification(activityId, requireCustomActivityType(), customData(payload))
        } else {
            module.updateLiveNotification(activityId, parseData(payload))
        }
    }

    /**
     * Ends a live notification. Dart may send a `payload` for iOS, where a final content-state is
     * what makes ActivityKit render a terminal state; Android renders its own terminal state (the
     * notification simply stops being ongoing), so the key is ignored here.
     */
    private fun end(args: Map<String, Any>) {
        val module = requireNotNull(getPushModule()) { MODULE_UNAVAILABLE }
        val activityId = requireNotNull(args.getAs<String>("activityId")) {
            "activityId is required"
        }
        module.endLiveNotification(activityId)
    }

    /**
     * Identifiers the SDK will actually render, read from the live push module config rather than
     * cached at init. The wrapper is not the only thing that can enable a type — an app (or a
     * generated config plugin) may call `enableLiveNotificationTypes` on its own builder — and a
     * cached copy would then be empty and refuse every start.
     */
    private fun enabledActivityTypes(): Set<String> =
        SDKComponent.pushModuleConfig.liveNotificationTypes

    /**
     * The app's own identifier for the custom template. Absent means the app sent a custom payload
     * without configuring `liveNotifications.customType` — say so, rather than starting a
     * notification the allowlist would silently drop.
     *
     * Falls back to the live config for the same reason [enabledActivityTypes] reads it: the custom
     * type may have been enabled without going through this wrapper. It is the one enabled
     * identifier that isn't a built-in template, and there is only ever one.
     */
    private fun requireCustomActivityType(): String = requireNotNull(
        customActivityType ?: enabledActivityTypes().firstOrNull { identifier ->
            LiveNotificationType.entries.none { it.identifier == identifier }
        },
    ) {
        "No custom Live Activity type is configured. Set `liveNotifications.customType` in your " +
            "Customer.io SDK config to your own reverse-DNS identifier, and render it from your " +
            "CustomerIOLiveNotificationsCallback."
    }

    /** Flattens the payload's `data` map. Android stringifies every value downstream anyway. */
    private fun customData(payload: Map<String, Any>): Map<String, Any> =
        payload.getAs<Map<String, Any>>("data") ?: emptyMap()

    private fun parseData(payload: Map<String, Any>): LiveNotificationData {
        return when (val type = payload.getAs<String>("type")) {
            LiveNotificationType.SEGMENTS.identifier -> LiveNotificationData.Segments(
                header = payload.requireString("header"),
                status = payload.requireString("status"),
                substatus = payload.getAs<String>("substatus"),
                segmentsTotal = payload.requireInt("segmentsTotal"),
                segmentsComplete = payload.requireInt("segmentsComplete"),
                trailingText = payload.getAs<String>("trailingText"),
            )

            LiveNotificationType.COUNTDOWN_TIMER.identifier -> LiveNotificationData.CountdownTimer(
                header = payload.requireString("header"),
                title = payload.requireString("title"),
                statusMessage = payload.getAs<String>("statusMessage"),
                endTime = payload.getAs<Number>("endTime")?.toLong(),
            )

            // A newer native SDK may know this type even though this wrapper build doesn't.
            // Reject softly (the caller turns this into a FlutterError) rather than crash.
            else -> throw IllegalArgumentException("Unsupported Live Activity template: $type")
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

        // Discriminator Dart sends for the custom template. Not a wire identifier — the notification
        // is started under the app's own `liveNotifications.customType`.
        private const val CUSTOM_TYPE_DISCRIMINATOR = "custom"

        // Mirrors the iOS handler's code so the same mistake reads the same way on both platforms.
        private const val TYPE_NOT_REGISTERED_CODE = "live_activity_type_not_registered"

        private fun notRegisteredMessage(activityType: String): String =
            "Live Activity type '$activityType' is not registered. Add it to " +
                "`liveNotifications.types` in your Customer.io SDK config (or set " +
                "`liveNotifications.customType` for a custom type), and make sure your app renders it."

        // The app's own identifier for the custom template, captured from config at SDK init. Only a
        // hint: `requireCustomActivityType` falls back to the live config, which is authoritative
        // however the type was enabled.
        @Volatile
        private var customActivityType: String? = null

        /**
         * App-provided callback used to render custom (app-defined) Live Notifications. The native
         * push callback can only be set at SDK build time, so the host app must register this
         * *before* initializing the Customer.io SDK from Dart; it is then applied onto the push
         * module's config in [applyLiveActivitiesConfig].
         */
        @Volatile
        private var liveNotificationCallback:
            io.customer.messagingpush.data.communication.CustomerIOLiveNotificationsCallback? = null

        /**
         * Registers the callback used to render custom Live Notifications. Must be called before the
         * Customer.io SDK is initialized from Dart.
         */
        @JvmStatic
        fun setLiveNotificationCallback(
            callback: io.customer.messagingpush.data.communication.CustomerIOLiveNotificationsCallback,
        ) {
            liveNotificationCallback = callback
        }

        /**
         * Applies live activity configuration onto the FCM push module's config builder. Live
         * Notifications are hosted by [ModuleMessagingPushFCM], so their config (enabled templates,
         * custom types, branding) is set on the same [MessagingPushModuleConfig].
         *
         * @param builder the push module's config builder.
         * @param config the `liveNotifications` config map from the customer app.
         */
        internal fun applyLiveActivitiesConfig(
            builder: MessagingPushModuleConfig.Builder,
            config: Map<String, Any>,
        ) {
            // Custom live notifications require the host app to render them; apply the callback the
            // app registered before SDK init (see [setLiveNotificationCallback]).
            liveNotificationCallback?.let { builder.setLiveNotificationCallback(it) }

            // Unrecognized identifiers are ignored: a newer native SDK may ship types this
            // wrapper build doesn't know, and that must never break the ones it does know.
            val templateTypes = config.getAs<List<*>>("types")
                ?.mapNotNull { it as? String }
                ?.mapNotNull { identifier ->
                    LiveNotificationType.entries.firstOrNull { it.identifier == identifier }
                }
                .orEmpty()
            if (templateTypes.isNotEmpty()) {
                builder.enableLiveNotificationTypes(*templateTypes.toTypedArray())
            }

            // The custom template. Allowlisting the identifier is both necessary and sufficient:
            // LiveNotificationHandler drops any push whose activityType isn't in this set, and a type
            // with no built-in template falls through to the host app's render callback.
            //
            // Assigned unconditionally: a re-initialize that drops `customType` must clear it, or
            // `start` would keep minting notifications under an identifier no longer allowlisted —
            // which the handler then discards, leaving the caller with an id and nothing on screen.
            val customType = config.getAs<String>("customType")?.trim()?.takeIf { it.isNotEmpty() }
            customActivityType = customType
            if (customType != null) {
                builder.enableCustomLiveNotificationTypes(customType)
            }

            val branding = config.getAs<Map<String, Any>>("branding")
            if (branding != null) {
                val accentColor = branding.getAs<String>("accentColorHex")
                    ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
                    ?: Color.TRANSPARENT
                // A bundled drawable is preferred over a remote URL: it renders without a network
                // round-trip, so the logo is present on the very first frame.
                val logo = branding.getAs<String>("logoResource")
                    ?.let { name -> drawableResId(name)?.let(LiveNotificationAsset::Drawable) }
                    ?: branding.getAs<String>("logoUrl")?.let(LiveNotificationAsset::RemoteUrl)
                val smallIcon = branding.getAs<String>("smallIconResource")
                    ?.let { name -> drawableResId(name) }
                builder.setLiveNotificationBranding(
                    LiveNotificationBranding(
                        companyName = branding.getAs<String>("companyName").orEmpty(),
                        accentColor = accentColor,
                        smallIcon = smallIcon,
                        logo = logo,
                    ),
                )
            }
        }

        /**
         * Resolve a bundled drawable by name, or `null` when the host app doesn't ship one under
         * that name — a missing asset must degrade to "no image", never crash rendering.
         */
        private fun drawableResId(name: String): Int? {
            val context = SDKComponent.android().applicationContext
            return context.resources
                .getIdentifier(name, "drawable", context.packageName)
                .takeIf { it != 0 }
        }
    }
}
