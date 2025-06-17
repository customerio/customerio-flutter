package io.customer.customer_io.messaginginapp

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import io.customer.customer_io.bridge.native
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
    private val mainHandler = Handler(Looper.getMainLooper())
    
    companion object {
        private const val TAG = "InlineInAppMessagePlatformView"
        
        // Parameter constants for consistency with iOS implementation
        private const val ELEMENT_ID = "elementId"
        private const val PROGRESS_TINT = "progressTint"
    }

    init {
        // Set initial element ID from creation params
        creationParams?.get(ELEMENT_ID)?.let { elementId ->
            if (elementId is String) {
                inlineView.elementId = elementId
            }
        }

        // Set initial progress tint color if provided
        creationParams?.get(PROGRESS_TINT)?.let { color ->
            when (color) {
                is Int -> inlineView.setProgressTint(color)
                is Long -> inlineView.setProgressTint(color.toInt())
            }
        }

        // Set method call handler for the channel
        methodChannel.setMethodCallHandler(this)

        
        inlineView.visibility = View.VISIBLE
        
        inlineView.post {
            // Reset elementId to trigger Customer.io registration
            val currentElementId = inlineView.elementId
            if (currentElementId != null) {
                inlineView.elementId = null
                inlineView.elementId = currentElementId
            }
        }
    }

    override fun getView(): View = inlineView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setElementId" -> call.native(result, { it as? String }, ::setElementId)
            "setProgressTint" -> call.native(result, { it as? Int }, ::setProgressTint)
            "getElementId" -> call.native(result, { Unit }, { getElementId() })
            else -> result.notImplemented()
        }
    }

    private fun setElementId(elementId: String?) {
        inlineView.elementId = elementId
    }

    private fun setProgressTint(color: Int?) {
        require(color != null) { "Color must be an integer" }
        inlineView.setProgressTint(color)
    }

    private fun getElementId(): String? = inlineView.elementId
}