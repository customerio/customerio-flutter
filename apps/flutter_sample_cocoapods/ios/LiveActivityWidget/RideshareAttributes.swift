import ActivityKit
import Foundation

/// Attributes for the sample app's custom "rideshare" Live Activity.
///
/// Custom (app-defined) Live Activity types on iOS are entirely app-owned: they require a native
/// Widget Extension + `ActivityAttributes` and cannot be data-driven from Dart through the
/// Customer.io wrapper. Add this one source file to BOTH the Runner (app) target and the
/// LiveActivityWidget (extension) target so both can reference the type.
@available(iOS 16.2, *)
struct RideshareAttributes: ActivityAttributes {
    /// Reverse-DNS type identifier, matching the `customTypes` entry registered with the SDK and the
    /// identifier used when registering this type with `LiveActivitiesModule`.
    static let identifier = "io.customer.livenotifications.custom.rideshare"

    /// Driver name — a static attribute, fixed for the life of the activity.
    var driverName: String

    /// The parts of the activity that change on every update.
    struct ContentState: Codable, Hashable {
        var status: String
        var etaMinutes: Int
    }
}
