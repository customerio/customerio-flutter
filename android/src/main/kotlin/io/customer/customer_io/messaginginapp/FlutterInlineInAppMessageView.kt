package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.ViewGroup
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
        
        // Ensure this view can receive touch events
        isClickable = true
        isFocusable = true
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
    

    override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
        // Don't intercept - let children handle touches
        return false
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        // Ensure EngineWebView can receive touch events on first touch
        if (childCount > 0) {
            val child = getChildAt(0)
            if (child.javaClass.simpleName == "EngineWebView" && (!child.isClickable || !child.isFocusable)) {
                child.isClickable = true
                child.isFocusable = true
                child.isFocusableInTouchMode = true
            }
        }
        
        // Let the Customer.io EngineWebView handle touches normally
        return super.dispatchTouchEvent(ev)
    }
}