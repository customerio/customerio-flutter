package io.customer.customer_io.messaginginapp

import android.content.Context
import android.util.AttributeSet
import androidx.annotation.AttrRes
import androidx.annotation.StyleRes
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
) {
    override val platformDelegate = FlutterInAppPlatformDelegate(view = this, methodChannel = methodChannel)

    init {
        // Initialize the wrapper view after platformDelegate is set
        initializeView()
    }

    /**
     * Flutter-specific method to trigger size animations from Dart code.
     */
    fun triggerSizeAnimation(widthInDp: Double?, heightInDp: Double?, duration: Long = 200L) {
        platformDelegate.animateViewSize(
            widthInDp = widthInDp,
            heightInDp = heightInDp,
            duration = duration,
            onStart = null,
            onEnd = null
        )
    }
}