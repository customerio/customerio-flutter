import Flutter
import Foundation
#if canImport(CioLiveActivities)
import ActivityKit
import CioLiveActivities
import CioLiveActivities_Attributes
import CioLiveActivities_Templates
#endif

/// Flutter plugin sub-handler for Live Activities.
///
/// Gated on `canImport(CioLiveActivities)` and iOS 16.2+. Custom activity types are rejected on
/// iOS because they require a native Widget Extension and an `adopt(_:)` call and cannot be
/// data-driven from Dart.
public class CustomerIOLiveActivities: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?

    #if canImport(CioLiveActivities)
    /// The held Live Activities module (not a singleton in the native SDK), created during SDK init.
    private var module: LiveActivitiesModule?

    /// Type-erased handles keyed by activity id. The native `start` returns a generic
    /// `CIOLiveActivity<Attributes>` that can't be stored in a homogeneous map, so we keep closures
    /// that capture the concrete handle and rebuild its content-state from a Dart map on update.
    private struct ActivityBox {
        let update: ([String: Any]) async throws -> Void
        let end: () async -> Void
    }

    private var activities: [String: ActivityBox] = [:]
    private let lock = NSLock()
    #endif

    public static func register(with _: FlutterPluginRegistrar) {}

    init(with registrar: FlutterPluginRegistrar) {
        super.init()

        let channel = FlutterMethodChannel(name: "customer_io_live_activities", binaryMessenger: registrar.messenger())
        methodChannel = channel
        registrar.addMethodCallDelegate(self, channel: channel)
    }

    deinit {
        methodChannel?.setMethodCallHandler(nil)
        methodChannel = nil
    }

    /// Initialize the Live Activities module from the SDK config's `liveActivities` key. Registers
    /// the enabled built-in template attribute types so `start` can request them.
    func initializeModule(params: [String: AnyHashable]) {
        #if canImport(CioLiveActivities)
        guard let laConfig = params["liveActivities"] as? [String: AnyHashable] else { return }
        guard #available(iOS 16.2, *) else { return }
        let templates = (laConfig["templates"] as? [String]) ?? []
        var builder = LiveActivityConfigBuilder()
        if templates.contains("segments") {
            builder = builder.register(CIOSegmentsAttributes.self)
        }
        if templates.contains("countdownTimer") {
            builder = builder.register(CIOCountdownTimerAttributes.self)
        }
        module = LiveActivitiesModule.initialize(builder.build())
        #endif
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start":
            start(args, result: result)

        case "update":
            update(args, result: result)

        case "end":
            end(args, result: result)

        case "startCustom":
            startCustom(args, result: result)

        case "handleDeepLinkOpen":
            handleDeepLinkOpen(args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Bridge methods

    private func start(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard #available(iOS 16.2, *), let module = module else {
            return result(Self.unavailableError())
        }
        guard let map = args["payload"] as? [String: Any], let type = map["type"] as? String else {
            return result(FlutterError(code: "live_activity_start_failed", message: "payload.type is required", details: nil))
        }
        do {
            let id: String
            switch type {
            case "segments":
                let handle = try module.start(
                    CIOSegmentsAttributes(header: map["header"] as? String ?? ""),
                    contentState: try Self.segmentsState(from: map)
                )
                store(handle: handle, contentBuilder: Self.segmentsState)
                id = handle.id
            case "countdownTimer":
                let handle = try module.start(
                    CIOCountdownTimerAttributes(header: map["header"] as? String ?? ""),
                    contentState: try Self.countdownState(from: map)
                )
                store(handle: handle, contentBuilder: Self.countdownState)
                id = handle.id
            default:
                return result(FlutterError(code: "live_activity_start_failed", message: "Unknown live activity template type: \(type)", details: nil))
            }
            result(id)
        } catch {
            result(FlutterError(code: "live_activity_start_failed", message: error.localizedDescription, details: nil))
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private func update(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard let activityId = args["activityId"] as? String else {
            return result(FlutterError(code: "live_activity_update_failed", message: "activityId is required", details: nil))
        }
        lock.lock()
        let box = activities[activityId]
        lock.unlock()
        guard let box = box else {
            return result(FlutterError(code: "live_activity_update_failed", message: "No live activity found for id \(activityId)", details: nil))
        }
        guard let map = args["payload"] as? [String: Any] else {
            return result(FlutterError(code: "live_activity_update_failed", message: "payload is required", details: nil))
        }
        Task {
            do {
                try await box.update(map)
                result(true)
            } catch {
                result(FlutterError(code: "live_activity_update_failed", message: error.localizedDescription, details: nil))
            }
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private func end(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard let activityId = args["activityId"] as? String else {
            return result(FlutterError(code: "live_activity_end_failed", message: "activityId is required", details: nil))
        }
        lock.lock()
        let box = activities.removeValue(forKey: activityId)
        lock.unlock()
        // Unknown/already-ended id is treated as success (idempotent end).
        guard let box = box else { return result(true) }
        Task {
            await box.end()
            result(true)
        }
        #else
        result(Self.unavailableError())
        #endif
    }

    private func startCustom(_: [String: Any], result: @escaping FlutterResult) {
        // Custom activity types on iOS require a native Widget Extension + ActivityAttributes and an
        // `adopt(_:)` call; they cannot be data-driven from Dart.
        result(FlutterError(
            code: "live_activity_custom_unsupported_ios",
            message: "Custom live activity types are not supported from Dart on iOS. Use a native Widget Extension and adopt().",
            details: nil
        ))
    }

    private func handleDeepLinkOpen(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard let urlString = args["url"] as? String, let module = module, let parsed = URL(string: urlString) else {
            return result(false)
        }
        result(module.handleDeepLinkOpen(parsed))
        #else
        result(false)
        #endif
    }

    // MARK: - Helpers

    #if canImport(CioLiveActivities)
    @available(iOS 16.2, *)
    private func store<A: ActivityAttributes>(
        handle: CIOLiveActivity<A>,
        contentBuilder: @escaping ([String: Any]) throws -> A.ContentState
    ) {
        let box = ActivityBox(
            update: { map in await handle.update(try contentBuilder(map)) },
            end: { await handle.end() }
        )
        lock.lock()
        activities[handle.id] = box
        lock.unlock()
    }

    @available(iOS 16.2, *)
    private static func segmentsState(from map: [String: Any]) throws -> CIOSegmentsAttributes.ContentState {
        CIOSegmentsAttributes.ContentState(
            status: map["status"] as? String ?? "",
            substatus: map["substatus"] as? String,
            segmentsTotal: intValue(map["segmentsTotal"]),
            segmentsComplete: intValue(map["segmentsComplete"]),
            trailingText: map["trailingText"] as? String
        )
    }

    @available(iOS 16.2, *)
    private static func countdownState(from map: [String: Any]) throws -> CIOCountdownTimerAttributes.ContentState {
        var endTime: EpochSecondsDate?
        if let seconds = map["endTime"] as? NSNumber {
            endTime = EpochSecondsDate(Date(timeIntervalSince1970: seconds.doubleValue))
        }
        return CIOCountdownTimerAttributes.ContentState(
            title: map["title"] as? String ?? "",
            statusMessage: map["statusMessage"] as? String,
            endTime: endTime
        )
    }

    private static func intValue(_ any: Any?) -> Int {
        (any as? NSNumber)?.intValue ?? 0
    }
    #endif

    private static func unavailableError() -> FlutterError {
        FlutterError(
            code: "live_activity_module_unavailable",
            message: "Live Activities are unavailable. Enable live activity templates in the SDK config and add the widget extension.",
            details: nil
        )
    }
}
