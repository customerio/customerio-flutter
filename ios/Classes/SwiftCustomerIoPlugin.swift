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
        
        CustomerIO.initialize(siteId: siteId, apiKey: apiKey, region: Region.from(regionStr: region))
        setUserAgentClient(params: params)
        setupConfig(params: params)
    }
    
    private func setUserAgentClient(params : Dictionary<String, Any>){
        let version = params[Keys.PackageConfig.version] as? String ?? "n/a"
        let sdkSource = SdkWrapperConfig.Source.flutter
        CustomerIO.config {
            $0._sdkWrapperConfig = SdkWrapperConfig(source: sdkSource, version: version )
        }
    }
    
    private func setupConfig(params : Dictionary<String, Any>){
        CustomerIO.config {
            $0.autoTrackDeviceAttributes = params[Keys.Config.autoTrackDeviceAttributes] as! Bool
            $0.logLevel = CioLogLevel.from(for: params[Keys.Config.logLevel] as! String)
            $0.autoTrackPushEvents = params[Keys.Config.autoTrackPushEvents] as! Bool
            $0.backgroundQueueMinNumberOfTasks = params[Keys.Config.backgroundQueueMinNumberOfTasks] as! Int
            $0.backgroundQueueSecondsDelay = params[Keys.Config.backgroundQueueSecondsDelay] as! Seconds
            if let trackingApiUrl = params[Keys.Config.trackingApiUrl] as? String, !trackingApiUrl.isEmpty {
                $0.trackingApiUrl = trackingApiUrl
            }
        }
    }
}
