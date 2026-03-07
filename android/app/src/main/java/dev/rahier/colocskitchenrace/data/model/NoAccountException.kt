package dev.rahier.colocskitchenrace.data.model

class NoAccountException(val email: String) : Exception("No account found for $email")
