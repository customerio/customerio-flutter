import CioDataPipelines
import CioInternalCommon
import CioMessagingInApp
import Flutter
import UIKit
#if canImport(CioLocation)
import CioLocation
#endif
#if canImport(CioLocationGeofence)
import CioLocationGeofence
#endif

public class CustomerIOPlugin: NSObject, FlutterPlugin {
    let lifecycleHandler = CustomerIOFlutterLifecycle()

    private var methodChannel: FlutterMethodChannel!
    private var inAppMessagingChannelHandler: CustomerIOInAppMessaging!
    #if canImport(CioLocation)
    private var locationChannelHandler: CustomerIOLocation!
    #endif
    #if canImport(CioLocationGeofence)
    private var geofenceChannelHandler: CustomerIOGeofence!
    #endif
    private var messagingPushChannelHandler: CustomerIOMessagingPush!
    private var liveActivitiesChannelHandler: CustomerIOLiveActivities!

    private let logger: CioInternalCommon.Logger = DIGraphShared.shared.logger

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CustomerIOPlugin()

        instance.methodChannel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
        registrar.publish(instance)

        instance.lifecycleHandler.configureRedirectRouting(with: registrar)
        registerSceneDelegateIfSupported(instance, with: registrar)

        instance.inAppMessagingChannelHandler = CustomerIOInAppMessaging(with: registrar)
        #if canImport(CioLocation)
        instance.locationChannelHandler = CustomerIOLocation(with: registrar)
        #endif
        #if canImport(CioLocationGeofence)
        instance.geofenceChannelHandler = CustomerIOGeofence(with: registrar)
        #endif
        instance.messagingPushChannelHandler = CustomerIOMessagingPush(with: registrar)
        instance.liveActivitiesChannelHandler = CustomerIOLiveActivities(with: registrar)
    }

    /// Flutter added scene-delegate registration after this package's original minimum Flutter
    /// version. Invoke the optional registrar API dynamically so existing AppDelegate-only apps
    /// continue to compile on older Flutter releases, while newer Flutter hosts can use UIScene.
    private static func registerSceneDelegateIfSupported(
        _ instance: CustomerIOPlugin,
        with registrar: FlutterPluginRegistrar
    ) {
        guard instance.lifecycleHandler.shouldRegisterSceneDelegate else { return }
        guard #available(iOS 13.0, *) else { return }

        let selector = NSSelectorFromString("addSceneDelegate:")
        guard registrar.responds(to: selector) else {
            instance.lifecycleHandler.reportUnavailableSceneRegistration()
            return
        }
        _ = registrar.perform(selector, with: instance.lifecycleHandler)
    }

    deinit {
        self.methodChannel.setMethodCallHandler(nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "clearIdentify":
            call.nativeNoArgs(result: result, handler: clearIdentify)

        case "deleteDeviceToken":
            call.nativeNoArgs(result: result, handler: deleteDeviceToken)

        case "identify":
            call.nativeMapArgs(result: result, handler: identify)

        case "initialize":
            call.nativeMapArgs(result: result, handler: initialize)

        case "setDeviceAttributes":
            call.nativeMapArgs(result: result, handler: setDeviceAttributes)

        case "setProfileAttributes":
            call.nativeMapArgs(result: result, handler: setProfileAttributes)

        case "registerDeviceToken":
            call.nativeMapArgs(result: result, handler: registerDeviceToken)

        case "screen":
            call.nativeMapArgs(result: result, handler: screen)

        case "track":
            call.nativeMapArgs(result: result, handler: track)

        case "trackMetric":
            call.nativeMapArgs(result: result, handler: trackMetric)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func identify(params: [String: AnyHashable]) {
        let userId = params[Args.userId] as? String
        let traits = params[Args.traits] as? [String: AnyHashable] ?? [:]

        if userId == nil, traits.isEmpty {
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

    private func track(params: [String: AnyHashable]) {
        guard let name: String = params.require(Args.name) else {
            return
        }

        guard let properties = params[Args.properties] as? [String: AnyHashable] else {
            CustomerIO.shared.track(name: name)
            return
        }

        CustomerIO.shared.track(name: name, properties: properties)
    }

    func screen(params: [String: AnyHashable]) {
        guard let title: String = params.require(Args.title) else {
            return
        }

        guard let properties = params[Args.properties] as? [String: AnyHashable] else {
            CustomerIO.shared.screen(title: title)
            return
        }

        CustomerIO.shared.screen(title: title, properties: properties)
    }

    private func setDeviceAttributes(params: [String: AnyHashable]) {
        guard let attributes: [String: AnyHashable] = params.require(Args.attributes) else {
            return
        }

        CustomerIO.shared.deviceAttributes = attributes
    }

    private func setProfileAttributes(params: [String: AnyHashable]) {
        guard let attributes: [String: AnyHashable] = params.require(Args.attributes) else {
            return
        }

        CustomerIO.shared.profileAttributes = attributes
    }

    private func registerDeviceToken(params: [String: AnyHashable]) {
        guard let token: String = params.require(Args.token) else {
            return
        }

        CustomerIO.shared.registerDeviceToken(token)
    }

    private func deleteDeviceToken() {
        CustomerIO.shared.deleteDeviceToken()
    }

    private func trackMetric(params: [String: AnyHashable]) {
        guard let deliveryId: String = params.require(Args.deliveryId),
              let deviceToken: String = params.require(Args.deliveryToken),
              let metricEvent: String = params.require(Args.metricEvent),
              let event = Metric.getEvent(from: metricEvent)
        else {
            return
        }

        CustomerIO.shared.trackMetric(deliveryID: deliveryId, event: event, deviceToken: deviceToken)
    }

    private func initialize(params: [String: AnyHashable]) {
        do {
            // Configure and override SdkClient for Flutter before initializing native SDK
            CustomerIOSdkClient.configure(using: params)
            // Initialize native SDK with provided config
            let sdkConfigBuilder = try SDKConfigBuilder.create(from: params)

            #if canImport(CioLocation)
            let locationConfig = params["location"] as? [String: AnyHashable]
            #if canImport(CioLocationGeofence)
            let geofenceConfigured = params["geofence"] as? [String: AnyHashable] != nil
            #else
            let geofenceConfigured = false
            #endif

            // Add location module when location or geofence is configured. Geofence implies
            // location: it relies on the location module's fixes, so register location (with
            // the app's config if given, otherwise defaults) whenever geofence is enabled.
            if locationConfig != nil || geofenceConfigured {
                let trackingModeValue = locationConfig?["trackingMode"] as? String
                let mode: LocationTrackingMode
                switch trackingModeValue?.uppercased() {
                case "OFF":
                    mode = .off
                case "ON_APP_START":
                    mode = .onAppStart
                default:
                    mode = .manual
                }
                _ = sdkConfigBuilder.addModule(LocationModule(config: LocationConfig(mode: mode)))
            }

            #if canImport(CioLocationGeofence)
            // Geofence relies on the location module above.
            if let geofenceConfig = params["geofence"] as? [String: AnyHashable] {
                let locationMode: GeofenceLocationMode
                switch (geofenceConfig["locationMode"] as? String)?.uppercased() {
                case "MANUAL":
                    locationMode = .manual
                default:
                    locationMode = .automatic
                }
                _ = sdkConfigBuilder.addModule(GeofenceModule(config: GeofenceModuleConfig(locationMode: locationMode)))
            }
            #endif
            #endif

            // Customer value wins; otherwise on when the geofence module is added, off otherwise.
            #if canImport(CioLocationGeofence)
            let geofenceAdded = params["geofence"] as? [String: AnyHashable] != nil
            #else
            let geofenceAdded = false
            #endif
            let allowBackgroundDelivery = (params["ios"] as? [String: AnyHashable])?["allowBackgroundDelivery"] as? Bool
            _ = sdkConfigBuilder.allowBackgroundDelivery(allowBackgroundDelivery ?? geofenceAdded)

            #if canImport(CioLiveActivities)
            // Register Live Activities from the `liveNotifications` config (iOS 16.2+). Adding it
            // to the config builder — rather than initializing after the fact — is what enables
            // push-to-start, since token registration happens during SDK init.
            if let liveActivitiesModule = CustomerIOLiveActivities.module(from: params) {
                _ = sdkConfigBuilder.addModule(liveActivitiesModule)
            }
            #endif

            CustomerIO.initialize(withConfig: sdkConfigBuilder.build())

            // Initialize in-app messaging with provided config
            inAppMessagingChannelHandler.configureModule(params: params)

            logger.debug("Customer.io SDK initialized with config: \(params)")
        } catch {
            logger.error("Initializing Customer.io SDK failed with error: \(error)")
        }
    }

    enum Args {
        static let attributes = "attributes"
        static let deliveryId = "deliveryId"
        static let deliveryToken = "deliveryToken"
        static let metricEvent = "metricEvent"
        static let name = "name"
        static let properties = "properties"
        static let title = "title"
        static let token = "token"
        static let traits = "traits"
        static let userId = "userId"
    }
}
