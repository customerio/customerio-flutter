import CioInternalCommon
import Flutter
import Foundation
import UIKit

/// Routes a URL through the first Flutter view controller displaying UI in the callback's scene,
/// falling back to the scene's first Flutter controller after Flutter's first-frame wait expires.
///
/// Flutter bounds its own first-frame wait at three seconds when delivering an incoming deep link.
/// Mirror that behavior because a cold UIScene callback can arrive before Dart has installed the
/// navigation-channel handler; after that boundary, log rather than retaining a stale activation.
final class CustomerIOFlutterDeepLinkRouter {
    private static let retryInterval = 0.05
    private static let readinessAttempts = 60

    @MainActor
    func route(_ url: URL, in scene: UIScene) {
        route(url, in: scene, remainingAttempts: Self.readinessAttempts)
    }

    @MainActor
    private func route(_ url: URL, in scene: UIScene, remainingAttempts: Int) {
        let useHiddenFallback = remainingAttempts == 0
        guard let viewController = deliveryViewController(
            in: scene,
            useHiddenFallback: useHiddenFallback
        ) else {
            guard remainingAttempts > 0 else {
                DIGraphShared.shared.logger.error(
                    "Customer.io could not access a Flutter engine for the Live Activity redirect"
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self, weak scene, url] in
                guard let scene else { return }
                self?.route(url, in: scene, remainingAttempts: remainingAttempts - 1)
            }
            return
        }

        let navigationChannel = viewController.engine.navigationChannel
        navigationChannel.invokeMethod(
            "pushRouteInformation",
            arguments: ["location": url.absoluteString]
        ) { result in
            guard (result as? NSNumber)?.boolValue != true else { return }
            DIGraphShared.shared.logger.error(
                "Customer.io delivered the Live Activity redirect to Flutter, but the host did not handle it"
            )
        }
    }

    @MainActor
    private func deliveryViewController(
        in scene: UIScene,
        useHiddenFallback: Bool
    ) -> FlutterViewController? {
        let candidates = sceneFlutterViewControllers(in: scene)
        return candidates.first(where: \.isDisplayingFlutterUI) ??
            (useHiddenFallback ? candidates.first : nil)
    }

    @MainActor
    private func sceneFlutterViewControllers(in scene: UIScene) -> [FlutterViewController] {
        guard let windowScene = scene as? UIWindowScene else { return [] }

        var pending = windowScene.windows.compactMap(\.rootViewController)
        var matches: [FlutterViewController] = []
        while !pending.isEmpty {
            let viewController = pending.removeFirst()
            if let flutterViewController = viewController as? FlutterViewController {
                matches.append(flutterViewController)
            }
            if let presented = viewController.presentedViewController {
                pending.append(presented)
            }
            pending.append(contentsOf: viewController.children)
        }
        return matches
    }
}
