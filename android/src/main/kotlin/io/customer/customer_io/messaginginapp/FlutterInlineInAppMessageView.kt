package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.ViewGroup
import android.webkit.WebView
import androidx.annotation.AttrRes
import androidx.annotation.StyleRes
import io.customer.messaginginapp.ui.core.BaseInlineInAppMessageView
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter implementation of inline in-app message view.
 * Bridges native in-app message functionality with Flutter event handling and layout system.
 */
class FlutterInlineInAppMessageView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    @AttrRes defStyleAttr: Int = 0,
    @StyleRes defStyleRes: Int = 0,
    private val methodChannel: MethodChannel
) : BaseInlineInAppMessageView<FlutterInAppPlatformDelegate>(
    context, attrs, defStyleAttr, defStyleRes
) {
    override val platformDelegate = FlutterInAppPlatformDelegate(view = this, methodChannel = methodChannel)
    
    companion object {
        private const val TAG = "FlutterInlineView"
    }

    init {
        this.layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
        configureView()
        
        // Ensure this view and its children can receive touch events
        isClickable = true
        isFocusable = true
        Log.d(TAG, "FlutterInlineInAppMessageView init: clickable=$isClickable, focusable=$isFocusable")
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        onViewDetached()
    }

    override fun onLoadingStarted() {
        platformDelegate.sendLoadingStateEvent(InlineInAppMessageStateEvent.LoadingStarted)
    }

    override fun onLoadingFinished() {
        platformDelegate.sendLoadingStateEvent(InlineInAppMessageStateEvent.LoadingFinished)
        
        // Configure any WebViews after loading finishes
        configureWebViews()
    }

    override fun onNoMessageToDisplay() {
        platformDelegate.sendLoadingStateEvent(InlineInAppMessageStateEvent.NoMessageToDisplay)
    }

    fun setProgressTint(color: Int) {
        // TODO: Implement when setProgressTint is available in BaseInlineInAppMessageView
    }

    fun triggerSizeAnimation(widthInDp: Double?, heightInDp: Double?, duration: Long = 200L) {
        platformDelegate.animateViewSize(
            widthInDp = widthInDp,
            heightInDp = heightInDp,
            duration = duration,
            onStart = null,
            onEnd = null
        )
    }
    
    private fun configureWebViews() {
        Log.d(TAG, "configureWebViews: Checking for WebViews to configure")
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            if (child is WebView) {
                Log.d(TAG, "configureWebViews: Found WebView, enabling JavaScript")
                child.settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    allowFileAccess = true
                    allowContentAccess = true
                }
            } else if (child.javaClass.simpleName == "EngineWebView") {
                Log.d(TAG, "configureWebViews: Found EngineWebView, trying reflection configuration")
                try {
                    configureEngineWebView(child)
                } catch (e: Exception) {
                    Log.w(TAG, "configureWebViews: Failed to configure EngineWebView: ${e.message}")
                }
            }
        }
    }
    
    private fun configureEngineWebView(engineWebView: android.view.View) {
        Log.d(TAG, "configureEngineWebView: Attempting to find WebView inside EngineWebView")
        
        // Method 1: Try to find a field that contains a WebView
        val clazz = engineWebView.javaClass
        val fields = clazz.declaredFields
        
        for (field in fields) {
            field.isAccessible = true
            try {
                val fieldValue = field.get(engineWebView)
                if (fieldValue is WebView) {
                    Log.d(TAG, "configureEngineWebView: Found WebView in field: ${field.name}")
                    fieldValue.settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        allowFileAccess = true
                        allowContentAccess = true
                    }
                    Log.d(TAG, "configureEngineWebView: Successfully enabled JavaScript via field ${field.name}")
                    return
                }
            } catch (e: Exception) {
                Log.v(TAG, "configureEngineWebView: Failed to access field ${field.name}: ${e.message}")
            }
        }
        
        // Method 2: Try to find WebView as a child view if EngineWebView is a ViewGroup
        if (engineWebView is ViewGroup) {
            Log.d(TAG, "configureEngineWebView: EngineWebView is a ViewGroup, searching children")
            for (i in 0 until engineWebView.childCount) {
                val childView = engineWebView.getChildAt(i)
                if (childView is WebView) {
                    Log.d(TAG, "configureEngineWebView: Found WebView child at index $i")
                    childView.settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        allowFileAccess = true
                        allowContentAccess = true
                    }
                    Log.d(TAG, "configureEngineWebView: Successfully enabled JavaScript via child WebView")
                    return
                } else if (childView is ViewGroup) {
                    // Recursively search nested ViewGroups
                    try {
                        configureEngineWebView(childView)
                    } catch (e: Exception) {
                        Log.v(TAG, "configureEngineWebView: Failed recursive search in child: ${e.message}")
                    }
                }
            }
        }
        
        Log.w(TAG, "configureEngineWebView: Could not find WebView inside EngineWebView")
    }

    override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
        Log.d(TAG, "onInterceptTouchEvent: action=${ev?.actionMasked}, x=${ev?.x}, y=${ev?.y}")
        val result = false
        Log.d(TAG, "onInterceptTouchEvent returning: $result")
        return result
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        Log.d(TAG, "onTouchEvent: action=${event?.actionMasked}, x=${event?.x}, y=${event?.y}")
        Log.d(TAG, "onTouchEvent: this view clickable=$isClickable, focusable=$isFocusable, enabled=$isEnabled")
        
        // First try the super implementation (BaseInlineInAppMessageView)
        val superResult = super.onTouchEvent(event)
        Log.d(TAG, "onTouchEvent: super.onTouchEvent returned $superResult")
        
        // If super handled it, we're done
        if (superResult) {
            Log.d(TAG, "onTouchEvent: Super handled the touch, returning true")
            return true
        }
        
        // If super didn't handle it but we want to ensure touch handling works,
        // let's always return true for ACTION_DOWN to consume the gesture
        if (event?.actionMasked == MotionEvent.ACTION_DOWN) {
            Log.d(TAG, "onTouchEvent: Forcing consumption of ACTION_DOWN for gesture sequence")
            return true
        }
        
        // For other actions, let super result decide
        Log.d(TAG, "onTouchEvent: Returning super result: $superResult")
        return superResult
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        Log.d(TAG, "dispatchTouchEvent: action=${ev?.actionMasked}, x=${ev?.x}, y=${ev?.y}")
        Log.d(TAG, "dispatchTouchEvent: childCount=$childCount")
        
        // Log all child views and ensure they can receive touch events
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            Log.d(TAG, "dispatchTouchEvent: child[$i] = ${child.javaClass.simpleName}, clickable=${child.isClickable}, focusable=${child.isFocusable}")
            
            // Ensure EngineWebView can receive touch events and has JavaScript enabled
            if (child.javaClass.simpleName == "EngineWebView") {
                if (!child.isClickable || !child.isFocusable) {
                    Log.d(TAG, "dispatchTouchEvent: Making EngineWebView clickable and focusable")
                    child.isClickable = true
                    child.isFocusable = true
                    child.isFocusableInTouchMode = true
                }
                
                // Enable JavaScript if this is a WebView or try to find WebView inside EngineWebView
                if (child is WebView) {
                    val settings = child.settings
                    if (!settings.javaScriptEnabled) {
                        Log.d(TAG, "dispatchTouchEvent: Enabling JavaScript in EngineWebView")
                        settings.javaScriptEnabled = true
                        settings.domStorageEnabled = true
                        settings.allowFileAccess = true
                        settings.allowContentAccess = true
                    }
                    Log.d(TAG, "dispatchTouchEvent: EngineWebView JavaScript enabled: ${settings.javaScriptEnabled}")
                } else {
                    Log.d(TAG, "dispatchTouchEvent: EngineWebView is not a WebView instance, it's ${child.javaClass.name}")
                    // Try to find WebView inside EngineWebView using reflection
                    try {
                        configureEngineWebView(child)
                    } catch (e: Exception) {
                        Log.w(TAG, "dispatchTouchEvent: Failed to configure EngineWebView via reflection: ${e.message}")
                    }
                }
            }
        }
        
        // First try to dispatch to children normally
        val childResult = super.dispatchTouchEvent(ev)
        Log.d(TAG, "dispatchTouchEvent: super returned $childResult")
        
        // Strategy: Let child (EngineWebView) handle the touch completely
        // Don't interfere with Customer.io action detection
        if (childResult) {
            Log.d(TAG, "dispatchTouchEvent: Child handled touch, letting Customer.io handle actions")
            return true
        }
        
        // Only as fallback if child completely rejected the touch
        if (ev != null) {
            Log.d(TAG, "dispatchTouchEvent: Child didn't handle, minimal fallback handling")
            // Minimal handling - just consume ACTION_DOWN to maintain gesture sequence
            val ourResult = ev.actionMasked == MotionEvent.ACTION_DOWN
            Log.d(TAG, "dispatchTouchEvent: Fallback returned $ourResult")
            return ourResult
        }
        
        Log.d(TAG, "dispatchTouchEvent returning: $childResult")
        return childResult
    }
}