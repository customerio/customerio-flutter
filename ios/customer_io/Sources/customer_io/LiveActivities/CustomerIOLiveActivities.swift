import CioDataPipelines
import CioInternalCommon
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
/// Gated on `canImport(CioLiveActivities)` and iOS 16.2+. Custom activity types work from Dart
/// through the SDK-owned `CIOCustomAttributes`: ActivityKit needs a concrete Swift type to register
/// an activity and observe its push-to-start token, and a metatype can't cross a method channel, so
/// the SDK owns the type and Dart supplies its values.
public class CustomerIOLiveActivities: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?

    #if canImport(CioLiveActivities)
    /// Reverse-DNS activity type identifiers for the SDK's built-in templates. These are the same
    /// strings the backend sends as `notificationType` and that Android's `LiveNotificationType`
    /// exposes, so Dart, both native SDKs, and the wire format share one vocabulary.
    enum TypeIdentifier {
        static let segments = "io.customer.livenotifications.segments"
        static let countdownTimer = "io.customer.livenotifications.countdowntimer"
        /// Discriminator Dart sends for the custom template. Not a wire identifier — the activity is
        /// reported under the app's own `liveNotifications.customType`.
        static let custom = "custom"
    }

    /// Type-erased handles keyed by activity id. The native `start` returns a generic
    /// `CIOLiveActivity<Attributes>` that can't be stored in a homogeneous map, so we keep closures
    /// that capture the concrete handle and rebuild its content-state from a Dart map on update.
    private struct ActivityBox {
        let update: ([String: Any]) async throws -> Void
        let end: ([String: Any]?) async throws -> Void
    }

    private var activities: [String: ActivityBox] = [:]
    private let lock = NSLock()

    /// Records an `update`/`end` aimed at an activity this process never started. Not surfaced to
    /// Dart — see the call sites — but worth a log, because the same message covers both a genuine
    /// caller mistake and the expected post-restart / push-started cases.
    private static func logUnknownActivity(_ activityId: String, method: String) {
        DIGraphShared.shared.logger.info(
            "Live Activities: \(method) ignored — no activity with id \(activityId) was started by this app session. " +
                "Activities started before an app restart, or started by a push, are not tracked in-process."
        )
    }
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
        // The custom template registers one SDK-owned Swift type under the app's own identifier.
        // That indirection is what lets a Dart app have a custom activity at all: the SDK needs a
        // metatype to register and to observe push-to-start for, and a metatype can't cross a
        // method channel.
        //
        // Nothing is cached from this: `start` learns that a custom activity isn't registered from
        // the nil handle the SDK returns, which stays correct if the type was registered elsewhere.
        if let customType = (liveConfig["customType"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !customType.isEmpty {
            builder = builder.register(CIOCustomAttributes.self, identifier: customType)
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
                    CIOSegmentsAttributes(header: try Self.requireString(map, "header")),
                    contentState: try Self.segmentsState(from: map)
                ) else {
                    return result(Self.notRegisteredError(type))
                }
                store(handle: handle, contentBuilder: Self.segmentsState)
                id = handle.id
            case TypeIdentifier.countdownTimer:
                guard let handle = try CustomerIO.liveActivities.start(
                    CIOCountdownTimerAttributes(header: try Self.requireString(map, "header")),
                    contentState: try Self.countdownState(from: map)
                ) else {
                    return result(Self.notRegisteredError(type))
                }
                store(handle: handle, contentBuilder: Self.countdownState)
                id = handle.id
            case TypeIdentifier.custom:
                // No pre-check on the configured identifier: an unregistered type already comes back
                // as a nil handle, and that path is correct however the SDK was initialized — a
                // check against wrapper-captured config would refuse a type registered elsewhere.
                guard let handle = try CustomerIO.liveActivities.start(
                    CIOCustomAttributes(),
                    contentState: try Self.customState(from: map)
                ) else {
                    return result(Self.customNotRegisteredError())
                }
                store(handle: handle, contentBuilder: Self.customState)
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
        // An unknown id means the update did not happen, so it must not report success. Unlike `end`
        // — where re-ending an already-ended activity is a legitimate no-op — there is nothing
        // idempotent about an update that never applied. Android *does* perform it (it routes the id
        // straight to the native SDK), so resolving here would make the same call report success on
        // both platforms while only one of them did anything.
        guard let box = box else {
            Self.logUnknownActivity(activityId, method: "update")
            return result(FlutterError(
                code: "live_activity_update_failed",
                message: "No live activity found for id \(activityId). On iOS only activities started " +
                    "in this app session can be updated.",
                details: nil
            ))
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
        let box = activities[activityId]
        lock.unlock()
        // Unknown/already-ended id is treated as success (idempotent end). See `update` for why an
        // unknown id is not an error.
        guard let box = box else {
            Self.logUnknownActivity(activityId, method: "end")
            return result(true)
        }
        let map = args["payload"] as? [String: Any]
        Task {
            // FlutterResult must be invoked on the platform (main) thread; the Task
            // resumes off-main after the await, so hop back before replying.
            do {
                try await box.end(map)
                // Dropped only once the end succeeded. Removing up front would lose the handle on a
                // throw, and the retry would then take the unknown-id path above and report success
                // for an activity still on screen.
                self.forget(activityId)
                await MainActor.run { result(true) }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "live_activity_end_failed", message: error.localizedDescription, details: nil))
                }
            }
        }
        #else
        result(Self.unavailableError())
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
            // ActivityKit keeps the last content-state on screen when `end` is given none, so a
            // final payload is what lets the activity show a terminal state rather than freezing
            // mid-progress.
            update: { map in await handle.update(try contentBuilder(map)) },
            end: { map in await handle.end(try map.map(contentBuilder)) }
        )
        lock.lock()
        activities[handle.id] = box
        lock.unlock()
    }

    private func forget(_ activityId: String) {
        lock.lock()
        activities.removeValue(forKey: activityId)
        lock.unlock()
    }

    /// Thrown for a missing required field so the caller sees an error naming it, rather than an
    /// activity rendering with a blank line. Matches Android, whose `requireString` / `requireInt`
    /// already throw — the same call must not produce a silent half-rendered card on one platform
    /// and an error on the other.
    private struct MissingFieldError: LocalizedError {
        let field: String
        var errorDescription: String? { "\(field) is required" }
    }

    private static func requireString(_ map: [String: Any], _ key: String) throws -> String {
        guard let value = map[key] as? String else { throw MissingFieldError(field: key) }
        return value
    }

    private static func requireInt(_ map: [String: Any], _ key: String) throws -> Int {
        guard let value = map[key] as? NSNumber else { throw MissingFieldError(field: key) }
        return value.intValue
    }

    @available(iOS 16.2, *)
    private static func segmentsState(from map: [String: Any]) throws -> CIOSegmentsAttributes.ContentState {
        CIOSegmentsAttributes.ContentState(
            status: try requireString(map, "status"),
            substatus: map["substatus"] as? String,
            segmentsTotal: try requireInt(map, "segmentsTotal"),
            segmentsComplete: try requireInt(map, "segmentsComplete"),
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
            title: try requireString(map, "title"),
            statusMessage: map["statusMessage"] as? String,
            endTime: endTime
        )
    }

    /// Builds the custom template's content-state from the payload's `data` map.
    ///
    /// Values are coerced to strings rather than rejected: a Dart `int`/`double`/`bool` arrives as
    /// `NSNumber`, and refusing them would make `{'eta': 5}` fail for no reason a caller can see.
    /// Anything without a sensible text form is dropped instead of stringifying as gibberish.
    @available(iOS 16.2, *)
    private static func customState(from map: [String: Any]) throws -> CIOCustomAttributes.ContentState {
        let raw = map["data"] as? [String: Any] ?? [:]
        var data: [String: String] = [:]
        for (key, value) in raw {
            switch value {
            case let string as String: data[key] = string
            case let number as NSNumber: data[key] = number.stringValue
            default: continue
            }
        }
        return CIOCustomAttributes.ContentState(data: data)
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

    /// The custom template's version of [notRegisteredError]: `type` is only the discriminator, so
    /// naming it would tell the caller nothing about what to fix.
    private static func customNotRegisteredError() -> FlutterError {
        FlutterError(
            code: "live_activity_type_not_registered",
            message: "No custom Live Activity type is registered. Set `liveNotifications.customType` " +
                "in your Customer.io SDK config to your own reverse-DNS identifier, and render " +
                "CIOCustomAttributes in your Widget Extension.",
            details: nil
        )
    }
}
