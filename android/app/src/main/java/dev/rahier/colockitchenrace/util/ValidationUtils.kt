package dev.rahier.colockitchenrace.util

object ValidationUtils {
    private val PHONE_REGEX = Regex("^\\+?[0-9\\s\\-()]{7,20}$")

    fun isValidPhone(phone: String): Boolean {
        return phone.isNotBlank() && PHONE_REGEX.matches(phone.trim())
    }

    fun isValidEmail(email: String): Boolean {
        return email.contains("@") && email.contains(".")
    }
}
