package io.customer.customer_io.utils

/**
 * Returns the value corresponding to the given key after casting to the generic type provided, or
 * null if such key is not present in the map or value cannot be casted to the given type.
 */
internal inline fun <reified T> Map<String, Any>.getAs(key: String): T? {
    if (containsKey(key)) {
        return get(key) as? T
    }
    return null
}
