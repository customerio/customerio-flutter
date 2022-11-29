import Flutter
import UIKit
import CioTracking
import Common
import CioMessagingInApp

public class SwiftCustomerIoPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        let instance = SwiftCustomerIoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    private func identify(params : Dictionary<String, Any>){
        guard let identifier = params[Keys.Tracking.identifier] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, Any> else{
            CustomerIO.shared.identify(identifier: identifier)
            return
        }
        
        CustomerIO.shared.identify(identifier: identifier, body: attributes)
    }
    
    private func clearIdentify() {
        CustomerIO.shared.clearIdentify()
    }
    
    private func track(params : Dictionary<String, Any>)  {
        guard let name = params[Keys.Tracking.eventName] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, Any> else{
            CustomerIO.shared.track(name: name)
            return
        }
        
        CustomerIO.shared.track(name: name, data: attributes)
        
    }
    
    func screen(params : Dictionary<String, Any>) {
        guard let name = params[Keys.Tracking.eventName] as? String
        else {
            return
        }
        
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, Any> else{
            CustomerIO.shared.screen(name: name)
            return
        }
        
        CustomerIO.shared.screen(name: name, data: attributes)
    }
    
    
    private func setDeviceAttributes(params : Dictionary<String, Any>){
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, Any>
        else {
            return
        }
        CustomerIO.shared.deviceAttributes = attributes
    }
    
    private func setProfileAttributes(params : Dictionary<String, Any>){
        guard let attributes = params[Keys.Tracking.attributes] as? Dictionary<String, Any>
        else {
            return
        }
        CustomerIO.shared.profileAttributes = attributes
    }
    
    
    private func initialize(params : Dictionary<String, Any>){
        guard let siteId = params[Keys.Environment.siteId] as? String,
              let apiKey = params[Keys.Environment.apiKey] as? String,
              let region = params[Keys.Environment.region] as? String,
              let organizationId = params[Keys.Environment.organizationId] as? String
        else {
            return
        }
        
        CustomerIO.initialize(siteId: siteId, apiKey: apiKey, region: Region.from(regionStr: region)){
            config in
            config._sdkWrapperConfig = self.getUserAgent(params: params)
            config.autoTrackDeviceAttributes = params[Keys.Config.autoTrackDeviceAttributes] as! Bool
            config.logLevel = CioLogLevel.from(for: params[Keys.Config.logLevel] as! String)
            config.autoTrackPushEvents = params[Keys.Config.autoTrackPushEvents] as! Bool
            config.backgroundQueueMinNumberOfTasks = params[Keys.Config.backgroundQueueMinNumberOfTasks] as! Int
            config.backgroundQueueSecondsDelay = params[Keys.Config.backgroundQueueSecondsDelay] as! Seconds
            if let trackingApiUrl = params[Keys.Config.trackingApiUrl] as? String, !trackingApiUrl.isEmpty {
                config.trackingApiUrl = trackingApiUrl
            }
        }
        
        if organizationId != "" {
            initializeInApp(organizationId: organizationId)
        }
    }
    
    private func getUserAgent(params : Dictionary<String, Any>) -> SdkWrapperConfig{
        let version = params[Keys.PackageConfig.version] as? String ?? "n/a"
        let sdkSource = SdkWrapperConfig.Source.flutter
        return SdkWrapperConfig(source: sdkSource, version: version )
    }
    
    
    /**
     Initialize in-app using customerio plugin
     */
    private func initializeInApp(organizationId: String){
        DispatchQueue.main.async {
            MessagingInApp.shared.initialize(organizationId: organizationId)
        }
    }
}

private extension FlutterMethodCall {
    func toNativeMethodCall( result: @escaping FlutterResult,
                             method: (_: Dictionary<String, Any>) throws -> Void) {
        do {
            if let attributes = self.arguments as? Dictionary<String, Any> {
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
