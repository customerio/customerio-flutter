import Flutter
import UIKit
import CioTracking
import Common

public class SwiftCustomerIoPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        let instance = SwiftCustomerIoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "initialize":
            if let params = call.arguments as? Dictionary<String, Any> {
                print(params)
                initialize(params: params)
                result(true)
            } else{
                print("initialize: params not available")
                result(FlutterError())
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initialize(params : Dictionary<String, Any>){
        guard let siteId = params[Keys.Environment.siteId] as? String,
              let apiKey = params[Keys.Environment.apiKey] as? String,
              let region = params[Keys.Environment.region] as? String
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
    }
    
    private func getUserAgent(params : Dictionary<String, Any>) -> SdkWrapperConfig{
        let version = params[Keys.PackageConfig.version] as? String ?? "n/a"
        let sdkSource = SdkWrapperConfig.Source.flutter
        return SdkWrapperConfig(source: sdkSource, version: version )
    }
}
