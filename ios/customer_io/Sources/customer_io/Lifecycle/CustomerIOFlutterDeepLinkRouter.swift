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
    private let usesApplicationRoot: Bool

    init(registrar: FlutterPluginRegistrar, usesApplicationRoot: Bool = false) {
        self.registrar = registrar
        self.usesApplicationRoot = usesApplicationRoot
    }

    @MainActor
    func route(_ url: URL) {
        route(url, remainingAttempts: Self.readinessAttempts)
    }

    @MainActor
    private func route(_ url: URL, remainingAttempts: Int) {
        let registeredViewController = registrar?.viewController as? FlutterViewController
        let viewController: FlutterViewController?
        if usesApplicationRoot {
            viewController = UIApplication.shared.delegate?
                .window??.rootViewController as? FlutterViewController ?? registeredViewController
        } else {
            viewController = registeredViewController
        }
        guard let viewController else {
            retryOrReportUnavailable(url, remainingAttempts: remainingAttempts)
            return
        }

        guard viewController.isDisplayingFlutterUI else {
            retryOrReportUnavailable(url, remainingAttempts: remainingAttempts)
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

    @MainActor
    private func retryOrReportUnavailable(_ url: URL, remainingAttempts: Int) {
        guard remainingAttempts > 0 else {
            DIGraphShared.shared.logger.error(
                "Customer.io could not access a ready Flutter engine for the Live Activity redirect"
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self, url] in
            MainActor.assumeIsolated {
                self?.route(url, remainingAttempts: remainingAttempts - 1)
            }
        }
    }
}
