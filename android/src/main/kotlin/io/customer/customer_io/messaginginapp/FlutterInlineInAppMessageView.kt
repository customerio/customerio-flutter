package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import androidx.annotation.AttrRes
import androidx.annotation.StyleRes
import io.customer.messaginginapp.type.InAppMessage
import io.customer.messaginginapp.type.InlineMessageActionListener
import io.customer.messaginginapp.ui.core.WrapperInlineView
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter implementation of inline in-app message view.
 * Now uses WrapperInlineView from native SDK to eliminate code duplication with React Native.
 * Only contains Flutter-specific functionality - all lifecycle and state management is shared.
 */
class FlutterInlineInAppMessageView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    @AttrRes defStyleAttr: Int = 0,
    @StyleRes defStyleRes: Int = 0,
    private val methodChannel: MethodChannel
) : WrapperInlineView<FlutterInAppPlatformDelegate>(
    context, attrs, defStyleAttr, defStyleRes
), InlineMessageActionListener {
    
    companion object {
        private const val TAG = "FlutterInlineInAppMessageView"
    }
    
    override val platformDelegate = FlutterInAppPlatformDelegate(view = this, methodChannel = methodChannel)

    init {
        // Initialize the wrapper view after platformDelegate is set
        initializeView()
        setActionListener(this)
    }

    /**
     * Handle action clicks from inline in-app messages.
     */
    override fun onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
        val payload = mapOf(
            "actionValue" to actionValue,
            "actionName" to actionName,
            "messageId" to message.messageId,
            "deliveryId" to message.deliveryId
        )
        
        // Dispatch through platform delegate
        post {
            platformDelegate.dispatchEventPublic("onAction", payload)
        }
    }
}