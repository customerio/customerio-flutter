package io.customer.testbed.flutter

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PermissionChannelHandler(
    private val activity: Activity
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val REQUEST_NOTIFICATION = 1001
        private const val REQUEST_LOCATION = 1002
        private const val REQUEST_BACKGROUND_LOCATION = 1003
    }

    private var pendingResult: MethodChannel.Result? = null

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "getNotificationPermissionStatus" -> getNotificationPermissionStatus(result)
            "requestLocationPermission" -> requestLocationPermission(result)
            "requestBackgroundLocationPermission" -> requestBackgroundLocationPermission(result)
            "getLocationAuthorizationStatus" -> getLocationAuthorizationStatus(result)
            "openAppSettings" -> {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", activity.packageName, null)
                }
                activity.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Drives the state-aware "Background Location" button, mirroring the native sample apps.
    private fun getLocationAuthorizationStatus(result: MethodChannel.Result) {
        val fineGranted = ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!fineGranted) {
            val permanentlyDenied = !ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_FINE_LOCATION) &&
                hasRequestedPermissionBefore(Manifest.permission.ACCESS_FINE_LOCATION)
            result.success(if (permanentlyDenied) "denied" else "notDetermined")
            return
        }
        val backgroundGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        result.success(if (backgroundGranted) "backgroundGranted" else "foregroundOnly")
    }

    private fun getNotificationPermissionStatus(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("granted")
            return
        }
        when {
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS)
                    == PackageManager.PERMISSION_GRANTED -> result.success("granted")
            ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.POST_NOTIFICATIONS)
                    -> result.success("denied")
            else -> result.success("notDetermined")
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("granted")
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }
        if (!claimPendingResult(result)) return
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION
        )
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }
        if (!ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_FINE_LOCATION)
            && hasRequestedPermissionBefore(Manifest.permission.ACCESS_FINE_LOCATION)) {
            result.success("permanentlyDenied")
            return
        }
        if (!claimPendingResult(result)) return
        markPermissionRequested(Manifest.permission.ACCESS_FINE_LOCATION)
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            REQUEST_LOCATION
        )
    }

    // Background location is a separate, escalated grant required for geofence transition
    // delivery while the app is backgrounded. It only exists as its own permission on
    // API 29+, and on API 30+ the OS requires fine location to be granted first.
    private fun requestBackgroundLocationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success("granted")
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            result.success("fineLocationRequired")
            return
        }
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }
        if (!ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            && hasRequestedPermissionBefore(Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
            result.success("permanentlyDenied")
            return
        }
        if (!claimPendingResult(result)) return
        markPermissionRequested(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQUEST_BACKGROUND_LOCATION
        )
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_NOTIFICATION &&
            requestCode != REQUEST_LOCATION &&
            requestCode != REQUEST_BACKGROUND_LOCATION
        ) return false

        val result = pendingResult ?: return false
        pendingResult = null

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
        } else {
            val permission = permissions.firstOrNull() ?: ""
            if (!ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)) {
                result.success("permanentlyDenied")
            } else {
                result.success("denied")
            }
        }
        return true
    }

    // Only one permission request can be in flight at a time (single result slot).
    // Reject a second concurrent request instead of clobbering the first's callback.
    private fun claimPendingResult(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.success("denied")
            return false
        }
        pendingResult = result
        return true
    }

    private fun hasRequestedPermissionBefore(permission: String): Boolean {
        return activity.getSharedPreferences("permission_prefs", Activity.MODE_PRIVATE)
            .getBoolean(permission, false)
    }

    private fun markPermissionRequested(permission: String) {
        activity.getSharedPreferences("permission_prefs", Activity.MODE_PRIVATE)
            .edit().putBoolean(permission, true).apply()
    }
}
