package io.customer.customer_io.messaginginapp

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import io.customer.customer_io.bridge.native
import io.customer.sdk.core.util.Logger
import io.customer.sdk.core.di.SDKComponent
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

    // MethodChannel neeeds to be unique per view instance to handle mulitple inline views on
    // the same screen.
    private val methodChannel: MethodChannel = MethodChannel(messenger, "customer_io_inline_view_$id")
    private val inlineView: FlutterInlineInAppMessageView = FlutterInlineInAppMessageView(context, methodChannel = methodChannel)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val logger: Logger = SDKComponent.logger
    
    companion object {
        private const val TAG = "InlineInAppMessagePlatformView"
        
        // Parameter constants for consistency with iOS implementation
        private const val ELEMENT_ID = "elementId"
    }

    init {
        // Set initial element ID from creation params
        creationParams?.get(ELEMENT_ID)?.let { elementId ->
            if (elementId is String) {
                inlineView.elementId = elementId
            } else {
                logger.error("ElementId is not a string: $elementId")
            }
        } ?: logger.error("No elementId found in creation params")

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
            "getElementId" -> call.native(result, { Unit }, { getElementId() })
            else -> result.notImplemented()
        }
    }

    private fun setElementId(elementId: String?) {
        inlineView.elementId = elementId
    }

    private fun getElementId(): String? = inlineView.elementId
}