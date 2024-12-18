import CioDataPipelines
import Flutter
import Foundation

public class CustomerIOMessagingPush: NSObject, FlutterPlugin {
    private let channelName: String = "customer_io_messaging_push"

    public static func register(with _: FlutterPluginRegistrar) {}

    private var methodChannel: FlutterMethodChannel?

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        guard let methodChannel = methodChannel else {
            print("\(channelName) methodChannel is nil")
            return
        }

        registrar.addMethodCallDelegate(self, channel: methodChannel)
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle method calls for this method channel
        switch call.method {
        case "getRegisteredDeviceToken":
            call.nativeNoArgs(result: result) { CustomerIO.shared.registeredDeviceToken }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
