package io.customer.customer_io.location

import io.customer.customer_io.bridge.NativeModuleBridge
import io.customer.customer_io.bridge.nativeMapArgs
import io.customer.customer_io.bridge.nativeNoArgs
import io.customer.customer_io.utils.getAs
import io.customer.location.LocationModuleConfig
import io.customer.location.LocationTrackingMode
import io.customer.location.ModuleLocation
import io.customer.sdk.CustomerIOBuilder
import io.customer.sdk.core.di.SDKComponent
import io.customer.sdk.core.util.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter module implementation for location module in native SDKs. All functionality
 * linked with the module should be placed here.
 */
internal class CustomerIOLocation(
    pluginBinding: FlutterPlugin.FlutterPluginBinding,
) : NativeModuleBridge, MethodChannel.MethodCallHandler {
    override val moduleName: String = "Location"
    override val flutterCommunicationChannel: MethodChannel =
        MethodChannel(pluginBinding.binaryMessenger, "customer_io_location")
    private val logger: Logger = SDKComponent.logger

    private fun getLocationServices() = runCatching {
        ModuleLocation.instance().locationServices
    }.onFailure {
        logger.error("Location module is not initialized. Ensure location config is provided during SDK initialization.")
    }.getOrNull()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setLastKnownLocation" -> call.nativeMapArgs(result, ::setLastKnownLocation)
            "requestLocationUpdate" -> call.nativeNoArgs(result, ::requestLocationUpdate)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun setLastKnownLocation(params: Map<String, Any>) {
        val latitude = params.getAs<Double>("latitude")
        val longitude = params.getAs<Double>("longitude")

        if (latitude == null || longitude == null) {
            logger.error("Latitude and longitude are required for setLastKnownLocation")
            return
        }

        getLocationServices()?.setLastKnownLocation(latitude, longitude)
    }

    private fun requestLocationUpdate() {
        getLocationServices()?.requestLocationUpdate()
    }

    override fun configureModule(
        builder: CustomerIOBuilder,
        config: Map<String, Any>
    ) {
        val trackingModeValue = config.getAs<String>("trackingMode")
        val trackingMode = trackingModeValue?.let { value ->
            runCatching { enumValueOf<LocationTrackingMode>(value) }.getOrNull()
        } ?: LocationTrackingMode.MANUAL

        val module = ModuleLocation(
            LocationModuleConfig.Builder()
                .setLocationTrackingMode(trackingMode)
                .build()
        )
        builder.addCustomerIOModule(module)
    }
}
