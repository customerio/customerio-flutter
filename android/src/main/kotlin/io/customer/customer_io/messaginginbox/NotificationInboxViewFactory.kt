package io.customer.customer_io.messaginginbox

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Identifiers for the Visual Notification Inbox platform views. Kept in sync with the
 * viewType strings registered in [io.customer.customer_io.messaginginapp.CustomerIOInAppMessaging]
 * and with the Dart widgets.
 */
internal object InboxViewTypes {
    const val OVERLAY = "customer_io_notification_inbox_overlay_view"
    const val BELL = "customer_io_notification_inbox_bell_view"
    const val VIEW = "customer_io_notification_inbox_view"
}

/**
 * Which native inbox Compose component a platform view should host.
 */
internal enum class InboxComponent {
    OVERLAY,
    BELL,
    VIEW,
}

/**
 * Factory for the Visual Notification Inbox platform views. A single factory class handles all
 * three components, distinguished by [component]. Mirrors [InlineInAppMessageViewFactory].
 */
internal class NotificationInboxViewFactory(
    private val messenger: BinaryMessenger,
    private val component: InboxComponent,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String, Any?>
        return NotificationInboxPlatformView(context, viewId, creationParams, messenger, component)
    }
}
