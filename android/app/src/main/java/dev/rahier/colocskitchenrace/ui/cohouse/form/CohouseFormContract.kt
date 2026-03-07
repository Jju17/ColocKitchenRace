package dev.rahier.colocskitchenrace.ui.cohouse.form

import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import dev.rahier.colocskitchenrace.data.model.ValidatedAddress

data class CohouseFormState(
    val isEditMode: Boolean = false,
    val cohouseId: String? = null,
    val name: String = "",
    val street: String = "",
    val postalCode: String = "",
    val city: String = "",
    val members: List<CohouseUser> = emptyList(),
    val newMemberName: String = "",
    val isSaving: Boolean = false,
    val error: String? = null,
    // Address validation
    val isValidatingAddress: Boolean = false,
    val addressValidationResult: AddressValidationResult? = null,
    // Cover image
    val coverImageData: ByteArray? = null,
    // Coordinates from validation
    val latitude: Double? = null,
    val longitude: Double? = null,
) {
    val canSave: Boolean
        get() = name.isNotBlank() && street.isNotBlank() && postalCode.isNotBlank() && city.isNotBlank()

    val addressValidationLabel: String?
        get() = when (addressValidationResult) {
            is AddressValidationResult.Valid -> "Adresse validee"
            is AddressValidationResult.LowConfidence -> "Adresse incertaine — verifiez"
            is AddressValidationResult.NotFound -> "Adresse introuvable"
            is AddressValidationResult.InvalidSyntax -> null
            null -> null
        }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is CohouseFormState) return false
        return isEditMode == other.isEditMode &&
            cohouseId == other.cohouseId &&
            name == other.name &&
            street == other.street &&
            postalCode == other.postalCode &&
            city == other.city &&
            members == other.members &&
            newMemberName == other.newMemberName &&
            isSaving == other.isSaving &&
            error == other.error &&
            isValidatingAddress == other.isValidatingAddress &&
            addressValidationResult == other.addressValidationResult &&
            (coverImageData?.contentEquals(other.coverImageData ?: byteArrayOf()) ?: (other.coverImageData == null)) &&
            latitude == other.latitude &&
            longitude == other.longitude
    }

    override fun hashCode(): Int {
        var result = isEditMode.hashCode()
        result = 31 * result + (cohouseId?.hashCode() ?: 0)
        result = 31 * result + name.hashCode()
        result = 31 * result + street.hashCode()
        result = 31 * result + postalCode.hashCode()
        result = 31 * result + city.hashCode()
        result = 31 * result + members.hashCode()
        result = 31 * result + newMemberName.hashCode()
        result = 31 * result + isSaving.hashCode()
        result = 31 * result + (error?.hashCode() ?: 0)
        result = 31 * result + isValidatingAddress.hashCode()
        result = 31 * result + (addressValidationResult?.hashCode() ?: 0)
        result = 31 * result + (coverImageData?.contentHashCode() ?: 0)
        result = 31 * result + (latitude?.hashCode() ?: 0)
        result = 31 * result + (longitude?.hashCode() ?: 0)
        return result
    }
}

sealed interface CohouseFormIntent {
    data class NameChanged(val name: String) : CohouseFormIntent
    data class StreetChanged(val street: String) : CohouseFormIntent
    data class PostalCodeChanged(val postalCode: String) : CohouseFormIntent
    data class CityChanged(val city: String) : CohouseFormIntent
    data class NewMemberNameChanged(val name: String) : CohouseFormIntent
    data object AddMember : CohouseFormIntent
    data class RemoveMember(val memberId: String) : CohouseFormIntent
    data class CoverImagePicked(val imageData: ByteArray) : CohouseFormIntent
    data object CoverImageCleared : CohouseFormIntent
    data class ApplySuggestedAddress(val address: ValidatedAddress) : CohouseFormIntent
    data object Save : CohouseFormIntent
}

sealed interface CohouseFormEffect {
    data object Saved : CohouseFormEffect
}
