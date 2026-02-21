package dev.rahier.colockitchenrace.data.model

enum class CohouseType(val displayName: String) {
    MIXED("Mixte"),
    GIRLS("Filles"),
    BOYS("Garcons");

    companion object {
        fun fromFirestore(value: String): CohouseType? = when (value) {
            "mixed" -> MIXED
            "girls" -> GIRLS
            "boys" -> BOYS
            else -> null
        }
    }

    fun toFirestore(): String = when (this) {
        MIXED -> "mixed"
        GIRLS -> "girls"
        BOYS -> "boys"
    }
}
