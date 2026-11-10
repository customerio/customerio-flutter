import CioDataPipelines
@_spi(Internal) import CioMessagingPush
import Flutter
import Foundation

public class CustomerIOMessagingPush: NSObject, FlutterPlugin {
    private let channelName: String = "customer_io_messaging_push"
    /// Set once Dart registers a silent push handler, and kept across launches: a push that launches the app
    /// reaches `CioAppDelegateWrapper` before Dart runs.
    private static let backgroundPushHandlerKey = "io.customer.customer_io.background_push_handler_registered"
    /// The engine whose Dart isolate gets silent pushes: the last to register a handler, or else the first engine.
    private static weak var backgroundPushReceiver: CustomerIOMessagingPush?

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
        // Pushes that arrive during a background launch wait here until Dart registers its handler.
        methodChannel.resizeBuffer(10)
        if Self.backgroundPushReceiver == nil {
            Self.backgroundPushReceiver = self
        }
        MessagingPush.wrapperBackgroundPushHandler = Self.handleBackgroundPush
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

        case "registerBackgroundPushHandler":
            call.nativeMapArgs(result: result) { _ in
                UserDefaults.standard.set(true, forKey: Self.backgroundPushHandlerKey)
                Self.backgroundPushReceiver = self
            }

        case "clearBackgroundPushHandler":
            call.nativeNoArgs(result: result) {
                UserDefaults.standard.removeObject(forKey: Self.backgroundPushHandlerKey)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Called by `CioAppDelegateWrapper` for Customer.io silent pushes only, after it saves Delivered. Returning
    /// false leaves the push to the app delegate as before. The SDK completes a taken push with `.noData` after
    /// 25 seconds if Dart hasn't answered.
    private static func handleBackgroundPush(
        _ push: CustomerIOBackgroundPush,
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) -> Bool {
        guard UserDefaults.standard.bool(forKey: backgroundPushHandlerKey),
              let methodChannel = backgroundPushReceiver?.methodChannel
        else { return false }

        methodChannel.invokeMethod(
            "onBackgroundPushReceived",
            arguments: ["deliveryId": push.deliveryID, "deliveryToken": push.deliveryToken, "data": push.data]
        ) { result in
            completionHandler(result is FlutterError ? .failed : .newData)
        }
        return true
    }
}
