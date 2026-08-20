import CioInternalCommon
import Flutter
import UIKit

/// Routes Flutter application and scene activation callbacks through the lifecycle declared by
/// the host application's standard `UIApplicationSceneManifest`.
final class CustomerIOFlutterLifecycle: NSObject {
    private static let sceneManifestInfoPlistKey = "UIApplicationSceneManifest"

    @MainActor
    private static let sceneOccurrenceResults = CustomerIOSceneOccurrenceResults()

    private let usesUIScene: Bool
    private let usesFlutterDeepLinking: Bool

    var shouldRegisterSceneDelegate: Bool {
        CustomerIOLifecycleSeatSelection.shouldRegisterSceneDelegate(
            hasSceneManifest: usesUIScene,
            flutterDeepLinkingEnabled: usesFlutterDeepLinking
        )
    }

    private var deepLinkRouter: CustomerIOFlutterDeepLinkRouter?

    init(bundle: Bundle = .main) {
        usesUIScene = bundle.object(
            forInfoDictionaryKey: Self.sceneManifestInfoPlistKey
        ) != nil
        let configuredValue = bundle.object(
            forInfoDictionaryKey: "FlutterDeepLinkingEnabled"
        )
        usesFlutterDeepLinking = CustomerIOURLRouting.isFlutterDeepLinkingEnabled(configuredValue)
        super.init()
    }

    func configureRedirectRouting(with registrar: FlutterPluginRegistrar) {
        guard shouldRegisterSceneDelegate else { return }
        deepLinkRouter = CustomerIOFlutterDeepLinkRouter(registrar: registrar)
    }

    func reportUnavailableSceneRegistration() {
        guard usesUIScene else { return }
        DIGraphShared.shared.logger.error(
            "Customer.io UIScene routing requires Flutter 3.44.8 or newer"
        )
    }

    @available(iOS 13.0, *)
    @MainActor
    func handleSceneConnection(
        _ connectionOptions: UIScene.ConnectionOptions?,
        in scene: UIScene
    ) -> Bool {
        guard usesUIScene, let connectionOptions else { return false }
        guard CustomerIOURLRouting.canClaimColdConnection(
            urlCount: connectionOptions.urlContexts.count,
            userActivityCount: connectionOptions.userActivities.count,
            hasShortcut: connectionOptions.shortcutItem != nil,
            hasNotificationResponse: connectionOptions.notificationResponse != nil
        ),
            let urlContext = connectionOptions.urlContexts.first
        else {
            attributeUnambiguousTrackingURL(in: connectionOptions.urlContexts)
            logUnclaimedTrackingURLIfPresent(in: connectionOptions.urlContexts)
            return false
        }
        return routeSceneURL(urlContext.url, occurrence: urlContext, in: scene)
    }

    @available(iOS 13.0, *)
    @MainActor
    func handleSceneOpenURLContexts(
        _ urlContexts: Set<UIOpenURLContext>,
        in scene: UIScene
    ) -> Bool {
        guard usesUIScene else { return false }
        // Flutter's Boolean claims the entire set for this engine. A set with multiple URLs
        // cannot be partially claimed. Attribute one unambiguous Customer.io tracking URL,
        // but do not route its redirect before returning false and handing the intact set to
        // Flutter. This avoids routing a Customer.io URL once here and then letting Flutter
        // process that same URL again.
        guard urlContexts.count == 1, let urlContext = urlContexts.first else {
            attributeUnambiguousTrackingURL(in: urlContexts)
            logUnclaimedTrackingURLIfPresent(in: urlContexts)
            return false
        }
        return routeSceneURL(urlContext.url, occurrence: urlContext, in: scene)
    }

    @MainActor
    private func routeSceneURL(
        _ url: URL,
        occurrence: UIOpenURLContext,
        in scene: UIScene
    ) -> Bool {
        let resolution = resolveSceneURL(url, occurrence: occurrence)
        if case .redirect = resolution,
           !Self.sceneOccurrenceResults.claimRedirectDelivery(for: occurrence)
        {
            return true
        }
        return handleResolution(resolution, in: scene)
    }

    @MainActor
    private func resolveSceneURL(
        _ url: URL,
        occurrence: UIOpenURLContext
    ) -> CustomerIOURLRoutingResolution {
        Self.sceneOccurrenceResults.resolution(for: occurrence) {
            CustomerIOURLRouting.resolve(
                url,
                handleWidgetURL: CustomerIOLiveActivities.handleWidgetUrl,
                isWidgetTrackingURL: CustomerIOLiveActivities.isWidgetTrackingURL
            )
        }
    }

    @MainActor
    private func attributeUnambiguousTrackingURL(in urlContexts: Set<UIOpenURLContext>) {
        let trackingContexts = urlContexts.filter {
            CustomerIOLiveActivities.isWidgetTrackingURL($0.url)
        }
        guard trackingContexts.count == 1, let urlContext = trackingContexts.first else { return }
        _ = resolveSceneURL(urlContext.url, occurrence: urlContext)
    }

    @MainActor
    private func logUnclaimedTrackingURLIfPresent(in urlContexts: Set<UIOpenURLContext>) {
        guard urlContexts.contains(where: {
            CustomerIOLiveActivities.isWidgetTrackingURL($0.url)
        }) else { return }
        DIGraphShared.shared.logger.info(
            "Customer.io left an ambiguous Live Activity scene occurrence for Flutter or the host to route"
        )
    }

    @MainActor
    private func handleResolution(
        _ resolution: CustomerIOURLRoutingResolution,
        in scene: UIScene
    ) -> Bool {
        switch resolution {
        case .notHandled:
            return false
        case .handled:
            return true
        case .invalidTrackingRedirect:
            DIGraphShared.shared.logger.error(
                "Customer.io Live Activity redirect cannot target another tracking URL"
            )
            return true
        case let .redirect(destination):
            return forwardRedirect(destination, in: scene)
        }
    }

    @MainActor
    private func forwardRedirect(_ destination: URL, in scene: UIScene) -> Bool {
        guard let deepLinkRouter else {
            DIGraphShared.shared.logger.error(
                "Customer.io could not access the Flutter redirect router"
            )
            return true
        }
        deepLinkRouter.route(destination, in: scene)
        return true
    }

    @available(iOS 13.0, *)
    @MainActor
    @objc(scene:willConnectToSession:options:)
    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        handleSceneConnection(connectionOptions, in: scene)
    }

    @available(iOS 13.0, *)
    @MainActor
    @objc(scene:openURLContexts:)
    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        handleSceneOpenURLContexts(urlContexts, in: scene)
    }
}
