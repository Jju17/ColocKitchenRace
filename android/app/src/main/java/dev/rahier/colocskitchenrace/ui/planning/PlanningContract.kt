package dev.rahier.colocskitchenrace.ui.planning

import dev.rahier.colocskitchenrace.data.model.CKRMyPlanning

data class PlanningState(
    val planning: CKRMyPlanning? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
)

sealed interface PlanningIntent {
    data object Retry : PlanningIntent
}
