package dev.rahier.colockitchenrace.ui.cohouse.form

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.CohouseUser
import dev.rahier.colockitchenrace.data.model.PostalAddress
import dev.rahier.colockitchenrace.data.repository.AuthRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.channels.Channel
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
) {
    val canSave: Boolean
        get() = name.isNotBlank() && street.isNotBlank() && postalCode.isNotBlank() && city.isNotBlank()
}

sealed class CohouseFormIntent {
    data class NameChanged(val name: String) : CohouseFormIntent()
    data class StreetChanged(val street: String) : CohouseFormIntent()
    data class PostalCodeChanged(val postalCode: String) : CohouseFormIntent()
    data class CityChanged(val city: String) : CohouseFormIntent()
    data class NewMemberNameChanged(val name: String) : CohouseFormIntent()
    data object AddMember : CohouseFormIntent()
    data class RemoveMember(val memberId: String) : CohouseFormIntent()
    data object Save : CohouseFormIntent()
}

sealed class CohouseFormEffect {
    data object Saved : CohouseFormEffect()
}

@HiltViewModel
class CohouseFormViewModel @Inject constructor(
    private val cohouseRepository: CohouseRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(CohouseFormState())
    val state: StateFlow<CohouseFormState> = _state.asStateFlow()

    private val _effect = Channel<CohouseFormEffect>()
    val effect = _effect.receiveAsFlow()

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
            )
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
            is CohouseFormIntent.StreetChanged -> _state.update { it.copy(street = intent.street) }
            is CohouseFormIntent.PostalCodeChanged -> _state.update { it.copy(postalCode = intent.postalCode) }
            is CohouseFormIntent.CityChanged -> _state.update { it.copy(city = intent.city) }
            is CohouseFormIntent.NewMemberNameChanged -> _state.update { it.copy(newMemberName = intent.name) }
            CohouseFormIntent.AddMember -> addMember()
            is CohouseFormIntent.RemoveMember -> removeMember(intent.memberId)
            CohouseFormIntent.Save -> save()
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
        // Don't allow removing admin users
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
                    val updated = existing.copy(
                        name = s.name,
                        address = address,
                        users = s.members,
                    )
                    cohouseRepository.set(s.cohouseId, updated)
                    cohouseRepository.setCurrentCohouse(updated)
                } else {
                    // Check for duplicates
                    val duplicateResult = cohouseRepository.checkDuplicate(s.name, s.street, s.city)
                    if (duplicateResult.isDuplicate) {
                        _state.update { it.copy(isSaving = false, error = duplicateResult.reason ?: "Cette coloc existe deja") }
                        return@launch
                    }

                    val code = generateCode()
                    val cohouse = Cohouse(
                        name = s.name,
                        address = address,
                        code = code,
                        users = s.members,
                    )
                    cohouseRepository.add(cohouse)
                    cohouseRepository.setCurrentCohouse(cohouse)

                    // Update user's cohouseId
                    val user = authRepository.currentUser.value
                    if (user != null) {
                        authRepository.updateUser(user.copy(cohouseId = cohouse.id))
                    }
                }

                _state.update { it.copy(isSaving = false) }
                _effect.send(CohouseFormEffect.Saved)
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, error = e.message ?: "Erreur lors de la sauvegarde") }
            }
        }
    }

    private fun generateCode(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return (1..6).map { chars.random() }.joinToString("")
    }
}
