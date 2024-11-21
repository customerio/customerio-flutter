import UIKit
import Flutter
import CioMessagingPushFCM
import FirebaseMessaging
import FirebaseCore

@main
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
    
    func application(application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown);
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        MessagingPush.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        MessagingPush.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
