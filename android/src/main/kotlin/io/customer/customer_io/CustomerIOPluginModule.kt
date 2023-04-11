package io.customer.customer_io

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Base interface that should be implemented by each Customer.io module that can communicate with
 * code in Flutter/Dart files.
 */
internal interface CustomerIOPluginModule {
    /**
     * Unique name of module to identify between other modules
     */
    val moduleName: String

    /**
     * Called whenever root FlutterPlugin has been associated with a FlutterEngine instance.
     *
     * @see [FlutterPlugin.onAttachedToEngine] for more details
     */
    fun onAttachedToEngine()

    /**
     * Called whenever root FlutterPlugin has been removed from a FlutterEngine instance.
     *
     * @see [FlutterPlugin.onDetachedFromEngine] for more details
     */
    fun onDetachedFromEngine()
}
