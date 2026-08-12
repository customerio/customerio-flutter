import Flutter
import UIKit

/// Fixture-only ownership for the canonical Swift trace stream.
///
/// The recorder is armed from whichever real bootstrap seat occurs first. In
/// the legacy configuration that is the implicit-engine callback. In the scene
/// configuration UIKit reaches the already-owned Customer.io app-delegate
/// wrapper first. This preserves the platform's actual callback order.
enum LifecycleTraceFlutterFixture {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var rawLaunchObserver: NSObjectProtocol?
        var launchObserver: NSObjectProtocol?
        var activeObserver: NSObjectProtocol?
    }

    private static let state = State()

    @discardableResult
    static func startIfConfigured() -> Bool {
        guard LifecycleTraceHarness.configureFromEnvironment(sink: ConsoleLifecycleTraceSink()) != nil else {
            return false
        }
        installRawLaunchObserverOnce()
        installLaunchObserverOnce()
        installActiveObserverOnce()
        return LifecycleTraceHarness.startScenario()
            || LifecycleTraceHarness.sharedRecorder != nil
    }

    private static func installRawLaunchObserverOnce() {
        state.lock.lock()
        defer { state.lock.unlock() }
        guard state.rawLaunchObserver == nil else { return }

        let center = NotificationCenter.default
        state.rawLaunchObserver = center.addObserver(
            forName: LifecycleTraceRawLaunchMarker.notificationName,
            object: center,
            queue: .main
        ) { notification in
            guard let recorder = LifecycleTraceHarness.sharedRecorder,
                  let facts = LifecycleTraceRawLaunchMarker.decode(
                    notification,
                    center: center,
                    expectedProcessInstanceID: recorder.processInstanceID
                  ) else { return }
            _ = LifecycleTraceProbe.post(
                callback: .applicationDidFinishLaunching,
                owner: .applicationDelegate,
                kind: .osCallback,
                phase: .entry,
                observations: LifecycleTraceObservation(
                    flags: [.hasLaunchOptions: facts.hasLaunchOptions],
                    counts: [.launchOptionKeys: facts.launchOptionKeys],
                    enums: [.appState: facts.appState]
                )
            )
        }
    }

    private static func installLaunchObserverOnce() {
        state.lock.lock()
        defer { state.lock.unlock() }
        guard state.launchObserver == nil else { return }

        let center = NotificationCenter.default
        state.launchObserver = center.addObserver(
            forName: UIApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            _ = LifecycleTraceProbe.post(
                callback: .uikitApplicationDidFinishLaunchingNotification,
                owner: .uikitNotification,
                kind: .observerNotification,
                phase: .entry,
                observations: LifecycleTraceEvidence.observe(applicationState: UIApplication.shared.applicationState)
            )
        }
    }

    private static func installActiveObserverOnce() {
        state.lock.lock()
        defer { state.lock.unlock() }
        guard state.activeObserver == nil else { return }

        let center = NotificationCenter.default
        state.activeObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            _ = LifecycleTraceProbe.post(
                callback: .uikitApplicationDidBecomeActiveNotification,
                owner: .uikitNotification,
                kind: .observerNotification,
                phase: .stateChange,
                observations: LifecycleTraceEvidence.observe(applicationState: UIApplication.shared.applicationState)
            )
            LifecycleTraceHarness.endScenario(after: .activeScene)
        }

        LifecycleTraceHarness.registerEndCleanup {
            state.lock.lock()
            defer { state.lock.unlock() }
            if let observer = state.rawLaunchObserver {
                center.removeObserver(observer)
                state.rawLaunchObserver = nil
            }
            if let observer = state.launchObserver {
                center.removeObserver(observer)
                state.launchObserver = nil
            }
            guard let observer = state.activeObserver else { return }
            center.removeObserver(observer)
            state.activeObserver = nil
        }
    }
}
