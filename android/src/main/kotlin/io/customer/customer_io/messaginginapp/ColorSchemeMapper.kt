package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.type.ColorScheme

/** Key of the color scheme inside the Dart `inApp` configuration, and of the setter's argument. */
internal const val COLOR_SCHEME_KEY = "colorScheme"

/**
 * Wire values of [ColorScheme], matching the raw values `CioColorScheme` serializes on the Dart
 * side. Lowercase because that is also what iOS's `MessagingInAppConfigBuilder` matches, so one
 * vocabulary covers both platforms.
 */
private const val AUTO = "auto"
private const val LIGHT = "light"
private const val DARK = "dark"

/**
 * Maps a wire value onto [ColorScheme], or null when [rawValue] is absent or unrecognized.
 *
 * Null rather than [ColorScheme.AUTO] for an unrecognized value, so callers can leave the current
 * scheme alone and report the mistake. Falling back to AUTO would render whichever variant the
 * device asks for, which looks like a styling bug rather than a configuration error — and on the
 * runtime setter it would quietly undo a scheme the app had set correctly earlier.
 *
 * Top-level rather than a method on the plugin so it can be unit-tested without a Flutter binding.
 */
internal fun colorSchemeFrom(rawValue: String?): ColorScheme? = when (rawValue) {
    AUTO -> ColorScheme.AUTO
    LIGHT -> ColorScheme.LIGHT
    DARK -> ColorScheme.DARK
    else -> null
}

/** Reads the color scheme out of the Dart `inApp` configuration map. */
internal fun colorSchemeFrom(config: Map<String, Any>): ColorScheme? =
    colorSchemeFrom(config.getAs<String>(COLOR_SCHEME_KEY))
