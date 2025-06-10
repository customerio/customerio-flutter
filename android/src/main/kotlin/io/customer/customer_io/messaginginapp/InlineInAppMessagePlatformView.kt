package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.customer.customer_io.bridge.native
import io.customer.messaginginapp.type.InAppMessage
import io.customer.messaginginapp.type.InlineMessageActionListener
import io.customer.messaginginapp.ui.InlineInAppMessageView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView

/**
 * Platform view that wraps the native InlineInAppMessageView for Flutter integration.
 * 
 * This class creates a bridge between Flutter and the native Android InlineInAppMessageView,
 * allowing Flutter apps to display inline in-app messages using the Customer.io messaging SDK.
 */
class InlineInAppMessagePlatformView(
    context: Context,
    id: Int,
    creationParams: Map<String, Any?>?,
    messenger: BinaryMessenger
) : PlatformView, MethodCallHandler {

    private val inlineView: InlineInAppMessageView = InlineInAppMessageView(context)
    private val methodChannel: MethodChannel
    
    companion object {
        private const val TAG = "InlineInAppMessagePlatformView"
    }

    init {
        Log.d(TAG, "Creating InlineInAppMessagePlatformView with id: $id")
        Log.d(TAG, "Creation params: $creationParams")
        
        // Set initial element ID from creation params
        creationParams?.get("elementId")?.let { elementId ->
            if (elementId is String) {
                Log.d(TAG, "Setting elementId: $elementId")
                inlineView.elementId = elementId
            } else {
                Log.w(TAG, "ElementId is not a string: $elementId (${elementId?.javaClass?.simpleName})")
            }
        } ?: Log.w(TAG, "No elementId found in creation params")

        // Set initial progress tint color if provided
        creationParams?.get("progressTint")?.let { color ->
            if (color is Int) {
                Log.d(TAG, "Setting progressTint: $color")
                inlineView.setProgressTint(color)
            } else {
                Log.w(TAG, "ProgressTint is not an int: $color (${color?.javaClass?.simpleName})")
            }
        }

        // Create method channel for communication with Flutter
        methodChannel = MethodChannel(messenger, "customer_io_inline_view_$id")
        methodChannel.setMethodCallHandler(this)
        Log.d(TAG, "Method channel created: customer_io_inline_view_$id")

        // Set up action listener to forward actions to Flutter
        inlineView.setActionListener(object : InlineMessageActionListener {
            override fun onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
                Log.d(TAG, "Action triggered: $actionName = $actionValue for message: ${message.messageId}")
                methodChannel.invokeMethod("onAction", mapOf(
                    "messageId" to message.messageId,
                    "deliveryId" to message.deliveryId,
                    "actionValue" to actionValue,
                    "actionName" to actionName
                ))
            }
        })
        
        // Set up the view with natural sizing
        inlineView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        
        // Make sure the view is visible
        inlineView.visibility = View.VISIBLE
        
        Log.d(TAG, "InlineInAppMessageView initialized with elementId: ${inlineView.elementId}")
        
        // Post initial setup to ensure proper initialization
        inlineView.post {
            Log.d(TAG, "View posted to UI thread, elementId is: ${inlineView.elementId}")
            
            // Reset elementId to trigger Customer.io registration
            val currentElementId = inlineView.elementId
            if (currentElementId != null) {
                Log.d(TAG, "Initial elementId reset for registration: $currentElementId")
                inlineView.elementId = null
                inlineView.elementId = currentElementId
                Log.d(TAG, "Initial elementId reset complete")
            }
        }
    }

    override fun getView(): View {
        Log.d(TAG, "getView() called, returning native InlineInAppMessageView")
        return inlineView
    }

    override fun dispose() {
        Log.d(TAG, "dispose() called")
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method call received: ${call.method} with arguments: ${call.arguments}")
        
        when (call.method) {
            "setElementId" -> call.native(result, { it as? String }, ::setElementId)
            "setProgressTint" -> call.native(result, { it as? Int }, ::setProgressTint)
            "getElementId" -> call.native(result, { Unit }, { getElementId() })
            else -> {
                Log.w(TAG, "Unhandled method call: ${call.method}")
                result.notImplemented()
            }
        }
    }

    private fun setElementId(elementId: String?) {
        Log.d(TAG, "Setting elementId via method call: $elementId")
        inlineView.elementId = elementId
        Log.d(TAG, "ElementId set to: ${inlineView.elementId}")
    }

    private fun setProgressTint(color: Int?) {
        require(color != null) { "Color must be an integer" }
        Log.d(TAG, "Setting progressTint via method call: $color")
        inlineView.setProgressTint(color)
    }

    private fun getElementId(): String? {
        val currentElementId = inlineView.elementId
        Log.d(TAG, "Getting elementId: $currentElementId")
        return currentElementId
    }
}