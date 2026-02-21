package dev.rahier.colockitchenrace.ui.home.registration

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colockitchenrace.data.model.CKRGame
import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.CohouseType
import dev.rahier.colockitchenrace.data.model.CohouseUser
import dev.rahier.colockitchenrace.data.repository.CKRGameRepository
import dev.rahier.colockitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
import javax.inject.Inject

data class RegistrationFormState(
    val game: CKRGame? = null,
    val cohouse: Cohouse? = null,
    val selectedUserIds: Set<String> = emptySet(),
    val averageAge: String = "",
    val cohouseType: CohouseType = CohouseType.MIXED,
    val isLoading: Boolean = false,
) {
    val participants: List<CohouseUser>
        get() = cohouse?.users ?: emptyList()

    val selectedCount: Int
        get() = selectedUserIds.size

    val totalPriceCents: Int
        get() = selectedCount * (game?.pricePerPersonCents ?: 0)

    val formattedTotal: String
        get() {
            val euros = totalPriceCents / 100.0
            val formatter = NumberFormat.getCurrencyInstance(Locale("fr", "BE"))
            formatter.currency = Currency.getInstance("EUR")
            return formatter.format(euros)
        }

    val canContinue: Boolean
        get() = selectedCount > 0 && averageAge.isNotBlank()
}

sealed class RegistrationFormIntent {
    data class ToggleUser(val userId: String) : RegistrationFormIntent()
    data class AverageAgeChanged(val age: String) : RegistrationFormIntent()
    data class CohouseTypeChanged(val type: CohouseType) : RegistrationFormIntent()
    data object ContinueToPayment : RegistrationFormIntent()
}

sealed class RegistrationFormEffect {
    data class NavigateToPayment(
        val gameId: String,
        val cohouseId: String,
        val attendingUserIds: List<String>,
        val averageAge: Int,
        val cohouseType: String,
        val totalPriceCents: Int,
        val participantCount: Int,
    ) : RegistrationFormEffect()
}

@HiltViewModel
class RegistrationFormViewModel @Inject constructor(
    private val gameRepository: CKRGameRepository,
    private val cohouseRepository: CohouseRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(RegistrationFormState())
    val state: StateFlow<RegistrationFormState> = _state.asStateFlow()

    private val _effect = Channel<RegistrationFormEffect>()
    val effect = _effect.receiveAsFlow()

    init {
        viewModelScope.launch {
            val game = gameRepository.currentGame.value
            val cohouse = cohouseRepository.currentCohouse.value
            _state.update {
                it.copy(
                    game = game,
                    cohouse = cohouse,
                    cohouseType = cohouse?.cohouseType ?: CohouseType.MIXED,
                )
            }
        }
    }

    fun onIntent(intent: RegistrationFormIntent) {
        when (intent) {
            is RegistrationFormIntent.ToggleUser -> toggleUser(intent.userId)
            is RegistrationFormIntent.AverageAgeChanged -> _state.update { it.copy(averageAge = intent.age) }
            is RegistrationFormIntent.CohouseTypeChanged -> _state.update { it.copy(cohouseType = intent.type) }
            RegistrationFormIntent.ContinueToPayment -> continueToPayment()
        }
    }

    private fun toggleUser(userId: String) {
        _state.update {
            val newSet = it.selectedUserIds.toMutableSet()
            if (userId in newSet) newSet.remove(userId) else newSet.add(userId)
            it.copy(selectedUserIds = newSet)
        }
    }

    private fun continueToPayment() {
        val s = _state.value
        val game = s.game ?: return
        val cohouse = s.cohouse ?: return
        val age = s.averageAge.toIntOrNull() ?: return

        viewModelScope.launch {
            _effect.send(
                RegistrationFormEffect.NavigateToPayment(
                    gameId = game.id,
                    cohouseId = cohouse.id,
                    attendingUserIds = s.selectedUserIds.toList(),
                    averageAge = age,
                    cohouseType = s.cohouseType.toFirestore(),
                    totalPriceCents = s.totalPriceCents,
                    participantCount = s.selectedCount,
                )
            )
        }
    }
}
