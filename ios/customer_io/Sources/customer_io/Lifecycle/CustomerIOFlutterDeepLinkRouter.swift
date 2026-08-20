import CioInternalCommon
import Flutter
import Foundation
import UIKit

/// Routes a URL through the Flutter engine associated with this plugin registration.
///
/// Flutter bounds its own first-frame wait at three seconds when delivering an incoming deep link.
/// Mirror that behavior because a cold UIScene callback can arrive before Dart has installed the
/// navigation-channel handler; after that boundary, log rather than retaining a stale activation.
final class CustomerIOFlutterDeepLinkRouter {
    private static let retryInterval = 0.05
    private static let readinessAttempts = 60

    private weak var registrar: FlutterPluginRegistrar?

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    @MainActor
    func route(_ url: URL, in scene: UIScene) {
        route(url, in: scene, remainingAttempts: Self.readinessAttempts)
    }

    @MainActor
    private func route(_ url: URL, in scene: UIScene, remainingAttempts: Int) {
        guard let viewController = readyViewController(in: scene) else {
            retryOrReportUnavailable(url, in: scene, remainingAttempts: remainingAttempts)
            return
        }

        viewController.engine.navigationChannel.invokeMethod(
            "pushRouteInformation",
            arguments: ["location": url.absoluteString]
        ) { result in
            guard (result as? NSNumber)?.boolValue != true else { return }
            DIGraphShared.shared.logger.error(
                "Customer.io delivered the Live Activity redirect to Flutter, but the host did not handle it"
            )
        }
    }

    private var registeredViewController: FlutterViewController? {
        let selector = NSSelectorFromString("viewController")
        guard let registrar, registrar.responds(to: selector) else { return nil }
        return registrar.perform(selector)?.takeUnretainedValue() as? FlutterViewController
    }

    @MainActor
    private func readyViewController(in scene: UIScene) -> FlutterViewController? {
        var candidates: [FlutterViewController] = []
        if let registeredViewController {
            candidates.append(registeredViewController)
        }
        candidates.append(contentsOf: sceneFlutterViewControllers(in: scene))

        var seen: Set<ObjectIdentifier> = []
        return candidates.first { candidate in
            seen.insert(ObjectIdentifier(candidate)).inserted && candidate.isDisplayingFlutterUI
        }
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

    @MainActor
    private func retryOrReportUnavailable(
        _ url: URL,
        in scene: UIScene,
        remainingAttempts: Int
    ) {
        guard remainingAttempts > 0 else {
            DIGraphShared.shared.logger.error(
                "Customer.io could not access a ready Flutter engine for the Live Activity redirect"
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self, weak scene, url] in
            guard let scene else { return }
            self?.route(url, in: scene, remainingAttempts: remainingAttempts - 1)
        }
    }
}
