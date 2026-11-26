package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.type.ModalPresentation

/** Key of the Android-only options inside the Dart `inApp` configuration. */
internal const val IN_APP_ANDROID_KEY = "android"

/** Key of the modal presentation inside the `android` sub-map. */
internal const val MODAL_PRESENTATION_KEY = "modalPresentation"

/** Wire values of [ModalPresentation], matching the raw values `ModalPresentationAndroid` serializes on the Dart side. */
private const val ACTIVITY = "ACTIVITY"
private const val HOST_WINDOW = "HOST_WINDOW"

/**
 * Maps a wire value onto [ModalPresentation], or null when [rawValue] is absent or unrecognized, so
 * the caller can keep the native default and report the mistake.
 *
 * Top-level rather than a method on the plugin so it can be unit-tested without a Flutter binding.
 */
internal fun modalPresentationFrom(rawValue: String?): ModalPresentation? = when (rawValue) {
    ACTIVITY -> ModalPresentation.ACTIVITY
    HOST_WINDOW -> ModalPresentation.HOST_WINDOW
    else -> null
}

/** Reads the raw modal presentation out of the `android` sub-map of the Dart `inApp` configuration. */
internal fun modalPresentationRawValueFrom(config: Map<String, Any>): String? =
    config.getAs<Map<String, Any>>(IN_APP_ANDROID_KEY)?.getAs<String>(MODAL_PRESENTATION_KEY)
