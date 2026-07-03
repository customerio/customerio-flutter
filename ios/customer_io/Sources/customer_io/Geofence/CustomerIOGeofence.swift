#if canImport(CioLocationGeofence)
import CioInternalCommon
import CioLocationGeofence
import Flutter
import Foundation

public class CustomerIOGeofence: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private let logger: Logger = DIGraphShared.shared.logger

    public static func register(with _: FlutterPluginRegistrar) {}

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        methodChannel = FlutterMethodChannel(name: "customer_io_geofence", binaryMessenger: registrar.messenger())

        guard let methodChannel = methodChannel else {
            print("customer_io_geofence methodChannel is nil")
            return
        }

        registrar.addMethodCallDelegate(self, channel: methodChannel)
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "refreshFromCurrentLocation":
            call.nativeNoArgs(result: result, handler: refreshFromCurrentLocation)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func refreshFromCurrentLocation() {
        CustomerIO.geofence.refreshFromCurrentLocation()
    }
}
#endif
