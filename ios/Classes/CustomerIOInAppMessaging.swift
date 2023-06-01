import Foundation
import Flutter
import CioMessagingInApp

public class CusomterIOInAppMessaging: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
    }
    
    init(with registrar: FlutterPluginRegistrar) {
        super.init()
        
        methodChannel = FlutterMethodChannel(name: "customer_io_messaging_in_app", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(self, channel: methodChannel)
    }
    
    
    deinit {
        methodChannel.setMethodCallHandler(nil)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Handle method calls for this method channel
        switch(call.method) {
            case Keys.Methods.dismissMessage:
                MessagingInApp.shared.dismissMessage()
            default:
                result(FlutterMethodNotImplemented)
        }
    }
    
    func detachFromEngine() {
        methodChannel.setMethodCallHandler(nil)
        methodChannel = nil
    }
}
