package dev.rahier.colocskitchenrace.ui.cohouse.form

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import dev.rahier.colocskitchenrace.data.model.PostalAddress
import dev.rahier.colocskitchenrace.data.model.ValidatedAddress
import dev.rahier.colocskitchenrace.data.repository.AddressValidatorRepository
import dev.rahier.colocskitchenrace.data.repository.AuthRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.util.ErrorMapper
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

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

sealed class CohouseFormIntent {
    data class NameChanged(val name: String) : CohouseFormIntent()
    data class StreetChanged(val street: String) : CohouseFormIntent()
    data class PostalCodeChanged(val postalCode: String) : CohouseFormIntent()
    data class CityChanged(val city: String) : CohouseFormIntent()
    data class NewMemberNameChanged(val name: String) : CohouseFormIntent()
    data object AddMember : CohouseFormIntent()
    data class RemoveMember(val memberId: String) : CohouseFormIntent()
    data class CoverImagePicked(val imageData: ByteArray) : CohouseFormIntent()
    data object CoverImageCleared : CohouseFormIntent()
    data class ApplySuggestedAddress(val address: ValidatedAddress) : CohouseFormIntent()
    data object Save : CohouseFormIntent()
}

sealed class CohouseFormEffect {
    data object Saved : CohouseFormEffect()
}

