package io.customer.customer_io.geofence

import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.geofence.GeofenceModuleConfig
import io.customer.geofence.ModuleGeofence
import io.customer.sdk.CustomerIOBuilder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge for the geofence module. Geofence has no Flutter-facing methods —
 * it runs automatically once registered — so this only wires the native module into
 * the SDK builder. The reference to [ModuleGeofence] is isolated here so it is loaded
 * only when the geofence dependency is bundled.
 *
 * Geofence depends on the location module; registration of location is handled by the
 * plugin when geofence is configured.
 */
internal class CustomerIOGeofence(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge {
    override val moduleName: String = "Geofence"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_geofence")

    override fun configureModule(builder: CustomerIOBuilder, config: Map<String, Any>) {
        builder.addCustomerIOModule(ModuleGeofence(GeofenceModuleConfig.Builder().build()))
    }
}
