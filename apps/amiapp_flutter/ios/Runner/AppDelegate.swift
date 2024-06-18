import UIKit
import Flutter
import CioMessagingPushFCM
import CioTracking
import FirebaseMessaging
import FirebaseCore

@UIApplicationMain
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
        
        CustomerIO.initialize(siteId: Env.siteId, apiKey: Env.apiKey, region: .US) { config in
            config.autoTrackDeviceAttributes = true
            config.logLevel = .debug
        }
        MessagingPushFCM.initialize(configOptions: nil)
        
        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown);
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        MessagingPush.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    // Function called when a push notification is clicked or swiped away.
    override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Track a Customer.io event for testing purposes to more easily track when this function is called.
        CustomerIO.shared.track(
            name: "push clicked",
            data: ["push": [
                "title": response.notification.request.content.title,
                "body": response.notification.request.content.body,
                "userInfo": response.notification.request.content.userInfo
            ]]
        )

        completionHandler()
    }
    
    override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Track a Customer.io event for testing purposes to more easily track when this function is called.
        CustomerIO.shared.track(
            name: "push should show app in foreground",
            data: ["push": [
                    "title": notification.request.content.title,
                    "body": notification.request.content.body,
                    "userInfo": notification.request.content.userInfo
            ]]
        )

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        MessagingPush.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
