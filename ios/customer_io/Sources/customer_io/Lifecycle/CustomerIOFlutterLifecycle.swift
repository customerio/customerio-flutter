import CioDataPipelines
import CioInternalCommon
import Flutter
import UIKit

/// Routes Flutter application and scene activation callbacks through topology-specific
/// Customer.io lifecycle handling.
///
/// The host topology is explicit. Existing applications without the Info.plist key keep the
/// AppDelegate-only behavior. UIScene applications must set
/// `CustomerIOAppLifecycleHostTopology` to `ui-scene`.
final class CustomerIOFlutterLifecycle: NSObject {
    private final class SceneOccurrenceResult {
        weak var occurrence: AnyObject?
        var handled = false

        init(occurrence: AnyObject) {
            self.occurrence = occurrence
        }
    }

    static let hostTopologyInfoPlistKey = "CustomerIOAppLifecycleHostTopology"
    private static let sceneManifestInfoPlistKey = "UIApplicationSceneManifest"

    @MainActor
    private static var sceneOccurrenceResults: [ObjectIdentifier: SceneOccurrenceResult] = [:]

    private enum HostTopology: String {
        case appDelegateOnly = "app-delegate-only"
        case uiScene = "ui-scene"
    }

    private let hostTopology: HostTopology?

    var shouldRegisterApplicationDelegate: Bool {
        hostTopology == .appDelegateOnly
    }

    var shouldRegisterSceneDelegate: Bool {
        hostTopology == .uiScene
    }

    @MainActor
    private var isForwardingRedirectToApplication = false

    @MainActor
    private lazy var sceneCoordinator = hostTopology == .uiScene
        ? CioSceneLifecycleCoordinator()
        : nil

    init(bundle: Bundle = .main) {
        let configuredTopology = bundle.object(
            forInfoDictionaryKey: Self.hostTopologyInfoPlistKey
        ) as? String

        switch configuredTopology {
        case nil:
            self.hostTopology = .appDelegateOnly
            if bundle.object(forInfoDictionaryKey: Self.sceneManifestInfoPlistKey) != nil {
                DIGraphShared.shared.logger.error(
                    "\(Self.hostTopologyInfoPlistKey) is missing for a UIScene host; " +
                        "set it to ui-scene to enable topology-specific Customer.io routing"
                )
            }
        case HostTopology.appDelegateOnly.rawValue:
            self.hostTopology = .appDelegateOnly
        case HostTopology.uiScene.rawValue:
            self.hostTopology = .uiScene
        default:
            DIGraphShared.shared.logger.error(
                "\(Self.hostTopologyInfoPlistKey) must be app-delegate-only or ui-scene"
            )
            self.hostTopology = nil
        }

        super.init()
    }

    func reportUnavailableSceneRegistration() {
        guard hostTopology == .uiScene else { return }
        DIGraphShared.shared.logger.error(
            "Customer.io UIScene routing requires Flutter 3.44.8 or newer"
        )
    }

