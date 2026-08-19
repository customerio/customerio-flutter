import Flutter
import OSLog
import UIKit

/// Standard Flutter scene host with the minimal logs used by the Xcode 27 launch proof.
final class SceneDelegate: FlutterSceneDelegate {
    private let logger = Logger(
        subsystem: "io.customer.flutter.fixture",
        category: "scene-lifecycle"
    )
    private let runToken = ProcessInfo.processInfo.environment["CIO_SCENE_HANDLER_RUN_TOKEN"] ?? "none"

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        logger.notice(
            "customerio-flutter-scene-will-connect token=\(self.runToken, privacy: .public)"
        )
        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        logger.notice(
            "customerio-flutter-scene-did-become-active token=\(self.runToken, privacy: .public)"
        )
        super.sceneDidBecomeActive(scene)
    }
}
