import CioDataPipelines
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
    /// Reverse-DNS activity type identifiers for the SDK's built-in templates. These are the same
    /// strings the backend sends as `notificationType` and that Android's `LiveNotificationType`
    /// exposes, so Dart, both native SDKs, and the wire format share one vocabulary.
    enum TypeIdentifier {
        static let segments = "io.customer.livenotifications.segments"
        static let countdownTimer = "io.customer.livenotifications.countdowntimer"
    }

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

    /// Reports an `opened` metric for a tapped Live Activity and returns the deep link to route to.
    /// Call this from the app's `openURL` entry point so a Live Activity tap is attributed.
    ///
    /// - Returns: the customer's redirect URL for a Customer.io widget URL (`nil` when it carries
    ///   none), or `url` unchanged when it isn't a Customer.io URL — so existing routing still
    ///   handles non-CIO links.
    #if canImport(CioLiveActivities)
    @discardableResult
    public static func handleWidgetUrl(_ url: URL) -> URL? {
        CustomerIO.liveActivities.handleWidgetUrl(url)
    }
    #else
    public static func handleWidgetUrl(_ url: URL) -> URL? { url }
    #endif

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

    #if canImport(CioLiveActivities)
    /// Build the Live Activities module from the SDK config's `liveNotifications` key, for
    /// registration on the SDK config builder at init. Registers the enabled built-in template
    /// attribute types so `CustomerIO.liveActivities.start` can request them, and so push-to-start
    /// tokens register for them at SDK init.
    ///
    /// Unrecognized type identifiers are ignored: a newer native SDK may ship templates this
    /// wrapper build doesn't know, and that must never break registration of the ones it does.
    static func module(from params: [String: AnyHashable]) -> LiveActivitiesModule? {
        guard let liveConfig = params["liveNotifications"] as? [String: AnyHashable] else { return nil }
        guard #available(iOS 16.2, *) else { return nil }
        let types = (liveConfig["types"] as? [String]) ?? []
        var builder = LiveActivityConfigBuilder()
        for type in types {
            switch type {
            case TypeIdentifier.segments:
                builder = builder.register(CIOSegmentsAttributes.self)
            case TypeIdentifier.countdownTimer:
                builder = builder.register(CIOCountdownTimerAttributes.self)
            default:
                continue
            }
        }
        return LiveActivitiesModule(config: builder.build())
    }
    #endif

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

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Bridge methods

    private func start(_ args: [String: Any], result: @escaping FlutterResult) {
        #if canImport(CioLiveActivities)
        guard #available(iOS 16.2, *) else {
            return result(Self.unavailableError())
        }
        guard let map = args["payload"] as? [String: Any], let type = map["type"] as? String else {
            return result(FlutterError(code: "live_activity_start_failed", message: "payload.type is required", details: nil))
        }
        do {
            // A nil handle means the module isn't registered or this type wasn't enabled. The
            // native SDK logs and returns nil rather than throwing, so surface it as a
            // FlutterError — never a crash.
            let id: String
            switch type {
            case TypeIdentifier.segments:
                guard let handle = try CustomerIO.liveActivities.start(
                    CIOSegmentsAttributes(header: map["header"] as? String ?? ""),
                    contentState: try Self.segmentsState(from: map)
                ) else {
                    return result(Self.notRegisteredError(type))
                }
                store(handle: handle, contentBuilder: Self.segmentsState)
                id = handle.id
            case TypeIdentifier.countdownTimer:
                guard let handle = try CustomerIO.liveActivities.start(
                    CIOCountdownTimerAttributes(header: map["header"] as? String ?? ""),
                    contentState: try Self.countdownState(from: map)
                ) else {
                    return result(Self.notRegisteredError(type))
                }
                store(handle: handle, contentBuilder: Self.countdownState)
                id = handle.id
            default:
                // A newer native SDK may know this type even though this wrapper build doesn't.
                // Fail softly so an unrecognized template can never crash the host app.
                return result(FlutterError(
                    code: "live_activity_type_unsupported",
                    message: "Unsupported Live Activity template: \(type)",
                    details: nil
                ))
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
                // FlutterResult must be invoked on the platform (main) thread; the Task
                // resumes off-main after the await, so hop back before replying.
                await MainActor.run { result(true) }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "live_activity_update_failed", message: error.localizedDescription, details: nil))
                }
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
            // FlutterResult must be invoked on the platform (main) thread; the Task
            // resumes off-main after the await, so hop back before replying.
            await MainActor.run { result(true) }
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
            message: "Live Activities require iOS 16.2 or later.",
            details: nil
        )
    }

    private static func notRegisteredError(_ type: String) -> FlutterError {
        FlutterError(
            code: "live_activity_type_not_registered",
            message: "Live Activity type '\(type)' is not registered. Add it to `liveNotifications.types` " +
                "in your Customer.io SDK config, and make sure your widget extension renders it.",
            details: nil
        )
    }
}
