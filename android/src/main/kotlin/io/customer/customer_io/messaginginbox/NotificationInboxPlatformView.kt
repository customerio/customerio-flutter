package io.customer.customer_io.messaginginbox

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import androidx.compose.ui.platform.ComposeView
import io.customer.messaginginbox.NotificationInboxOverlay
import io.customer.messaginginbox.NotificationInboxView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Platform view that hosts one of the native Visual Notification Inbox Compose components for
 * Flutter. Mirrors [io.customer.customer_io.messaginginapp.InlineInAppMessagePlatformView].
 *
 * The headless inbox data API and the global `InboxEventListener` are bridged elsewhere; these views
 * only render UI.
 *
 *  - [InboxComponent.BELL] hosts the native `NotificationInboxOverlay` composition rather than the
 *    bare `NotificationInboxBell`: only the overlay ties the bell to the SDK's own panel, and the
 *    wrapper deliberately does not reimplement panel presentation. Sized to the frame Flutter gives
 *    it, that composition *is* a bell that opens the inbox. `onTap` is surfaced to Dart purely as an
 *    observation — the SDK opens the panel itself.
 *  - [InboxComponent.VIEW] hosts the Jist-rendered message list.
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
                InboxComponent.BELL -> NotificationInboxOverlay()
                InboxComponent.VIEW -> NotificationInboxView()
            }
        }
    }

    /**
     * Container the Compose child is attached to, rather than handing the [ComposeView] to Flutter
     * directly.
     *
     * `AbstractComposeView` creates its composition during `onMeasure`, and that needs a window to
     * resolve the recomposer — a measure while detached throws "Cannot locate windowRecomposer". The
     * container therefore only adopts the Compose child once it is in a window. For
     * [InboxComponent.BELL] it also observes taps without consuming them, so Compose still receives
     * the gesture and opens the panel.
     */
    private val container: FrameLayout = object : FrameLayout(context) {
        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            if (composeView.parent == null) {
                addView(
                    composeView,
                    LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
                )
            }
        }

        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            val handled = super.dispatchTouchEvent(event)
            // Reporting on a consumed ACTION_UP approximates "the bell took this tap" rather than
            // firing for taps that landed on the transparent area around it.
            if (component == InboxComponent.BELL &&
                handled &&
                event.actionMasked == MotionEvent.ACTION_UP
            ) {
                methodChannel.invokeMethod(METHOD_ON_TAP, null)
            }
            return handled
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View = container

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        // Release the Compose composition tied to this view.
        composeView.disposeComposition()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // No incoming Dart -> native methods: callbacks flow native -> Dart.
        result.notImplemented()
    }

    companion object {
        private const val METHOD_ON_TAP = "onTap"

        private fun channelPrefix(component: InboxComponent): String = when (component) {
            InboxComponent.BELL -> "customer_io_notification_inbox_bell_view_"
            InboxComponent.VIEW -> "customer_io_notification_inbox_view_"
        }
    }
}
