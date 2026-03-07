package dev.rahier.colocskitchenrace.util

object ValidationUtils {
    private val PHONE_REGEX = Regex("^\\+?[0-9\\s\\-()]{7,20}$")
    private val EMAIL_REGEX = Regex("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")

    fun isValidPhone(phone: String): Boolean {
        return phone.isNotBlank() && PHONE_REGEX.matches(phone.trim())
    }

    fun isValidEmail(email: String): Boolean {
        return email.isNotBlank() && EMAIL_REGEX.matches(email.trim())
    }
}
