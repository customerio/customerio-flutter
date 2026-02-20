package io.customer.customer_io.bridge

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.mockito.kotlin.eq
import kotlin.test.assertEquals

class MethodCallExtensionsTest {

    @Test
    fun `native should handle successful calls and return the result`() {
        val methodCall = MethodCall("testMethod", mapOf("key" to "value"))
        val mockResult = mock<MethodChannel.Result>()
        val transformer: (Any?) -> Map<String, Any> = { args -> args as Map<String, Any> }
        val handler: (Map<String, Any>) -> String = { _ -> "success" }

        methodCall.native(mockResult, transformer, handler)

        verify(mockResult).success("success")
    }

    @Test
    fun `native should handle Unit result and return true`() {
        val methodCall = MethodCall("testMethod", mapOf("key" to "value"))
        val mockResult = mock<MethodChannel.Result>()
        val transformer: (Any?) -> Map<String, Any> = { args -> args as Map<String, Any> }
        val handler: (Map<String, Any>) -> Unit = { _ -> }

        methodCall.native(mockResult, transformer, handler)

        verify(mockResult).success(true)
    }

    @Test
    fun `native should unwrap Kotlin Result and return the value`() {
        val methodCall = MethodCall("testMethod", mapOf("key" to "value"))
        val mockResult = mock<MethodChannel.Result>()
        val transformer: (Any?) -> Map<String, Any> = { args -> args as Map<String, Any> }
        val resultObject = kotlin.Result.success("unwrapped success")
        val handler: (Map<String, Any>) -> kotlin.Result<String> = { _ -> resultObject }

        methodCall.native(mockResult, transformer, handler)

        verify(mockResult).success("unwrapped success")
    }

    @Test
    fun `native should handle errors from the handler`() {
        val methodCall = MethodCall("testMethod", mapOf("key" to "value"))
        val mockResult = mock<MethodChannel.Result>()
        val transformer: (Any?) -> Map<String, Any> = { args -> args as Map<String, Any> }
        val handler: (Map<String, Any>) -> String = { _ ->
            throw RuntimeException("Test error")
        }

        methodCall.native(mockResult, transformer, handler)

        verify(mockResult).error(
            eq("testMethod"),
            any(),
            any()
        )
    }

    @Test
    fun `native should handle Kotlin Result failures`() {
        val methodCall = MethodCall("testMethod", mapOf("key" to "value"))
        val mockResult = mock<MethodChannel.Result>()
        val transformer: (Any?) -> Map<String, Any> = { args -> args as Map<String, Any> }
        val handler: (Map<String, Any>) -> Result<String> = { _ ->
            Result.failure(RuntimeException("Result failure"))
        }

        methodCall.native(mockResult, transformer, handler)

        verify(mockResult).error(
            eq("testMethod"),
            any(),
            any()
        )
    }

    @Test
    fun `nativeNoArgs should call the handler with no arguments`() {
        val methodCall = MethodCall("testMethod", null)
        val mockResult = mock<MethodChannel.Result>()
        val handler: () -> String = { "no args result" }

        methodCall.nativeNoArgs(mockResult, handler)

        verify(mockResult).success("no args result")
    }

    @Test
    fun `nativeMapArgs should call the handler with the arguments as a map`() {
        val arguments = mapOf("key" to "value")
        val methodCall = MethodCall("testMethod", arguments)
        val mockResult = mock<MethodChannel.Result>()
        val handler: (Map<String, Any>) -> String = { args ->
            assertEquals("value", args["key"])
            "map args result"
        }

        methodCall.nativeMapArgs(mockResult, handler)

        verify(mockResult).success("map args result")
    }
}