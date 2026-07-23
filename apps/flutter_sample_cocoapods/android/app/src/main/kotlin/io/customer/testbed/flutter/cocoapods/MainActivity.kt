package io.customer.testbed.flutter.cocoapods

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.customer.customer_io.liveactivities.CustomerIOLiveActivities
import io.customer.messagingpush.data.communication.CustomerIOPushNotificationCallback
import io.customer.messagingpush.data.model.CustomerIOParsedPushPayload
import io.customer.testbed.flutter.PermissionChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var permissionHandler: PermissionChannelHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        // Custom live notifications require a render callback that can only be set at SDK build time.
        // Register it BEFORE the Dart layer initializes the Customer.io SDK (which happens later,
        // once the Flutter engine runs). The wrapper stores this statically and applies it onto the
        // push module config during SDK init.
        CustomerIOLiveActivities.setLiveNotificationCallback(RideshareLiveNotificationCallback())
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.customer.testbed/permissions")
        permissionHandler = PermissionChannelHandler(this)
        permissionHandler.register(channel)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (!permissionHandler.onRequestPermissionsResult(requestCode, permissions, grantResults)) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}

/**
 * Sample app-owned renderer for the custom `rideshare` live notification type. Custom types have no
 * built-in SDK template, so the app fully renders them here. Returning null for any other type lets
 * the SDK fall back to its built-in templates.
 *
 * Payload fields sent from Dart (`startCustom(..., data)`) arrive flattened as strings in
 * [CustomerIOParsedPushPayload.extras].
 */
private class RideshareLiveNotificationCallback : CustomerIOPushNotificationCallback {
    override fun createLiveNotification(
        payload: CustomerIOParsedPushPayload,
        context: Context,
    ): Notification? {
        val extras = payload.extras
        if (extras.getString("notification_type") != RIDESHARE_TYPE) return null

        val driverName = extras.getString("driverName") ?: "Your driver"
        val status = extras.getString("status") ?: ""
        val etaMinutes = extras.getString("etaMinutes")

        val body = if (etaMinutes != null) {
            "$status • ETA $etaMinutes min"
        } else {
            status
        }

        ensureChannel(context)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("$driverName is on the way")
            .setContentText(body)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Rideshare",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
    }

    private companion object {
        const val RIDESHARE_TYPE = "io.customer.livenotifications.custom.rideshare"
        const val CHANNEL_ID = "rideshare_live_notification"
    }
}