    func handleApplicationOpenURL(
        _ url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any]
    ) -> Bool {
        return MainActor.assumeIsolated {
            // Redirect forwarding below re-enters FlutterAppDelegate so Flutter can deliver the
            // unwrapped customer URL to its plugin and Dart routing chain. That nested callback is
            // host forwarding, not a second Customer.io activation occurrence.
            guard !isForwardingRedirectToApplication else { return false }
            guard hostTopology == .appDelegateOnly else { return false }
            return routeURL(url, applicationOptions: options)
        }
    }

    @available(iOS 13.0, *)
    func handleSceneConnection(_ connectionOptions: UIScene.ConnectionOptions?) -> Bool {
        return MainActor.assumeIsolated {
            guard let sceneCoordinator, let connectionOptions else { return false }
            guard connectionOptions.urlContexts.count == 1,
                  connectionOptions.userActivities.isEmpty,
                  connectionOptions.shortcutItem == nil,
                  let urlContext = connectionOptions.urlContexts.first else {
                return false
            }
            return Self.handleSceneOccurrence(urlContext) { [weak self] in
                guard let self else { return false }
                return claim(
                    sceneCoordinator.handleConnection(
                        options: connectionOptions,
                        routeURL: { [weak self] context in
                            self?.routeURL(
                                context.url,
                                applicationOptions: Self.applicationOptions(from: context.options)
                            ) ?? false
                        },
                        continueUserActivity: { _ in false },
                        performShortcut: { _ in false }
                    )
                )
            }
        }
    }

    @available(iOS 13.0, *)
    func handleSceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) -> Bool {
        return MainActor.assumeIsolated {
            guard let sceneCoordinator else { return false }
            guard urlContexts.count == 1, let urlContext = urlContexts.first else { return false }

            // Flutter's Boolean claims the entire set for this engine. A set with multiple URLs
            // cannot be partially claimed, so do not perform Customer.io routing before returning
            // false and handing the intact set to Flutter. This avoids routing a Customer.io URL
            // once here and then letting Flutter process that same URL again.
            return Self.handleSceneOccurrence(urlContext) { [weak self] in
                guard let self else { return false }
                return claim(
                    sceneCoordinator.handleOpenURLContexts(
                        urlContexts,
                        route: { [weak self] context in
                            self?.routeURL(
                                context.url,
                                applicationOptions: Self.applicationOptions(from: context.options)
                            ) ?? false
                        }
                    )
                )
            }
        }
    }

    @MainActor
    private static func handleSceneOccurrence(
        _ occurrence: UIOpenURLContext,
        route: () -> Bool
    ) -> Bool {
        sceneOccurrenceResults = sceneOccurrenceResults.filter { $0.value.occurrence != nil }
        let identifier = ObjectIdentifier(occurrence)
        if let existing = sceneOccurrenceResults[identifier] {
            return existing.handled
        }

        // Flutter forwards the same UIKit occurrence object to every registered engine. Keep a
        // weak identity result for that object's lifetime so each engine sees the same handled
        // answer while Customer.io metrics and host routing execute only once. A later activation
        // receives a new UIKit occurrence object, even when its URL payload is identical.
        let result = SceneOccurrenceResult(occurrence: occurrence)
        sceneOccurrenceResults[identifier] = result
        result.handled = route()
        return result.handled
    }

    @MainActor
    private func routeURL(
        _ url: URL,
        applicationOptions: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard let destination = CustomerIOLiveActivities.handleWidgetUrl(url) else {
            return true
        }
        guard destination != url else { return false }
        guard !CustomerIOLiveActivities.isWidgetTrackingURL(destination) else {
            DIGraphShared.shared.logger.error(
                "Customer.io Live Activity redirect cannot target another tracking URL"
            )
            return false
        }

        if let appDelegate = UIApplication.shared.delegate {
            isForwardingRedirectToApplication = true
            defer { isForwardingRedirectToApplication = false }
            if appDelegate.application?(
                UIApplication.shared,
                open: destination,
                options: applicationOptions
            ) == true {
                return true
            }
        }

        UIApplication.shared.open(destination, options: [:]) { success in
            guard !success else { return }
            DIGraphShared.shared.logger.error(
                "Customer.io could not open the Live Activity redirect URL"
            )
        }
        return true
    }

    @available(iOS 13.0, *)
    private static func applicationOptions(
        from sceneOptions: UIScene.OpenURLOptions
    ) -> [UIApplication.OpenURLOptionsKey: Any] {
        var applicationOptions: [UIApplication.OpenURLOptionsKey: Any] = [
            .openInPlace: sceneOptions.openInPlace,
        ]
        if let sourceApplication = sceneOptions.sourceApplication {
            applicationOptions[.sourceApplication] = sourceApplication
        }
        if let annotation = sceneOptions.annotation {
            applicationOptions[.annotation] = annotation
        }
        if #available(iOS 14.5, *), let eventAttribution = sceneOptions.eventAttribution {
            applicationOptions[.eventAttribution] = eventAttribution
        }
        return applicationOptions
    }

    @MainActor
    private func claim(_ result: CioSceneLifecycleHandlingResult) -> Bool {
        // Customer.io claims the Flutter callback only after its routing closure handled the
        // activation. A native rejection is fail-closed for Customer.io, but the remaining
        // Flutter/host delegate chain must still get the opportunity to handle that callback.
        switch result {
        case .handled:
            return true
        case .unhandled, .noActivation, .notificationOwnedByApplication,
             .rejectedAmbiguousInput:
            return false
        }
    }

    @available(iOS 13.0, *)
    @objc(scene:willConnectToSession:options:)
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        handleSceneConnection(connectionOptions)
    }

    @available(iOS 13.0, *)
    @objc(scene:openURLContexts:)
    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) -> Bool {
        handleSceneOpenURLContexts(urlContexts)
    }
}

extension CustomerIOPlugin: FlutterApplicationLifeCycleDelegate {
    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        lifecycleHandler.handleApplicationOpenURL(url, options: options)
    }
}
