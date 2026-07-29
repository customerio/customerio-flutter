package io.customer.customer_io.messaginginbox

import android.content.Context
import android.view.View
import androidx.compose.ui.platform.ComposeView
import io.customer.messaginginbox.NotificationInboxBell
import io.customer.messaginginbox.NotificationInboxOverlay
import io.customer.messaginginbox.NotificationInboxView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Platform view that hosts one of the native Visual Notification Inbox Compose components inside a
 * [ComposeView] for Flutter. Mirrors [io.customer.customer_io.messaginginapp.InlineInAppMessagePlatformView].
 *
 * The headless inbox data API and the global action [InboxEventListener] are already bridged
 * elsewhere; these views only render UI and surface per-view widget callbacks:
 *  - [InboxComponent.BELL] surfaces `onClick` taps to Dart as `onTap`.
 *  - [InboxComponent.OVERLAY] would surface panel presentation changes, but the Android native
 *    `NotificationInboxOverlay` public API does NOT currently expose a panel-presentation callback
 *    (iOS does). See DEVELOPING_LOCALLY.md. The overlay manages its panel state internally.
 */
internal class NotificationInboxPlatformView(
    context: Context,
    id: Int,
    @Suppress("UNUSED_PARAMETER") creationParams: Map<String, Any?>?,
    messenger: BinaryMessenger,
    private val component: InboxComponent,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val methodChannel: MethodChannel =
        MethodChannel(messenger, "${channelPrefix(component)}$id")

    private val composeView: ComposeView = ComposeView(context).apply {
        setContent {
            when (component) {
                InboxComponent.OVERLAY -> NotificationInboxOverlay()
                InboxComponent.BELL -> NotificationInboxBell(
                    onClick = {
                        // Surface bell taps to Dart. Host opens its own UI.
                        methodChannel.invokeMethod(METHOD_ON_TAP, null)
                    },
                )
                InboxComponent.VIEW -> NotificationInboxView()
            }
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View = composeView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        // Release the Compose composition tied to this view.
        composeView.disposeComposition()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // No incoming Dart -> native methods needed for the spike; callbacks flow native -> Dart.
        result.notImplemented()
    }

    companion object {
        private const val METHOD_ON_TAP = "onTap"

        private fun channelPrefix(component: InboxComponent): String = when (component) {
            InboxComponent.OVERLAY -> "customer_io_notification_inbox_overlay_view_"
            InboxComponent.BELL -> "customer_io_notification_inbox_bell_view_"
            InboxComponent.VIEW -> "customer_io_notification_inbox_view_"
        }
    }
}
