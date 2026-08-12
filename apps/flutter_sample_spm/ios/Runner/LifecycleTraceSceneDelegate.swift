import Flutter
import UIKit

/// Scene fixture that observes FlutterSceneDelegate's existing will-connect seat.
@objc(LifecycleTraceSceneDelegate)
final class LifecycleTraceSceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        let observations = [
            LifecycleTraceEvidence.observe(scene: scene, callback: .sceneWillConnect),
            LifecycleTraceEvidence.observe(connectedScenes: UIApplication.shared.connectedScenes),
            LifecycleTraceEvidence.observe(connectionOptions: connectionOptions)
        ]
        _ = LifecycleTraceProbe.post(
            callback: .sceneWillConnect,
            owner: .sceneDelegate,
            kind: .osCallback,
            phase: .entry,
            observations: observations[0], observations[1], observations[2]
        )
        _ = LifecycleTraceProbe.post(
            callback: .flutterSceneWillConnectForwarded,
            owner: .flutterPlugin,
            kind: .frameworkCallback,
            phase: .entry,
            observations: observations[0], observations[1], observations[2]
        )
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
