package dev.rahier.colocskitchenrace.ui.home.registration

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.rahier.colocskitchenrace.data.model.CohouseType
import dev.rahier.colocskitchenrace.data.repository.CKRGameRepository
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

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
