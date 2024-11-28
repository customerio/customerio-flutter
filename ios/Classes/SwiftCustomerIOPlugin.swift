import CioDataPipelines
import CioInternalCommon
import CioMessagingInApp
import Flutter
import UIKit

public class SwiftCustomerIOPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel!
    private var inAppMessagingChannelHandler: CustomerIOInAppMessaging!
    private var messagingPushChannelHandler: CustomerIOMessagingPush!

    private let logger: CioInternalCommon.Logger = DIGraphShared.shared.logger

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftCustomerIOPlugin()

        instance.methodChannel = FlutterMethodChannel(name: "customer_io", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)

        instance.inAppMessagingChannelHandler = CustomerIOInAppMessaging(with: registrar)
        instance.messagingPushChannelHandler = CustomerIOMessagingPush(with: registrar)
    }

    deinit {
        self.methodChannel.setMethodCallHandler(nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "clearIdentify":
            call.nativeNoArgs(result: result, handler: clearIdentify)

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
