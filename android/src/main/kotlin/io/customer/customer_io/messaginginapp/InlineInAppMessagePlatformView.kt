package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
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

    private val methodChannel: MethodChannel = MethodChannel(messenger, "customer_io_inline_view_$id")
    private val inlineView: FlutterInlineInAppMessageView = FlutterInlineInAppMessageView(context, methodChannel = methodChannel)
    private var lastReportedHeight: Int = 0
    private var globalLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    
    companion object {
        private const val TAG = "InlineInAppMessagePlatformView"
        
        // Parameter constants for consistency with iOS implementation
        private const val ELEMENT_ID = "elementId"
        private const val PROGRESS_TINT = "progressTint"
        private const val ACTION_VALUE = "actionValue"
        private const val ACTION_NAME = "actionName"
        private const val MESSAGE_ID = "messageId"
        private const val DELIVERY_ID = "deliveryId"
    }

    init {
        Log.d(TAG, "Creating InlineInAppMessagePlatformView with id: $id")
        Log.d(TAG, "Creation params: $creationParams")
        
        // Set initial element ID from creation params
        creationParams?.get(ELEMENT_ID)?.let { elementId ->
            if (elementId is String) {
                Log.d(TAG, "Setting elementId: $elementId")
                inlineView.elementId = elementId
            } else {
                Log.w(TAG, "ElementId is not a string: $elementId (${elementId?.javaClass?.simpleName})")
            }
        } ?: Log.w(TAG, "No elementId found in creation params")

        // Set initial progress tint color if provided
        creationParams?.get(PROGRESS_TINT)?.let { color ->
            when (color) {
                is Int -> inlineView.setProgressTint(color)
                is Long -> inlineView.setProgressTint(color.toInt())
                else -> Log.w(TAG, "ProgressTint must be an integer, got: ${color?.javaClass?.simpleName}")
            }
        }

        // Set method call handler for the channel
        methodChannel.setMethodCallHandler(this)
        Log.d(TAG, "Method channel created: customer_io_inline_view_$id")

        // Set up action listener to forward actions to Flutter
        inlineView.setActionListener(object : InlineMessageActionListener {
            override fun onActionClick(message: InAppMessage, actionValue: String, actionName: String) {
                Log.d(TAG, "Action triggered: $actionName = $actionValue for message: ${message.messageId}")
                methodChannel.invokeMethod("onAction", mapOf(
                    MESSAGE_ID to message.messageId,
                    DELIVERY_ID to message.deliveryId,
                    ACTION_VALUE to actionValue,
                    ACTION_NAME to actionName
                ))
            }
        })
        
        inlineView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        inlineView.visibility = View.VISIBLE
        
        Log.d(TAG, "InlineInAppMessageView initialized with elementId: ${inlineView.elementId}")
        
        inlineView.post {
            // Reset elementId to trigger Customer.io registration
            val currentElementId = inlineView.elementId
            if (currentElementId != null) {
                inlineView.elementId = null
                inlineView.elementId = currentElementId
            }
            setupAutoResizing()
        }
    }

    override fun getView(): View {
        return inlineView
    }

    override fun dispose() {
        Log.d(TAG, "dispose() called")
        
        // Remove global layout listener to prevent memory leaks
        globalLayoutListener?.let { listener ->
            inlineView.viewTreeObserver?.removeOnGlobalLayoutListener(listener)
            globalLayoutListener = null
        }
        
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
        inlineView.setProgressTint(color)
    }

    private fun getElementId(): String? {
        val currentElementId = inlineView.elementId
        Log.d(TAG, "Getting elementId: $currentElementId")
        return currentElementId
    }

    private fun setupAutoResizing() {
        globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
            val currentHeight = inlineView.measuredHeight
            
            if (currentHeight != lastReportedHeight && currentHeight > 0) {
                lastReportedHeight = currentHeight
                val density = inlineView.context.resources.displayMetrics.density
                val heightInDp = (currentHeight / density).toDouble()
                
                inlineView.triggerSizeAnimation(
                    widthInDp = null,
                    heightInDp = heightInDp,
                    duration = 200L
                )
            }
        }
        
        inlineView.viewTreeObserver?.addOnGlobalLayoutListener(globalLayoutListener)
    }
}