package io.customer.customer_io.geofence

import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.utils.getAs
import io.customer.geofence.GeofenceLocationMode
import io.customer.geofence.GeofenceModuleConfig
import io.customer.geofence.ModuleGeofence
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge for the geofence module. Wires the native module into the SDK
 * builder and exposes its Flutter-facing methods. The references to
 * [ModuleGeofence] are isolated here so they are loaded only when the geofence
 * dependency is bundled.
 *
 * Geofence depends on the location module; registration of location is handled by
 * the plugin when geofence is configured.
 */
internal class CustomerIOGeofence(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge {
    override val moduleName: String = "Geofence"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_geofence")
    private val logger: Logger = SDKComponent.logger

    private fun getModuleGeofence() = runCatching {
        ModuleGeofence.instance()
    }.onFailure {
        logger.error("Geofence module is not initialized. Ensure geofence config is provided during SDK initialization.")
    }.getOrNull()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "refreshFromCurrentLocation" -> call.nativeNoArgs(result, ::refreshFromCurrentLocation)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun refreshFromCurrentLocation() {
        getModuleGeofence()?.refreshFromCurrentLocation()
    }

    override fun configureModule(builder: CustomerIOBuilder, config: Map<String, Any>) {
        val locationModeValue = config.getAs<String>("locationMode")
        // Uppercase before matching so casing can't diverge from iOS (which uppercases too);
        // enumValueOf is case-sensitive. Unknown values fall back to the SDK default.
        val locationMode = locationModeValue?.let { value ->
            runCatching { enumValueOf<GeofenceLocationMode>(value.uppercase()) }.getOrNull()
        } ?: GeofenceLocationMode.AUTOMATIC

        builder.addCustomerIOModule(
            ModuleGeofence(
                GeofenceModuleConfig.Builder()
                    .setLocationMode(locationMode)
                    .build()
            )
        )
    }
}
