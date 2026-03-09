import CioInternalCommon
import CioLocation
import CoreLocation
import Flutter
import Foundation

public class CustomerIOLocation: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private let logger: Logger = DIGraphShared.shared.logger

    public static func register(with _: FlutterPluginRegistrar) {}

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        methodChannel = FlutterMethodChannel(name: "customer_io_location", binaryMessenger: registrar.messenger())

        guard let methodChannel = methodChannel else {
            print("customer_io_location methodChannel is nil")
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
        case "setLastKnownLocation":
            call.nativeMapArgs(result: result, handler: setLastKnownLocation)

        case "requestLocationUpdate":
            call.nativeNoArgs(result: result, handler: requestLocationUpdate)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setLastKnownLocation(params: [String: AnyHashable]) {
        guard let latitude = params["latitude"] as? Double,
              let longitude = params["longitude"] as? Double
        else {
            logger.error("Latitude and longitude are required for setLastKnownLocation")
            return
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        CustomerIO.location.setLastKnownLocation(location)
    }

    private func requestLocationUpdate() {
        CustomerIO.location.requestLocationUpdate()
    }
}
