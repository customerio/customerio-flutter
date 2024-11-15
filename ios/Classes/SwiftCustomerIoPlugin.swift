import Flutter
import UIKit
import CioDataPipelines
import CioInternalCommon
import CioMessagingInApp

public class SwiftCustomerIoPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel!
    private var inAppMessagingChannelHandler: CusomterIOInAppMessaging!
    private var messagingPushChannelHandler: CustomerIOMessagingPush!
    private let logger: CioInternalCommon.Logger = DIGraphShared.shared.logger
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCustomerIoPlugin()
        instance.methodChannel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
        
        instance.inAppMessagingChannelHandler = CusomterIOInAppMessaging(with: registrar)
        instance.messagingPushChannelHandler = CustomerIOMessagingPush(with: registrar)
    }
    
    deinit {
        self.methodChannel.setMethodCallHandler(nil)
        self.inAppMessagingChannelHandler.detachFromEngine()
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
            case Keys.Methods.registerDeviceToken:
                call.toNativeMethodCall(result: result) {
                    registerDeviceToken(params: $0)
                }
            case Keys.Methods.trackMetric:
                call.toNativeMethodCall(result: result) {
                    trackMetric(params: $0)
                }
            default:
                result(FlutterMethodNotImplemented)
        }
    }
    
    private func identify(params : Dictionary<String, AnyHashable>){
        
        let userId = params[Keys.Tracking.userId] as? String
        let traits = params[Keys.Tracking.traits] as? Dictionary<String, AnyHashable> ?? [:]
        
        if userId == nil && traits.isEmpty {
            logger.error("Please provide either an ID or traits to identify.")
            return
        }
        
        if let userId = userId, !traits.isEmpty {
            CustomerIO.shared.identify(userId: userId, traits: traits)
        } else if let userId = userId {
            CustomerIO.shared.identify(userId: userId)
        } else {
            CustomerIO.shared.profileAttributes = traits
        }
    }
    
    private func clearIdentify() {
        CustomerIO.shared.clearIdentify()
    }
    
    private func track(params : Dictionary<String, AnyHashable>)  {
        guard let name = params[Keys.Tracking.name] as? String else {
            logger.error("Missing event name in: \(params) for key: \(Keys.Tracking.name)")
            return
        }
        
        guard let properties = params[Keys.Tracking.properties] as? Dictionary<String, AnyHashable> else {
            CustomerIO.shared.track(name: name)
            return
        }
        
        CustomerIO.shared.track(name: name, properties: properties)
    }
    
    func screen(params : Dictionary<String, AnyHashable>) {
        guard let title = params[Keys.Tracking.title] as? String else {
            logger.error("Missing screen title in: \(params) for key: \(Keys.Tracking.title)")
            return
        }
        
        guard let properties = params[Keys.Tracking.properties] as? Dictionary<String, AnyHashable> else {
            CustomerIO.shared.screen(title: title)
            return
        }
        
        CustomerIO.shared.screen(title: title, properties: properties)
    }
    
    
    private func setDeviceAttributes(params : Dictionary<String, AnyHashable>){
        // TODO: Fix setDeviceAttributes implementation
        /*
         guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, AnyHashable>
         else {
         return
         }
         CustomerIO.shared.deviceAttributes = attributes
         */
    }
    
    private func setProfileAttributes(params : Dictionary<String, AnyHashable>){
        guard let attributes = params[Keys.Tracking.traits] as? Dictionary<String, AnyHashable>
        else {
            logger.error("Missing attributes in: \(params) for key: \(Keys.Tracking.traits)")
            return
        }
        
        CustomerIO.shared.profileAttributes = attributes
    }
    
    private func registerDeviceToken(params : Dictionary<String, AnyHashable>){
        guard let token = params[Keys.Tracking.token] as? String
        else {
            logger.error("Missing token in: \(params) for key: \(Keys.Tracking.token)")
            return
        }
        
        CustomerIO.shared.registerDeviceToken(token)
    }
    
    private func trackMetric(params : Dictionary<String, AnyHashable>){
        // TODO: Fix trackMetric implementation
        /*
         guard let deliveryId = params[Keys.Tracking.deliveryId] as? String,
         let deviceToken = params[Keys.Tracking.deliveryToken] as? String,
         let metricEvent = params[Keys.Tracking.metricEvent] as? String,
         let event = Metric.getEvent(from: metricEvent)
         else {
         return
         }
         
         CustomerIO.shared.trackMetric(deliveryID: deliveryId,
         event: event,
         deviceToken: deviceToken)
         */
    }
    
    private func initialize(params : Dictionary<String, AnyHashable>){
        do {
            // Configure and override SdkClient for Flutter before initializing native SDK
            CustomerIOSdkClient.configure(using: params)
            // Initialize native SDK with provided config
            let sdkConfigBuilder = try SDKConfigBuilder.create(from: params)
            CustomerIO.initialize(withConfig: sdkConfigBuilder.build())
            
            // TODO: Initialize in-app module with given config
            logger.debug("Customer.io SDK initialized with config: \(params)")
        } catch {
            logger.error("Initializing Customer.io SDK failed with error: \(error)")
        }
    }
    
    /**
     Initialize in-app using customerio plugin
     */
    private func initializeInApp(){
        // TODO: Fix initializeInApp implementation
        /*
         DispatchQueue.main.async {
         MessagingInApp.shared.initialize(eventListener: CustomerIOInAppEventListener(
         invokeMethod: {method,args in
         self.invokeMethod(method, args)
         })
         )
         }
         */
    }
    
    func invokeMethod(_ method: String, _ args: Any?) {
        // When sending messages from native code to Flutter, it's required to do it on main thread.
        // Learn more:
        // * https://docs.flutter.dev/platform-integration/platform-channels#channels-and-platform-threading
        // * https://linear.app/customerio/issue/MBL-358/
        DispatchQueue.main.async {
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