@HiltViewModel
class CohouseFormViewModel @Inject constructor(
    private val cohouseRepository: CohouseRepository,
    private val authRepository: AuthRepository,
    private val addressValidatorRepository: AddressValidatorRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(CohouseFormState())
    val state: StateFlow<CohouseFormState> = _state.asStateFlow()

    private val _effect = Channel<CohouseFormEffect>()
    val effect = _effect.receiveAsFlow()

    private var addressValidationJob: Job? = null

    fun initForEdit() {
        val cohouse = cohouseRepository.currentCohouse.value ?: return
        _state.update {
            it.copy(
                isEditMode = true,
                cohouseId = cohouse.id,
                name = cohouse.name,
                street = cohouse.address.street,
                postalCode = cohouse.address.postalCode,
                city = cohouse.address.city,
                members = cohouse.users,
                latitude = cohouse.latitude,
                longitude = cohouse.longitude,
            )
        }
        // Load cover image if exists
        cohouse.coverImagePath?.let { path ->
            viewModelScope.launch {
                try {
                    val data = cohouseRepository.loadCoverImage(path)
                    _state.update { it.copy(coverImageData = data) }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Log.w("CohouseForm", "Failed to load cover image", e)
                }
            }
        }
    }

    fun initForCreate() {
        val user = authRepository.currentUser.value ?: return
        val adminUser = user.toCohouseUser(isAdmin = true)
        _state.update {
            it.copy(
                isEditMode = false,
                members = listOf(adminUser),
            )
        }
    }

    fun onIntent(intent: CohouseFormIntent) {
        when (intent) {
            is CohouseFormIntent.NameChanged -> _state.update { it.copy(name = intent.name) }
            is CohouseFormIntent.StreetChanged -> {
                _state.update { it.copy(street = intent.street) }
                debouncedValidateAddress()
            }
            is CohouseFormIntent.PostalCodeChanged -> {
                _state.update { it.copy(postalCode = intent.postalCode) }
                debouncedValidateAddress()
            }
            is CohouseFormIntent.CityChanged -> {
                _state.update { it.copy(city = intent.city) }
                debouncedValidateAddress()
            }
            is CohouseFormIntent.NewMemberNameChanged -> _state.update { it.copy(newMemberName = intent.name) }
            CohouseFormIntent.AddMember -> addMember()
            is CohouseFormIntent.RemoveMember -> removeMember(intent.memberId)
            is CohouseFormIntent.CoverImagePicked -> _state.update { it.copy(coverImageData = intent.imageData) }
            CohouseFormIntent.CoverImageCleared -> _state.update { it.copy(coverImageData = null) }
            is CohouseFormIntent.ApplySuggestedAddress -> applySuggestedAddress(intent.address)
            CohouseFormIntent.Save -> save()
        }
    }

    private fun debouncedValidateAddress() {
        addressValidationJob?.cancel()
        addressValidationJob = viewModelScope.launch {
            delay(ADDRESS_VALIDATION_DEBOUNCE_MS)
            validateAddress()
        }
    }

    private suspend fun validateAddress() {
        val s = _state.value
        if (s.street.isBlank() || s.city.isBlank()) {
            _state.update { it.copy(addressValidationResult = null, isValidatingAddress = false) }
            return
        }

        _state.update { it.copy(isValidatingAddress = true) }
        try {
            val address = PostalAddress(
                street = s.street,
                postalCode = s.postalCode,
                city = s.city,
            )
            val result = addressValidatorRepository.validate(address)
            _state.update { it.copy(isValidatingAddress = false, addressValidationResult = result) }

            // Extract coordinates from validated address
            when (result) {
                is AddressValidationResult.Valid -> _state.update {
                    it.copy(latitude = result.address.latitude, longitude = result.address.longitude)
                }
                is AddressValidationResult.LowConfidence -> _state.update {
                    it.copy(latitude = result.address.latitude, longitude = result.address.longitude)
                }
                else -> {}
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w("CohouseForm", "Failed to validate address", e)
            _state.update { it.copy(isValidatingAddress = false) }
        }
    }

    private fun applySuggestedAddress(address: ValidatedAddress) {
        _state.update {
            it.copy(
                street = address.street,
                postalCode = address.postalCode,
                city = address.city,
                latitude = address.latitude,
                longitude = address.longitude,
                addressValidationResult = AddressValidationResult.Valid(address),
            )
        }
    }

    private fun addMember() {
        val name = _state.value.newMemberName.trim()
        if (name.isBlank()) return
        if (_state.value.members.any { it.surname.equals(name, ignoreCase = true) }) return

        val newUser = CohouseUser(
            id = UUID.randomUUID().toString(),
            surname = name,
        )
        _state.update {
            it.copy(
                members = it.members + newUser,
                newMemberName = "",
            )
        }
    }

    private fun removeMember(memberId: String) {
        val member = _state.value.members.find { it.id == memberId }
        if (member?.isAdmin == true) return

        _state.update { it.copy(members = it.members.filter { m -> m.id != memberId }) }
    }

    private fun save() {
        val s = _state.value
        if (!s.canSave) return

        viewModelScope.launch {
            _state.update { it.copy(isSaving = true, error = null) }
            try {
                val address = PostalAddress(
                    street = s.street,
                    postalCode = s.postalCode,
                    city = s.city,
                )

                if (s.isEditMode && s.cohouseId != null) {
                    val existing = cohouseRepository.currentCohouse.value ?: return@launch
                    // Strip empty non-admin users (like iOS)
                    val cleanMembers = s.members.filter { it.surname.isNotBlank() || it.isAdmin }
                    val updated = existing.copy(
                        name = s.name,
                        address = address,
                        users = cleanMembers,
                        latitude = s.latitude,
                        longitude = s.longitude,
                    )
                    cohouseRepository.set(s.cohouseId, updated)

                    // Upload cover image if changed
                    s.coverImageData?.let { imageData ->
                        val path = cohouseRepository.uploadCoverImage(s.cohouseId, imageData)
                        cohouseRepository.set(s.cohouseId, updated.copy(coverImagePath = path))
                        cohouseRepository.setCurrentCohouse(updated.copy(coverImagePath = path))
                    } ?: cohouseRepository.setCurrentCohouse(updated)
                } else {
                    // Check for duplicates
                    val duplicateResult = cohouseRepository.checkDuplicate(s.name, s.street, s.city)
                    if (duplicateResult.isDuplicate) {
                        _state.update { it.copy(isSaving = false, error = duplicateResult.reason ?: "Cette coloc existe deja") }
                        return@launch
                    }

                    val code = generateCode()
                    val cleanMembers = s.members.filter { it.surname.isNotBlank() || it.isAdmin }
                    val cohouse = Cohouse(
                        name = s.name,
                        address = address,
                        code = code,
                        users = cleanMembers,
                        latitude = s.latitude,
                        longitude = s.longitude,
                    )
                    cohouseRepository.add(cohouse)

                    // Upload cover image
                    var finalCohouse = cohouse
                    s.coverImageData?.let { imageData ->
                        val path = cohouseRepository.uploadCoverImage(cohouse.id, imageData)
                        finalCohouse = cohouse.copy(coverImagePath = path)
                        cohouseRepository.set(cohouse.id, finalCohouse)
                    }
                    cohouseRepository.setCurrentCohouse(finalCohouse)

                    // Update user's cohouseId
                    val user = authRepository.currentUser.value
                    if (user != null) {
                        authRepository.updateUser(user.copy(cohouseId = cohouse.id))
                    }
                }

                _state.update { it.copy(isSaving = false) }
                _effect.send(CohouseFormEffect.Saved)
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, error = ErrorMapper.toUserMessage(e, "Erreur lors de la sauvegarde")) }
            }
        }
    }

    private fun generateCode(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return (1..6).map { chars.random() }.joinToString("")
    }

    companion object {
        private const val ADDRESS_VALIDATION_DEBOUNCE_MS = 600L
    }
}
