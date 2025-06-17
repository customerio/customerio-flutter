package io.customer.customer_io.messaginginapp

import android.view.View
import io.customer.messaginginapp.ui.bridge.AndroidInAppPlatformDelegate
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter platform delegate for in-app messaging.
 * Bridges native in-app message events to Flutter components.
 * Similar to ReactInAppPlatformDelegate but for Flutter integration.
 *
 * @param view The native Android view hosting the in-app message
 * @param methodChannel The Flutter method channel for communication
 */
class FlutterInAppPlatformDelegate(
    view: View,
    private val methodChannel: MethodChannel
) : AndroidInAppPlatformDelegate(view) {

    companion object {
        private const val TAG = "FlutterInAppPlatformDelegate"
    }

    override fun animateViewSize(
        widthInDp: Double?,
        heightInDp: Double?,
        duration: Long?,
        onStart: (() -> Unit)?,
        onEnd: (() -> Unit)?
    ) {
        onStart?.invoke()

        val animDuration = duration ?: defaultAnimDuration
        val payload = mutableMapOf<String, Any?>()

        widthInDp?.takeIf { it > 0 }?.let { payload["width"] = it }
        heightInDp?.let { payload["height"] = it }
        payload["duration"] = animDuration.toDouble()

        // Send size change event to Flutter
        methodChannel.invokeMethod("onSizeChange", payload)

        // Execute onEnd callback after animation duration
        onEnd?.let { 
            view.postDelayed({ it.invoke() }, animDuration)
        }
    }

    /**
     * Send loading state events to Flutter
     */
    fun sendLoadingStateEvent(state: InlineInAppMessageStateEvent) {
        val payload = mapOf("state" to state.name)
        methodChannel.invokeMethod("onStateChange", payload)
    }
}

/**
 * State events for inline in-app messages
 */
enum class InlineInAppMessageStateEvent {
    LoadingStarted,
    LoadingFinished,
    NoMessageToDisplay
}