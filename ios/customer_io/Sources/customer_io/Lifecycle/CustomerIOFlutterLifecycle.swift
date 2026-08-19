import CioDataPipelines
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

    var shouldRegisterApplicationDelegate: Bool {
        CustomerIOLifecycleSeatSelection.shouldRegisterApplicationDelegate(
            hasSceneManifest: usesUIScene,
            flutterDeepLinkingEnabled: usesFlutterDeepLinking
        )
    }

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
        if shouldRegisterApplicationDelegate {
            // FlutterAppDelegate owns one application-level route target. Resolve its current root
            // controller at delivery time, with this registration's controller as an add-to-app
            // fallback when Flutter is embedded below the window root.
            deepLinkRouter = CustomerIOFlutterDeepLinkRouter(
                registrar: registrar,
                usesApplicationRoot: true
            )
        } else if shouldRegisterSceneDelegate {
            deepLinkRouter = CustomerIOFlutterDeepLinkRouter(registrar: registrar)
        }
    }

    func reportUnavailableSceneRegistration() {
        guard usesUIScene else { return }
        DIGraphShared.shared.logger.error(
            "Customer.io UIScene routing requires Flutter 3.44.8 or newer"
        )
    }

    func handleApplicationOpenURL(
        _ url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any]
    ) -> Bool {
        MainActor.assumeIsolated {
            guard !usesUIScene else { return false }
            return routeURL(url)
        }
    }

    @available(iOS 13.0, *)
    func handleSceneConnection(
        _ connectionOptions: UIScene.ConnectionOptions?,
        in _: UIScene
    ) -> Bool {
        MainActor.assumeIsolated {
            guard usesUIScene, let connectionOptions else { return false }
            guard CustomerIOURLRouting.canClaimColdConnection(
                urlCount: connectionOptions.urlContexts.count,
                userActivityCount: connectionOptions.userActivities.count,
                hasShortcut: connectionOptions.shortcutItem != nil,
                hasNotificationResponse: connectionOptions.notificationResponse != nil
            ),
                let urlContext = connectionOptions.urlContexts.first
            else {
                logUnclaimedTrackingURLIfPresent(in: connectionOptions.urlContexts)
                return false
            }
            return routeSceneURL(urlContext.url, occurrence: urlContext)
        }
    }

    @available(iOS 13.0, *)
    func handleSceneOpenURLContexts(
        _ urlContexts: Set<UIOpenURLContext>,
        in _: UIScene
    ) -> Bool {
        MainActor.assumeIsolated {
            guard usesUIScene else { return false }
            guard urlContexts.count == 1, let urlContext = urlContexts.first else {
                logUnclaimedTrackingURLIfPresent(in: urlContexts)
                return false
            }

            // Flutter's Boolean claims the entire set for this engine. A set with multiple URLs
            // cannot be partially claimed, so do not perform Customer.io routing before returning
            // false and handing the intact set to Flutter. This avoids routing a Customer.io URL
            // once here and then letting Flutter process that same URL again.
            return routeSceneURL(urlContext.url, occurrence: urlContext)
        }
    }

    @MainActor
    private func routeSceneURL(
        _ url: URL,
        occurrence: UIOpenURLContext
    ) -> Bool {
        // Flutter's scene provider passes this UIKit occurrence through each engine's plugin
        // chain. Resolve the native metric once, then let each engine route the same destination.
        let resolution = Self.sceneOccurrenceResults.resolution(for: occurrence) {
            CustomerIOURLRouting.resolve(
                url,
                handleWidgetURL: CustomerIOLiveActivities.handleWidgetUrl,
                isWidgetTrackingURL: CustomerIOLiveActivities.isWidgetTrackingURL
            )
        }
        return handleResolution(resolution)
    }

    @MainActor
    private func logUnclaimedTrackingURLIfPresent(in urlContexts: Set<UIOpenURLContext>) {
        guard urlContexts.contains(where: {
            CustomerIOLiveActivities.isWidgetTrackingURL($0.url)
        }) else { return }
        DIGraphShared.shared.logger.info(
            "Customer.io left an ambiguous scene URL occurrence for Flutter or the host to handle"
        )
    }

    @MainActor
    private func routeURL(_ url: URL) -> Bool {
        handleResolution(CustomerIOURLRouting.resolve(
            url,
            handleWidgetURL: CustomerIOLiveActivities.handleWidgetUrl,
            isWidgetTrackingURL: CustomerIOLiveActivities.isWidgetTrackingURL
        ))
    }

    @MainActor
    private func handleResolution(_ resolution: CustomerIOURLRoutingResolution) -> Bool {
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
            return forwardRedirect(destination)
        }
    }

    @MainActor
    private func forwardRedirect(_ destination: URL) -> Bool {
        guard let deepLinkRouter else {
            DIGraphShared.shared.logger.error(
                "Customer.io could not access the Flutter redirect router"
            )
            return true
        }
        deepLinkRouter.route(destination)
        return true
    }

    @available(iOS 13.0, *)
    @objc(scene:willConnectToSession:options:)
    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        handleSceneConnection(connectionOptions, in: scene)
    }

    @available(iOS 13.0, *)
    @objc(scene:openURLContexts:)
    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        handleSceneOpenURLContexts(urlContexts, in: scene)
    }
}

public extension CustomerIOPlugin {
    @objc(application:openURL:options:)
    func application(
        _: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        lifecycleHandler.handleApplicationOpenURL(url, options: options)
    }
}
