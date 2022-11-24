package io.customer.customer_io.extension

internal fun String.takeIfNotBlank(): String? = takeIf { it.isNotBlank() }
