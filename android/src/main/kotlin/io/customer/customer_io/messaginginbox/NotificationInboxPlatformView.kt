package io.customer.customer_io.messaginginbox

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import androidx.compose.runtime.Recomposer
import androidx.compose.ui.platform.AndroidUiDispatcher
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.customer.messaginginbox.NotificationInboxOverlay
import io.customer.messaginginbox.NotificationInboxView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

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

    /**
     * Lifecycle + saved-state owners for the Compose child.
     *
     * `ComposeView` refuses to compose without a `ViewTreeLifecycleOwner`, and Flutter's default host
     * does not provide one: `io.flutter.embedding.android.FlutterActivity` extends plain `Activity`,
     * not `ComponentActivity`, so nothing in the tree installs the owners and composition failed with
     * "ViewTreeLifecycleOwner not found from FlutterView". Supplying them here keeps the widget working
     * on any host rather than requiring apps to switch to FlutterFragmentActivity.
     */
    private val composeOwner = ComposeHostOwner()

    /**
     * Composition context for the Compose child, owned here rather than left to Compose's default.
     *
     * Left to itself, `AbstractComposeView` resolves a *window* recomposer, which `getWindowRecomposer`
     * installs on the window's root view and builds by looking for a `ViewTreeLifecycleOwner` from that
     * root — Flutter's `FlutterView`. Flutter's default host is a plain `Activity`, so no owner exists
     * there and composition failed with "ViewTreeLifecycleOwner not found from FlutterView"; owners set
     * on our own container are not consulted for this. Supplying a recomposer explicitly keeps the fix
     * inside the plugin instead of mutating the host's view tree.
     */
    private val recomposerContext = AndroidUiDispatcher.CurrentThread
    private val recomposer = Recomposer(recomposerContext)
    private val recomposerScope = CoroutineScope(recomposerContext)

    private val composeView: ComposeView = ComposeView(context).apply {
        setParentCompositionContext(recomposer)
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
                composeOwner.start()
                setViewTreeLifecycleOwner(composeOwner)
                setViewTreeSavedStateRegistryOwner(composeOwner)
                addView(
                    composeView,
                    LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
                )
            }
        }

        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            val handled = super.dispatchTouchEvent(event)
            // Reporting on a consumed ACTION_UP approximates "the bell took this tap" rather than
            // firing for taps that landed on the transparent area around it. Verified on device:
            // Flutter forwards DOWN and UP here with handled = true.
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
        recomposerScope.launch { recomposer.runRecomposeAndApplyChanges() }
    }

    override fun getView(): View = container

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        // Release the Compose composition tied to this view, then end the lifecycle it observed.
        composeView.disposeComposition()
        composeOwner.destroy()
        recomposer.cancel()
        recomposerScope.cancel()
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

/**
 * Minimal [LifecycleOwner] + [SavedStateRegistryOwner] for a Compose child hosted outside an
 * activity that provides them. Held RESUMED while the view lives so `collectAsStateWithLifecycle`
 * inside the SDK's composables keeps collecting, and DESTROYED once the platform view is disposed.
 */
private class ComposeHostOwner : LifecycleOwner, SavedStateRegistryOwner {
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry

    fun start() {
        if (lifecycleRegistry.currentState != Lifecycle.State.INITIALIZED) return
        // Restore must happen while still INITIALIZED; there is no state to carry across recreation.
        savedStateController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        if (lifecycleRegistry.currentState == Lifecycle.State.INITIALIZED) return
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }
}
