package io.customer.customer_io.messagingpush

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import io.customer.messagingpush.di.backgroundPushCallbackFallback
import io.customer.sdk.core.di.SDKComponent

/**
 * Sets the plugin's silent push callback as the native SDK's wrapper fallback when the process
 * starts, since Firebase can start it for a silent push before Dart sets up Customer.io. The
 * callback does nothing unless the app registered a Dart handler.
 */
internal class BackgroundPushInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        SDKComponent.backgroundPushCallbackFallback.callback = FlutterBackgroundPushCallback
        return false
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}
