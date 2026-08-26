import Flutter
import OSLog
import UIKit
import UserNotifications

/// Standard Flutter scene host with the minimal logs used by the Xcode 27 launch proof.
final class SceneDelegate: FlutterSceneDelegate {
    private static var didRequestNotificationPermissionForE2E = false

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

        // The E2E launch flag requests the real system prompt once a scene can present it.
        guard !Self.didRequestNotificationPermissionForE2E,
              ProcessInfo.processInfo.arguments.contains(where: {
                  $0.hasPrefix("--cio-e2e-request-notification-permission")
              }) else { return }

        Self.didRequestNotificationPermissionForE2E = true
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }
}
