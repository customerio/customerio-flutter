import UIKit
import Flutter
import CioDataPipelines
import CioMessagingPushFCM
import FirebaseMessaging
import FirebaseCore

@main
class AppDelegateWithCioIntegration: CioAppDelegateWrapper<AppDelegate> {}

@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Depending on the method you choose to install Firebase in your app,
        // you may need to add functions to this file, such as the following:
        // FirebaseApp.configure()
        //
        // Be sure to read the official Firebase docs to correctly install Firebase in your app.
        
        Messaging.messaging().delegate = self
        
        MessagingPushFCM.initialize(
            withConfig: MessagingPushConfigBuilder()
                .build()
        )
        
        // Sets a 3rd party push event handler for the app besides the Customer.io SDK and FlutterFire.
        // Setting the AppDelegate to be the handler will internally use `flutter_local_notifications` to handle the push event.
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ application: UIApplication,
                              didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        
        Messaging.messaging().apnsToken = deviceToken
        // Not needed when CioAppDelegateWrapper is used
//                Messaging.messaging().setAPNSToken(deviceToken, type: .unknown);
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
        // Not needed when CioAppDelegateWrapper is used
//        MessagingPush.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    // IMPORTANT: This method is necessary to have CIO deep linking working!
    // Puting `return false` in body is sufficient, as this is indicator for CIO SDK to do forward iOS the link for processing.
    // This will open the browser or the associated app.
    // If this method is not overriden, default Flutter's deep link processing will just discard CIO deep links.
    override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return false
    }
}

extension AppDelegate {
    // Function called when a push notification is clicked or swiped away.
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Track custom event with Customer.io.
        // NOT required for basic PN tap tracking - that is done automatically with `CioAppDelegateWrapper`.
        CustomerIO.shared.track(
            name: "custom push-clicked event",
            properties: ["push": response.notification.request.content.userInfo]
        )
        
        completionHandler()
    }
    
    // To test sending of local notifications, display the push while app in foreground. So when you press the button to display local push in the app, you are able to see it and click on it.
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
        //        completionHandler([])
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("33")
        // Not needed when CioAppDelegateWrapper is used
//        MessagingPush.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
