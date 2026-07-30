package io.customer.testbed.flutter

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import io.customer.customer_io.liveactivities.CustomerIOLiveActivities
import io.customer.messagingpush.data.communication.CustomerIOLiveNotificationsCallback
import io.customer.messagingpush.data.model.CustomerIOParsedPushPayload

/**
 * Shared by both sample apps (see `sourceSets` in each `android/app/build.gradle`), so both
 * manifests name it in full: `io.customer.testbed.flutter.MainApplication`. That replaces
 * Flutter's `${applicationName}` placeholder, which resolves to `android.app.Application` —
 * the class extended here, so nothing is lost by overriding it.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Registered here rather than in MainActivity because Android starts a process with no
        // Activity whenever it delivers a push after the app's process was killed. Application
        // onCreate runs in every process, an Activity's does not, so this is the only place a
        // renderer can be registered in time for a pushed live notification.
        CustomerIOLiveActivities.setLiveNotificationCallback(RideshareLiveNotificationCallback())
    }
}

/**
 * Sample app-owned renderer for the custom `rideshare` live notification type. Custom types have no
 * built-in SDK template, so the app fully renders them here. Returning null for any other type lets
 * the SDK fall back to its built-in templates.
 *
 * The `data` map Dart sends with `LiveActivityPayload.custom` arrives flattened in
 * [CustomerIOParsedPushPayload.extras], keyed the same way.
 */
private class RideshareLiveNotificationCallback : CustomerIOLiveNotificationsCallback {
    override fun createLiveNotification(
        payload: CustomerIOParsedPushPayload,
        context: Context,
    ): Notification? {
        val extras = payload.extras
        if (extras.getString("notification_type") != RIDESHARE_TYPE) return null

        // The SDK re-invokes this callback on the "end" event. Return a terminal, non-ongoing
        // notification then so it can be dismissed instead of sticking around forever.
        val ended = extras.getString("event") == "end"

        val driverName = extras.getString("driverName") ?: "Your driver"
        val status = extras.getString("status") ?: ""
        // Every custom value is a string, here and in the pushed content-state; parse what you need.
        val etaMinutes = extras.getString("etaMinutes")?.toDoubleOrNull()?.toInt()

        // Mirrors the iOS widget's layout: status leads (as the title below), then the driver, then
        // the ETA. `status` is not repeated here since it is already the title.
        val body = listOfNotNull(
            driverName,
            etaMinutes?.let { "ETA $it min" },
        ).joinToString(" • ")

        ensureChannel(context)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            // Title follows `status`, matching the iOS widget's headline. Hardcoding "is on the way"
            // left Android showing stale copy after an update that changed the status, while the
            // body below already reflected the new state.
            .setContentTitle(status.ifEmpty { if (ended) "Arrived" else "Rideshare" })
            .setContentText(body)
            .setOngoing(!ended)
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
