package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.type.NotificationInboxAccessibilityLabels
import io.customer.sdk.core.di.SDKComponent

/** Key of the accessibility labels sub-map inside the Dart `inApp` configuration. */
internal const val ACCESSIBILITY_LABELS_KEY = "notificationInboxAccessibilityLabels"

/**
 * Replaced with the unread count inside the `bellWithUnreadCount` template. Kept in sync with
 * `NotificationInboxAccessibilityLabels.countPlaceholder` on the Dart side.
 */
internal const val COUNT_PLACEHOLDER = "{count}"

/**
 * Builds the host's inbox accessibility labels from the Dart configuration, or null when the app
 * provided none — in which case the SDK keeps its default of emitting no labels at all rather than
 * falling back to English.
 *
 * `bellWithUnreadCount` arrives as a template string because the platform channel carries data but
 * not functions; it is converted here into the `(Int) -> String` the native SDK expects. A template
 * without the placeholder is returned verbatim for every count.
 *
 * Top-level rather than a method on the plugin so it can be unit-tested without a Flutter binding.
 */
internal fun inboxAccessibilityLabelsFrom(
    config: Map<String, Any>
): NotificationInboxAccessibilityLabels? {
    val labels = config.getAs<Map<String, Any>>(ACCESSIBILITY_LABELS_KEY) ?: return null

    val unreadCountTemplate = labels.getAs<String>("bellWithUnreadCount")
    // A mistyped placeholder (`{COUNT}`, `{{count}}`, `%d`) substitutes nothing and is read aloud
    // verbatim, braces included, with the count never announced. Nothing else in the stack can
    // surface that, so say it here.
    if (unreadCountTemplate != null && !unreadCountTemplate.contains(COUNT_PLACEHOLDER)) {
        SDKComponent.logger.debug(
            "Inbox accessibility label 'bellWithUnreadCount' has no '$COUNT_PLACEHOLDER' " +
                "placeholder, so the unread count will not be announced."
        )
    }
    return NotificationInboxAccessibilityLabels(
        bell = labels.getAs<String>("bell"),
        bellWithUnreadCount = unreadCountTemplate?.let { template ->
            { count: Int -> template.replace(COUNT_PLACEHOLDER, count.toString()) }
        },
        loadingIndicator = labels.getAs<String>("loadingIndicator"),
        emptyState = labels.getAs<String>("emptyState")
    )
}
