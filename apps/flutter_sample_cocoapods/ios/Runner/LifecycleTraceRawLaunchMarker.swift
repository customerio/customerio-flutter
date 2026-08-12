import Foundation

/// Safe values decoded from the fixture-only raw application-launch marker.
struct LifecycleTraceRawLaunchFacts {
    let appState: String
    let hasLaunchOptions: Bool
    let launchOptionKeys: Int
}

/// Authenticates the private in-process marker before it can define raw ingress.
///
/// The generated dependency patch posts through the process's default center and
/// carries the harness process-instance ID. Both are required so an unrelated
/// notification with the same private name cannot fabricate the canonical seat.
enum LifecycleTraceRawLaunchMarker {
    static let notificationName = Notification.Name("io.customer.lifecycle-trace.fixture.raw-did-finish")

    static func decode(
        _ notification: Notification,
        center: NotificationCenter,
        expectedProcessInstanceID: String
    ) -> LifecycleTraceRawLaunchFacts? {
        guard notification.object as AnyObject? === center,
              let processInstanceID = notification.userInfo?["process_instance_id"] as? String,
              processInstanceID == expectedProcessInstanceID,
              let appState = notification.userInfo?["app_state"] as? String,
              let hasLaunchOptions = notification.userInfo?["has_launch_options"] as? Bool,
              let launchOptionKeys = notification.userInfo?["launch_option_keys"] as? Int else {
            return nil
        }
        return LifecycleTraceRawLaunchFacts(
            appState: appState,
            hasLaunchOptions: hasLaunchOptions,
            launchOptionKeys: launchOptionKeys
        )
    }
}
