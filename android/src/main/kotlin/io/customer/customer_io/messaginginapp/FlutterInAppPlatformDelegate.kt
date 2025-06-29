package io.customer.customer_io.messaginginapp

import android.view.View
import io.customer.messaginginapp.ui.bridge.WrapperPlatformDelegate
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter platform delegate for in-app messaging.
 * Now uses WrapperPlatformDelegate from native SDK to eliminate code duplication with other wrappers.
 * Only contains Flutter-specific event dispatch logic - all animation and state management is shared.
 *
 * @param view The native Android view hosting the in-app message
 * @param methodChannel The Flutter method channel for communication
 */
class FlutterInAppPlatformDelegate(
    view: View,
    private val methodChannel: MethodChannel
) : WrapperPlatformDelegate(view) {

    /**
     * Flutter-specific event dispatch implementation.
     * This is the ONLY platform-specific code - everything else is now shared!
     */
    override fun dispatchEvent(eventName: String, payload: Map<String, Any?>) {
        methodChannel.invokeMethod(eventName, payload)
    }
    
    /**
     * Public method for external classes to dispatch events.
     * Used by InlineMessageActionListener implementation.
     */
    fun dispatchEventPublic(eventName: String, payload: Map<String, Any?>) {
        dispatchEvent(eventName, payload)
    }
}