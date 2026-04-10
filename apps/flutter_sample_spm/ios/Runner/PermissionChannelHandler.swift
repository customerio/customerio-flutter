import Flutter
import CoreLocation
import UIKit

class PermissionChannelHandler: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
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
        case "openAppSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
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

    private func requestLocationPermission(result: @escaping FlutterResult) {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            result("granted")
        case .denied, .restricted:
            result("permanentlyDenied")
        case .notDetermined:
            locationPermissionResult = result
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            result("denied")
        }
    }

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
