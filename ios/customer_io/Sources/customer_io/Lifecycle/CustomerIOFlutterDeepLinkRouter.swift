import CioInternalCommon
import Flutter
import Foundation
import UIKit

/// Routes URLs through Flutter view controllers displaying rendered UI. Cold callbacks wait up to
/// three seconds for a controller; a foreground controller hidden by native UI is then eligible.
///
/// Flutter bounds its own first-frame wait at three seconds when delivering an incoming deep link.
/// Use the same boundary because a cold callback can arrive before Dart installs its navigation
/// handler, without retaining a stale activation indefinitely.
final class CustomerIOFlutterDeepLinkRouter {
    private static let retryInterval = 0.05
    private static let readinessAttempts = 60

    @MainActor
    func route(_ url: URL, in scene: UIScene) {
        route(url, in: scene, remainingAttempts: Self.readinessAttempts)
    }

    /// Delivers an SDK-triggered destination to an eligible foreground Flutter scene. If Flutter
    /// declines it or no scene becomes eligible, the destination is opened through UIKit.
    func routeSDKDeepLink(_ url: URL) {
        DispatchQueue.main.async { [weak self, url] in
            self?.routeSDKDeepLink(url, remainingAttempts: Self.readinessAttempts)
        }
    }

    @MainActor
    private func routeSDKDeepLink(_ url: URL, remainingAttempts: Int) {
        let useHiddenFallback = remainingAttempts == 0
        guard let viewController = applicationFlutterViewController(
            useHiddenFallback: useHiddenFallback
        ) else {
            guard remainingAttempts > 0 else {
                DIGraphShared.shared.logger.error(
                    "Customer.io could not access a foreground Flutter engine for the SDK deep link"
                )
                openExternally(url)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self, url] in
                self?.routeSDKDeepLink(url, remainingAttempts: remainingAttempts - 1)
            }
            return
        }

        deliver(url, to: viewController) { [weak self] in
            DIGraphShared.shared.logger.info(
                "Customer.io is opening an SDK deep link externally because Flutter did not handle it"
            )
            self?.openExternally(url)
        }
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

        deliver(url, to: viewController) {
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
    private func applicationFlutterViewController(
        useHiddenFallback: Bool
    ) -> FlutterViewController? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        let candidates = [UIScene.ActivationState.foregroundActive, .foregroundInactive]
            .flatMap { activationState in
                windowScenes
                    .filter { $0.activationState == activationState }
                    .flatMap(sceneFlutterViewControllers)
            }

        return candidates.first(where: \.isDisplayingFlutterUI) ??
            (useHiddenFallback ? candidates.first : nil)
    }

    @MainActor
    private func deliver(
        _ url: URL,
        to viewController: FlutterViewController,
        onUnhandled: @escaping () -> Void
    ) {
        viewController.engine.navigationChannel.invokeMethod(
            "pushRouteInformation",
            arguments: ["location": url.absoluteString]
        ) { result in
            guard CustomerIOURLRouting.didFlutterHandle(result) else {
                onUnhandled()
                return
            }
        }
    }

    @MainActor
    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url) { opened in
            guard !opened else { return }
            DIGraphShared.shared.logger.error(
                "Customer.io could not open the SDK deep link externally"
            )
        }
    }

    @MainActor
    private func sceneFlutterViewControllers(in scene: UIScene) -> [FlutterViewController] {
        guard let windowScene = scene as? UIWindowScene else { return [] }

        return flutterViewControllers(from: windowScene.windows.compactMap(\.rootViewController))
    }

    @MainActor
    private func flutterViewControllers(from roots: [UIViewController]) -> [FlutterViewController] {
        CustomerIOViewControllerTraversal.topmostFirst(
            roots: roots,
            presentedViewController: \.presentedViewController,
            children: \.children
        ).compactMap { $0 as? FlutterViewController }
    }
}
