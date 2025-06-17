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
import io.customer.messaginginapp.ui.bridge.AndroidInAppPlatformDelegate
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
                is Int -> {
                    Log.d(TAG, "Setting progressTint: $color")
                    // TODO: Implement setProgressTint when available in BaseInlineInAppMessageView
                    // inlineView.setProgressTint(color)
                }
                is Long -> {
                    Log.d(TAG, "Setting progressTint (Long): $color")
                    // TODO: Implement setProgressTint when available in BaseInlineInAppMessageView
                    // inlineView.setProgressTint(color.toInt())
                }
                else -> {
                    Log.w(TAG, "ProgressTint is not an int/long: $color (${color?.javaClass?.simpleName})")
                }
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
        
        // Set up the inline view with proper layout params - no container needed
        inlineView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        
        // Make sure view is visible
        inlineView.visibility = View.VISIBLE
        
        // Loading state events are handled automatically by FlutterInlineInAppMessageView
        
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
            
            // Setup auto-resizing to trigger platform delegate animations
            setupAutoResizing()
        }
    }

    override fun getView(): View {
        Log.d(TAG, "getView() called, returning FlutterInlineInAppMessageView")
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
        Log.d(TAG, "Setting progressTint via method call: $color")
        // TODO: Implement setProgressTint when available in BaseInlineInAppMessageView
        // inlineView.setProgressTint(color)
    }

    private fun getElementId(): String? {
        val currentElementId = inlineView.elementId
        Log.d(TAG, "Getting elementId: $currentElementId")
        return currentElementId
    }

    /**
     * Sets up auto-resizing functionality by listening to layout changes in the native view
     * and triggering platform delegate animations which notify Flutter.
     */
    private fun setupAutoResizing() {
        Log.d(TAG, "Setting up auto-resizing listener")
        
        globalLayoutListener = ViewTreeObserver.OnGlobalLayoutListener {
            // Measure the actual content height from the inline view
            val currentHeight = inlineView.measuredHeight
            
            // Only process if the height has actually changed and is meaningful
            if (currentHeight != lastReportedHeight && currentHeight > 0) {
                Log.d(TAG, "View height changed from $lastReportedHeight to $currentHeight")
                lastReportedHeight = currentHeight
                
                // Convert height from pixels to density-independent pixels (dp)
                val density = inlineView.context.resources.displayMetrics.density
                val heightInDp = (currentHeight / density).toDouble()
                
                // Trigger platform delegate animation which will notify Flutter
                inlineView.triggerSizeAnimation(
                    widthInDp = null,
                    heightInDp = heightInDp,
                    duration = 200L
                )
                
                Log.d(TAG, "Triggered platform delegate animation for height: ${heightInDp}dp")
            }
        }
        
        // Add the listener to the view tree observer
        inlineView.viewTreeObserver?.addOnGlobalLayoutListener(globalLayoutListener)
        Log.d(TAG, "Auto-resizing listener added successfully")
    }
}