package io.customer.customer_io

import androidx.annotation.CallSuper

/**
 * Base interface that should be implemented by each Customer.io module that provides an option
 * to bridge native code with Flutter.
 */
internal interface CustomerIOPluginModule {
    /**
     * Unique name of module to identify between other modules
     */
    val moduleName: String

    /**
     * Called whenever a request from dart/flutter file is received. If the module implements the
     * method, it should return a lambda to process the request, else it should pass the request
     * to super class for rejecting the request gracefully.
     *
     * @param methodName name of method invoked from dart/flutter file.
     */
    @CallSuper
    fun onMethodCallInvoked(
        methodName: String,
    ): (arguments: Map<String, Any>) -> Any {
        throw NotImplementedError("Method $methodName not implemented in $moduleName module")
    }
}
