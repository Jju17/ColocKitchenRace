package dev.rahier.colocskitchenrace.data.model

data class ValidatedAddress(
    val street: String,
    val city: String,
    val postalCode: String,
    val country: String,
    val latitude: Double,
    val longitude: Double,
)

sealed class AddressValidationResult {
    data object InvalidSyntax : AddressValidationResult()
    data object NotFound : AddressValidationResult()
    data class LowConfidence(val address: ValidatedAddress) : AddressValidationResult()
    data class Valid(val address: ValidatedAddress) : AddressValidationResult()
}
