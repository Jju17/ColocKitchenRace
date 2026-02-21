package dev.rahier.colockitchenrace.data.model

import java.util.Date

data class CKRMyPlanning(
    val apero: PlanningStep,
    val diner: PlanningStep,
    val party: PartyInfo,
)

enum class StepRole { HOST, VISITOR }

data class PlanningStep(
    val role: StepRole,
    val cohouseName: String,
    val address: String,
    val hostPhone: String? = null,
    val visitorPhone: String? = null,
    val totalPeople: Int,
    val dietarySummary: Map<String, Int> = emptyMap(),
    val startTime: Date,
    val endTime: Date,
) {
    val id: String get() = "${role.name.lowercase()}-$cohouseName"
}

data class PartyInfo(
    val name: String,
    val address: String,
    val startTime: Date,
    val endTime: Date,
    val note: String? = null,
)
