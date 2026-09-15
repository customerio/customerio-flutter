package io.customer.customer_io.messaginginapp

import io.customer.customer_io.utils.getAs
import io.customer.messaginginapp.type.NotificationInboxAccessibilityLabels

/** Key of the accessibility labels sub-map inside the Dart `inApp` configuration. */
internal const val ACCESSIBILITY_LABELS_KEY = "notificationInboxAccessibilityLabels"

/**
 * Replaced with the unread count inside the `bellWithUnreadCount` template. Kept in sync with
 * `NotificationInboxAccessibilityLabels.countPlaceholder` on the Dart side.
 */
internal const val COUNT_PLACEHOLDER = "{count}"

/**
 * Wire keys of the individual labels, matching the field names
 * `NotificationInboxAccessibilityLabels.toMap()` emits on the Dart side. Named here rather than
 * spelled inline because a rename on either side silently drops that label at runtime instead of
 * failing, so the two copies are worth keeping easy to compare.
 */
internal object LabelKeys {
    const val BELL = "bell"
    const val BELL_WITH_UNREAD_COUNT = "bellWithUnreadCount"
    const val LOADING_INDICATOR = "loadingIndicator"
    const val EMPTY_STATE = "emptyState"
}

/**
 * Builds the host's inbox accessibility labels from the Dart configuration, or null when the app
 * provided none — in which case the SDK keeps its default of emitting no labels at all rather than
 * falling back to English.
 *
 * `bellWithUnreadCount` arrives as a template string because the platform channel carries data but
 * not functions; it is converted here into the `(Int) -> String` the native SDK expects. A template
 * without the placeholder is returned verbatim for every count; Dart warns about that case, where
 * the developer can actually see it.
 *
 * Top-level rather than a method on the plugin so it can be unit-tested without a Flutter binding.
 */
internal fun inboxAccessibilityLabelsFrom(
    config: Map<String, Any>
): NotificationInboxAccessibilityLabels? {
    val labels = config.getAs<Map<String, Any>>(ACCESSIBILITY_LABELS_KEY) ?: return null

    val unreadCountTemplate = labels.getAs<String>(LabelKeys.BELL_WITH_UNREAD_COUNT)
    return NotificationInboxAccessibilityLabels(
        bell = labels.getAs<String>(LabelKeys.BELL),
        bellWithUnreadCount = unreadCountTemplate?.let { template ->
            { count: Int -> template.replace(COUNT_PLACEHOLDER, count.toString()) }
        },
        loadingIndicator = labels.getAs<String>(LabelKeys.LOADING_INDICATOR),
        emptyState = labels.getAs<String>(LabelKeys.EMPTY_STATE)
    )
}
