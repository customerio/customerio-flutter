package io.customer.customer_io.extension

import io.customer.sdk.data.model.Region
import io.customer.sdk.util.CioLogLevel

internal fun String?.toRegion(fallback: Region = Region.US): Region {
    return if (this.isNullOrBlank()) fallback
    else listOf(
        Region.US,
        Region.EU,
    ).find { value -> value.code.equals(this, ignoreCase = true) } ?: fallback
}

internal fun String?.toCIOLogLevel(fallback: CioLogLevel = CioLogLevel.NONE): CioLogLevel {
    return CioLogLevel.values().find { value -> value.name.equals(this, ignoreCase = true) }
        ?: fallback
}
