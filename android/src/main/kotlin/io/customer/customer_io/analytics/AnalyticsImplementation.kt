package io.customer.customer_io.analytics

import android.app.Activity
import android.util.Log
import io.customer.sdk.data.model.CustomAttributes
import io.customer.sdk.data.request.MetricEvent
import io.customer.sdk.module.AnalyticsModule
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class AnalyticsImplementation(
    override val moduleConfig: AnalyticsConfig = AnalyticsConfig()
) : AnalyticsModule<AnalyticsConfig>, FlutterPlugin {

    private lateinit var flutterCommunicationChannel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        log("onAttachedToEngine")
        flutterCommunicationChannel =
            MethodChannel(binding.binaryMessenger, "customer_io_analytics_implementation")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        log("onDetachedFromEngine")
    }

    override var deviceAttributes: CustomAttributes
        get() = emptyMap()
        set(value) {
            log("deviceAttributes = $value")
        }
    override val moduleName: String
        get() = "AnalyticsImplementation"
    override var profileAttributes: CustomAttributes
        get() = emptyMap()
        set(value) {
            log("profileAttributes = $value")
        }
    override val registeredDeviceToken: String?
        get() {
            log("registeredDeviceToken")
            return null
        }

    override fun addCustomDeviceAttributes(deviceAttributes: CustomAttributes) {
        log("addCustomDeviceAttributes(deviceAttributes: $deviceAttributes)")
    }

    override fun addCustomProfileAttributes(deviceAttributes: CustomAttributes) {
        log("addCustomProfileAttributes(deviceAttributes: $deviceAttributes)")
    }

    override suspend fun cleanup() {
        log("cleanup()")
    }

    override fun clearIdentify() {
        log("clearIdentify()")
    }

    override fun deleteDeviceToken() {
        log("deleteDeviceToken()")
    }

    override fun identify(identifier: String) {
        log("identify(identifier: $identifier)")
    }

    override fun identify(identifier: String, attributes: Map<String, Any>) {
        log("identify(identifier: $identifier, attributes: $attributes)")
    }

    override fun initialize() {
        log("initialize()")
    }

    override fun registerDeviceToken(deviceToken: String, deviceAttributes: CustomAttributes) {
        log("registerDeviceToken(deviceToken: $deviceToken, deviceAttributes: $deviceAttributes)")
    }

    override fun screen(activity: Activity) {
        log("screen(activity: $activity)")
    }

    override fun screen(activity: Activity, attributes: Map<String, Any>) {
        log("screen(activity: $activity, attributes: $attributes)")
    }

    override fun screen(name: String) {
        log("screen(name: $name)")
    }

    override fun screen(name: String, attributes: Map<String, Any>) {
        log("screen(name: $name, attributes: $attributes)")
    }

    override fun track(name: String) {
        log("track(name: $name)")
    }

    override fun track(name: String, attributes: Map<String, Any>) {
        log("track(name: $name, attributes: $attributes)")
    }

    override fun trackInAppMetric(
        deliveryID: String,
        event: MetricEvent,
        metadata: Map<String, String>
    ) {
        log("trackInAppMetric(deliveryID: $deliveryID, event: $event, metadata: $metadata)")
        flutterCommunicationChannel.invokeMethod(
            "trackMetric", buildMap {
                putAll(metadata)
                put("deliveryID", deliveryID)
                put("event", event)
                put("cio_type", "in_app_metric")
            }
        )
    }

    override fun trackMetric(deliveryID: String, event: MetricEvent, deviceToken: String) {
        log("trackMetric(deliveryID: $deliveryID, event: $event, deviceToken: $deviceToken)")
        flutterCommunicationChannel.invokeMethod(
            "trackMetric", mapOf(
                "deliveryID" to deliveryID,
                "deviceToken" to deviceToken,
                "event" to event,
                "cio_type" to "metric",
            )
        )
    }

    private fun log(message: String) {
        Log.d("[CIO]", "[DEV] AnalyticsImplementation: $message")
    }
}