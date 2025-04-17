import CioInternalCommon
import CioMessagingInApp
import Flutter
import Foundation

public class CustomerIOInAppMessaging: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?

    public static func register(with _: FlutterPluginRegistrar) {}

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        methodChannel = FlutterMethodChannel(name: "customer_io_messaging_in_app", binaryMessenger: registrar.messenger())

        guard let methodChannel = methodChannel else {
            print("customer_io_messaging_in_app methodChannel is nil")
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
        case "dismissMessage":
            call.nativeNoArgs(result: result) {
                MessagingInApp.shared.dismissMessage()
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func configureModule(params: [String: AnyHashable]) {
        if let inAppConfig = try? MessagingInAppConfigBuilder.build(from: params) {
            MessagingInApp.initialize(withConfig: inAppConfig)
            MessagingInApp.shared.setEventListener(CustomerIOInAppEventListener(invokeDartMethod: invokeDartMethod))
        } else {
            DIGraphShared.shared.logger.error("[InApp] Failed to initialize module: invalid config")
        }
    }

    func invokeDartMethod(_ method: String, _ args: Any?) {
        // When sending messages from native code to Flutter, it's required to do it on main thread.
        // Learn more:
        // * https://docs.flutter.dev/platform-integration/platform-channels#channels-and-platform-threading
        // * https://linear.app/customerio/issue/MBL-358/
        DIGraphShared.shared.threadUtil.runMain { [weak self] in
            guard let self else { return }

            self.methodChannel?.invokeMethod(method, arguments: args)
        }
    }
}
