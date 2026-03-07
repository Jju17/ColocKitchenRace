package dev.rahier.colocskitchenrace.data.model

data class IdCardInfo(
    val documentType: String? = null,
    val name: String? = null,
    val dateOfBirth: String? = null,
    val nationality: String? = null,
    val recognizedTextSnippet: String? = null,
)

sealed interface IdCardScanResult {
    data class Valid(val info: IdCardInfo) : IdCardScanResult
    data object NotAnIdCard : IdCardScanResult
    data object PoorQuality : IdCardScanResult
    data class Error(val message: String) : IdCardScanResult
}
