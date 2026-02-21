package dev.rahier.colockitchenrace.util

import org.junit.Assert.*
import org.junit.Test

class ValidationUtilsTest {

    // -- Phone validation --

    @Test
    fun `valid Belgian mobile phone`() {
        assertTrue(ValidationUtils.isValidPhone("+32 470 12 34 56"))
    }

    @Test
    fun `valid phone without country code`() {
        assertTrue(ValidationUtils.isValidPhone("0470123456"))
    }

    @Test
    fun `valid phone with dashes`() {
        assertTrue(ValidationUtils.isValidPhone("+32-470-12-34-56"))
    }

    @Test
    fun `valid phone with parentheses`() {
        assertTrue(ValidationUtils.isValidPhone("+32 (0) 470 123456"))
    }

    @Test
    fun `blank phone is invalid`() {
        assertFalse(ValidationUtils.isValidPhone(""))
        assertFalse(ValidationUtils.isValidPhone("   "))
    }

    @Test
    fun `too short phone is invalid`() {
        assertFalse(ValidationUtils.isValidPhone("12345"))
    }

    @Test
    fun `phone with letters is invalid`() {
        assertFalse(ValidationUtils.isValidPhone("+32 abc def"))
    }

    // -- Email validation --

    @Test
    fun `valid email`() {
        assertTrue(ValidationUtils.isValidEmail("test@example.com"))
    }

    @Test
    fun `email without at is invalid`() {
        assertFalse(ValidationUtils.isValidEmail("testexample.com"))
    }

    @Test
    fun `email without dot is invalid`() {
        assertFalse(ValidationUtils.isValidEmail("test@examplecom"))
    }

    @Test
    fun `empty email is invalid`() {
        assertFalse(ValidationUtils.isValidEmail(""))
    }
}
