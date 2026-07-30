import Flutter
import CoreLocation
import UIKit

class PermissionChannelHandler: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    // Pending result for the foreground (When In Use) request, resolved by the delegate.
    private var locationPermissionResult: FlutterResult?

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "io.customer.testbed/permissions",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler(handle)
        locationManager.delegate = self
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestNotificationPermission":
            requestNotificationPermission(result: result)
        case "getNotificationPermissionStatus":
            getNotificationPermissionStatus(result: result)
        case "requestLocationPermission":
            requestLocationPermission(result: result)
        case "requestBackgroundLocationPermission":
            requestBackgroundLocationPermission(result: result)
        case "getLocationAuthorizationStatus":
            getLocationAuthorizationStatus(result: result)
        case "openAppSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Drives the state-aware "Background Location" button, mirroring the native sample apps.
    private func getLocationAuthorizationStatus(result: @escaping FlutterResult) {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            result("backgroundGranted")
        case .authorizedWhenInUse:
            result("foregroundOnly")
        case .denied, .restricted:
            result("denied")
        case .notDetermined:
            result("notDetermined")
        @unknown default:
            result("denied")
        }
    }

    private func getNotificationPermissionStatus(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    result("granted")
                case .denied:
                    result("permanentlyDenied")
                case .notDetermined:
                    result("notDetermined")
                @unknown default:
                    result("denied")
                }
            }
        }
    }

    private func requestNotificationPermission(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                result(granted ? "granted" : "denied")
            }
        }
    }

    // Only one permission request can be in flight at a time (single result slot).
    // Reject a second concurrent request instead of clobbering the first's callback.
    private func claimPendingResult(_ result: @escaping FlutterResult) -> Bool {
        if locationPermissionResult != nil {
            result("denied")
            return false
        }
        locationPermissionResult = result
        return true
    }

    private func requestLocationPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            result("granted")
        case .denied, .restricted:
            result("permanentlyDenied")
        case .notDetermined:
            guard claimPendingResult(result) else { return }
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            result("denied")
        }
    }

    // "Always" authorization is required for geofence region monitoring to wake the app
    // in the background. iOS escalates from When In Use to Always with a separate prompt.
    private func requestBackgroundLocationPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways:
            result("granted")
        case .denied, .restricted:
            result("permanentlyDenied")
        case .notDetermined, .authorizedWhenInUse:
            // The Always upgrade is delivered asynchronously, and Core Location may never
            // call the delegate (e.g. the user keeps "While Using", or the prompt was
            // already shown once). So don't await it — kick off the request and report
            // "pending"; the UI reflects the real outcome on resume via the status query.
            locationManager.requestAlwaysAuthorization()
            result("pending")
        @unknown default:
            result("denied")
        }
    }

    // Resolves the foreground (When In Use) request. The background request is fire-and-forget,
    // so When In Use here is always a foreground grant.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let result = locationPermissionResult else { return }
        locationPermissionResult = nil

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            result("granted")
        case .denied, .restricted:
            result("permanentlyDenied")
        default:
            result("denied")
        }
    }
}
