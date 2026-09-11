package io.customer.customer_io.messaginginapp

import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

/**
 * The Dart side sends the unread-count label as a template because the platform channel carries
 * data but not functions, so this mapper is where it becomes the `(Int) -> String` the native SDK
 * takes. These tests pin that conversion and the absent-means-absent rule — a dropped label is
 * silent at runtime (the SDK emits no text of its own, so the inbox just goes unlabeled).
 */
class InboxAccessibilityLabelsMapperTest {

    private fun config(labels: Map<String, Any>): Map<String, Any> =
        mapOf(ACCESSIBILITY_LABELS_KEY to labels)

    @Test
    fun `returns null when the app configured no labels`() {
        assertNull(inboxAccessibilityLabelsFrom(mapOf("siteId" to "site")))
    }

    @Test
    fun `maps every label from the Dart configuration`() {
        val labels = inboxAccessibilityLabelsFrom(
            config(
                mapOf(
                    "bell" to "Aviseringar",
                    "loadingIndicator" to "Laddar",
                    "emptyState" to "Inga aviseringar"
                )
            )
        )

        assertEquals("Aviseringar", labels?.bell)
        assertEquals("Laddar", labels?.loadingIndicator)
        assertEquals("Inga aviseringar", labels?.emptyState)
    }

    @Test
    fun `substitutes the count into the unread template`() {
        val labels = inboxAccessibilityLabelsFrom(
            config(mapOf("bellWithUnreadCount" to "Aviseringar, {count} olasta"))
        )

        assertEquals("Aviseringar, 3 olasta", labels?.bellWithUnreadCount?.invoke(3))
        assertEquals("Aviseringar, 0 olasta", labels?.bellWithUnreadCount?.invoke(0))
    }

    @Test
    fun `substitutes every occurrence of the placeholder`() {
        val labels = inboxAccessibilityLabelsFrom(
            config(mapOf("bellWithUnreadCount" to "{count} av {count}"))
        )

        assertEquals("2 av 2", labels?.bellWithUnreadCount?.invoke(2))
    }

    @Test
    fun `returns a template without the placeholder verbatim for every count`() {
        val labels = inboxAccessibilityLabelsFrom(
            config(mapOf("bellWithUnreadCount" to "Olasta aviseringar"))
        )

        assertEquals("Olasta aviseringar", labels?.bellWithUnreadCount?.invoke(1))
        assertEquals("Olasta aviseringar", labels?.bellWithUnreadCount?.invoke(9))
    }

    @Test
    fun `leaves unset labels null rather than inventing a fallback`() {
        val labels = inboxAccessibilityLabelsFrom(config(mapOf("emptyState" to "Inga aviseringar")))

        assertEquals("Inga aviseringar", labels?.emptyState)
        assertNull(labels?.bell)
        assertNull(labels?.bellWithUnreadCount)
        assertNull(labels?.loadingIndicator)
    }

    @Test
    fun `ignores a labels value that is not a map`() {
        // Dart is typed, but the channel is not — a malformed payload must not crash initialization.
        assertNull(inboxAccessibilityLabelsFrom(mapOf(ACCESSIBILITY_LABELS_KEY to "nonsense")))
    }
}
