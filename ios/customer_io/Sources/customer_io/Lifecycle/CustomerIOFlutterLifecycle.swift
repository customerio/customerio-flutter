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
        #if canImport(CioLiveActivities)
            usesUIScene && usesFlutterDeepLinking
        #else
            false
        #endif
    }

    private let deepLinkRouter = CustomerIOFlutterDeepLinkRouter()

    override init() {
        usesUIScene = Bundle.main.object(
            forInfoDictionaryKey: Self.sceneManifestInfoPlistKey
        ) != nil
        let configuredValue = Bundle.main.object(
            forInfoDictionaryKey: "FlutterDeepLinkingEnabled"
        )
        usesFlutterDeepLinking = CustomerIOURLRouting.isFlutterDeepLinkingEnabled(configuredValue)
        super.init()
    }

    func reportUnavailableSceneRegistration() {
        DIGraphShared.shared.logger.error(
            "This Flutter plugin registrar does not support Customer.io UIScene routing; Flutter 3.44.8 or newer is required"
        )
    }

    @MainActor
    func handleSceneConnection(
        _ connectionOptions: UIScene.ConnectionOptions?,
        in scene: UIScene
    ) -> Bool {
        guard let connectionOptions else { return false }
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

    @MainActor
    func handleSceneOpenURLContexts(
        _ urlContexts: Set<UIOpenURLContext>,
        in scene: UIScene
    ) -> Bool {
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
        return handleResolution(resolution, occurrence: occurrence, in: scene)
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
        occurrence: UIOpenURLContext,
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
            return forwardRedirect(destination, occurrence: occurrence, in: scene)
        }
    }

    @MainActor
    private func forwardRedirect(
        _ destination: URL,
        occurrence: UIOpenURLContext,
        in scene: UIScene
    ) -> Bool {
        guard Self.sceneOccurrenceResults.claimRedirectDelivery(for: occurrence) else { return true }

        deepLinkRouter.route(destination, in: scene)
        return true
    }

    @MainActor
    @objc(scene:willConnectToSession:options:)
    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        handleSceneConnection(connectionOptions, in: scene)
    }

    @MainActor
    @objc(scene:openURLContexts:)
    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        handleSceneOpenURLContexts(urlContexts, in: scene)
    }
}
