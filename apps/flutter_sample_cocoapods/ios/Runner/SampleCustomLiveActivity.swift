import Flutter
import Foundation
#if canImport(CioLiveActivities)
import ActivityKit
import CioLiveActivities
#endif

/// App-owned handler for the sample's custom "rideshare" Live Activity, exposed to Dart over a
/// MethodChannel (`sample_custom_live_activity`).
///
/// Custom (app-defined) Live Activity types on iOS are NOT driven through the Customer.io Flutter
/// wrapper — they require a native Widget Extension + `ActivityAttributes`. So the sample app owns
/// the whole flow here: it holds its OWN `LiveActivitiesModule`, registers ``RideshareAttributes``,
/// and drives start/update/end via ActivityKit. Because the type is registered with the module, the
/// Customer.io SDK still observes these activities and reports their lifecycle.
class SampleCustomLiveActivity: NSObject {
    private var methodChannel: FlutterMethodChannel?

    #if canImport(CioLiveActivities)
    private var module: LiveActivitiesModule?
    // id -> CIOLiveActivity<RideshareAttributes>, stored as Any to avoid annotating the property.
    private var activities: [String: Any] = [:]
    #endif

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "sample_custom_live_activity", binaryMessenger: messenger)
        methodChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        #if canImport(CioLiveActivities)
        if #available(iOS 16.2, *) {
            module = LiveActivitiesModule.initialize(
                LiveActivityConfigBuilder()
                    .register(RideshareAttributes.self, identifier: RideshareAttributes.identifier)
                    .build()
            )
        }
        #endif
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startRideshare":
            startRideshare(args, result: result)
        case "updateRideshare":
            updateRideshare(args, result: result)
        case "endRideshare":
            endRideshare(args, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startRideshare(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard #available(iOS 16.2, *), let module = module else {
            return result(Self.unavailableError())
        }
        let attributes = RideshareAttributes(driverName: args["driverName"] as? String ?? "Your driver")
        let state = RideshareAttributes.ContentState(
            status: args["status"] as? String ?? "",
            etaMinutes: Self.intValue(args["etaMinutes"])
        )
        do {
            let handle = try module.start(attributes, contentState: state)
            activities[handle.id] = handle
            result(handle.id)
        } catch {
            result(FlutterError(code: "rideshare_start_failed", message: error.localizedDescription, details: nil))
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private func updateRideshare(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard #available(iOS 16.2, *) else { return result(Self.unavailableError()) }
        guard let id = args["activityId"] as? String,
              let handle = activities[id] as? CIOLiveActivity<RideshareAttributes> else {
            return result(FlutterError(code: "rideshare_update_failed", message: "No rideshare activity for id", details: nil))
        }
        let state = RideshareAttributes.ContentState(
            status: args["status"] as? String ?? "",
            etaMinutes: Self.intValue(args["etaMinutes"])
        )
        Task {
            await handle.update(state)
            result(true)
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private func endRideshare(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard #available(iOS 16.2, *) else { return result(Self.unavailableError()) }
        guard let id = args["activityId"] as? String,
              let handle = activities.removeValue(forKey: id) as? CIOLiveActivity<RideshareAttributes> else {
            // Unknown/already-ended id is idempotent success.
            return result(true)
        }
        Task {
            await handle.end()
            result(true)
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private static func intValue(_ any: Any?) -> Int {
        (any as? NSNumber)?.intValue ?? 0
    }

    private static func unavailableError() -> FlutterError {
        FlutterError(
            code: "rideshare_unavailable",
            message: "Custom Live Activities require iOS 16.2+ and the CioLiveActivities module.",
            details: nil
        )
    }
}
