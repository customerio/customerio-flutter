import CioLiveActivities_Attributes
import Flutter
import UIKit
import customer_io

final class CustomerIOLiveActivitySceneHandler: NSObject, FlutterSceneLifeCycleDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        guard let URLContexts = connectionOptions?.urlContexts else { return false }
        return handleCustomerIOURLs(URLContexts, in: scene)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        handleCustomerIOURLs(URLContexts, in: scene)
    }

    private func handleCustomerIOURLs(
        _ URLContexts: Set<UIOpenURLContext>,
        in scene: UIScene
    ) -> Bool {
        guard URLContexts.contains(where: { CioLiveActivityWidgetUrl.parse($0.url) != nil }) else {
            return false
        }

        // Consuming this callback prevents Flutter from routing the Customer.io tracking URL.
        // Replay every routable URL through the scene so Flutter receives only customer deep links
        // and any non-Customer.io contexts that arrived in the same callback.
        for context in URLContexts {
            let routableURL = CioLiveActivityWidgetUrl.parse(context.url) == nil
                ? context.url
                : CustomerIOLiveActivities.handleWidgetUrl(context.url)
            guard let routableURL else { continue }

            DispatchQueue.main.async {
                scene.open(routableURL, options: nil) { success in
                    if !success {
                        print("Unable to route a URL received with a Customer.io Live Activity tap")
                    }
                }
            }
        }
        return true
    }
}

/// Flutter owns scene lifecycle forwarding for the sample app.
class SceneDelegate: FlutterSceneDelegate {}
