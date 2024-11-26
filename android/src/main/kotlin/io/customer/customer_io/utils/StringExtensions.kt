package io.customer.customer_io.utils

/**
 * Extension function to return the string if it is not null or blank.
 */
internal fun String?.takeIfNotBlank(): String? = takeIf { !it.isNullOrBlank() }
