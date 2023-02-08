import Flutter
import UIKit
import CioTracking
import Common
import CioMessagingInApp

public class SwiftCustomerIoPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCustomerIoPlugin()
        instance.methodChannel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    }
    
    deinit {
        self.methodChannel.setMethodCallHandler(nil)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case Keys.Methods.initialize:
            call.toNativeMethodCall(
                result: result) {
                    initialize(params: $0)
                }
        case Keys.Methods.clearIdentify:
            clearIdentify()
        case Keys.Methods.track:
            call.toNativeMethodCall(
                result: result) {
                    track(params: $0)
                }
        case Keys.Methods.screen:
            call.toNativeMethodCall(
                result: result) {
                    screen(params: $0)
                }
        case Keys.Methods.identify:
            call.toNativeMethodCall(
                result: result) {
                    identify(params: $0)
                }
        case Keys.Methods.setProfileAttributes:
            call.toNativeMethodCall(result: result) {
                setProfileAttributes(params: $0)
            }
        case Keys.Methods.setDeviceAttributes:
            call.toNativeMethodCall(result: result) {
                setDeviceAttributes(params: $0)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func identify(params : Dictionary<String, AnyHashable>){
        guard let identifier = params[Keys.Tracking.identifier] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable> else{
            CustomerIO.shared.identify(identifier: identifier)
            return
        }
        
        CustomerIO.shared.identify(identifier: identifier, body: attributes)
    }
    
    private func clearIdentify() {
        CustomerIO.shared.clearIdentify()
    }
    
    private func track(params : Dictionary<String, AnyHashable>)  {
        guard let name = params[Keys.Tracking.eventName] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable> else{
            CustomerIO.shared.track(name: name)
            return
        }
        
        CustomerIO.shared.track(name: name, data: attributes)
        
    }
    
    func screen(params : Dictionary<String, AnyHashable>) {
        guard let name = params[Keys.Tracking.eventName] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable> else{
            CustomerIO.shared.screen(name: name)
            return
        }
        
        CustomerIO.shared.screen(name: name, data: attributes)
    }
    
    
    private func setDeviceAttributes(params : Dictionary<String, AnyHashable>){
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable>
        else {
            return
        }
        CustomerIO.shared.deviceAttributes = attributes
    }
    
    private func setProfileAttributes(params : Dictionary<String, AnyHashable>){
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable>
        else {
            return
        }
        CustomerIO.shared.profileAttributes = attributes
    }
    
    
    private func initialize(params : Dictionary<String, AnyHashable>){
        guard let siteId = params[Keys.Environment.siteId] as? String,
              let apiKey = params[Keys.Environment.apiKey] as? String,
              let regionStr = params[Keys.Environment.region] as? String
        else {
            return
        }
        
        let region = Region.getRegion(from: regionStr)
        
        CustomerIO.initialize(siteId: siteId, apiKey: apiKey, region: region){
            config in
            config.modify(params: params)
        }
        

        if let enableInApp = params[Keys.Environment.enableInApp] as? Bool {
            if enableInApp{
                initializeInApp()
            }
        }
        
    }
    
    /**
     Initialize in-app using customerio plugin
     */
    private func initializeInApp(){
        DispatchQueue.main.async {
            MessagingInApp.shared.initialize(eventListener: CustomerIOInAppEventListener(
                invokeMethod: {method,args in
                    self.invokeMethodInBackground(method, args)
                })
            )
        }
    }
    
    func invokeMethodInBackground(_ method: String, _ args: Any?) {
        DispatchQueue.global(qos: .background).async {
            self.methodChannel.invokeMethod(method, arguments: args)
        }
    }
    
}

private extension FlutterMethodCall {
    func toNativeMethodCall( result: @escaping FlutterResult,
                             method: (_: Dictionary<String, AnyHashable>) throws -> Void) {
        do {
            if let attributes = self.arguments as? Dictionary<String, AnyHashable> {
                print(attributes)
                try method(attributes)
                result(true)
            } else{
                result(FlutterError(code: self.method, message: "params not available", details: nil))
            }
        } catch {
            result(FlutterError(code: self.method, message: "Unexpected error: \(error).", details: nil))
        }
        
    }
}

class CustomerIOInAppEventListener {
    private let invokeMethod: (String, Any?) -> Void
    
    init(invokeMethod: @escaping (String, Any?) -> Void) {
        self.invokeMethod = invokeMethod
    }
}

extension CustomerIOInAppEventListener: InAppEventListener {
    func errorWithMessage(message: InAppMessage) {
        invokeMethod("errorWithMessage", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }
    
    func messageActionTaken(message: InAppMessage, actionValue: String, actionName: String) {
        invokeMethod("messageActionTaken", [
            "messageId": message.messageId,
            "deliveryId": message.deliveryId,
            "actionValue": actionValue,
            "actionName": actionName
        ])
    }
    
    func messageDismissed(message: InAppMessage) {
        invokeMethod("messageDismissed", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }
    
    func messageShown(message: InAppMessage) {
        invokeMethod("messageShown", ["messageId": message.messageId, "deliveryId": message.deliveryId])
    }
}
