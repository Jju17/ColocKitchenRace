package dev.rahier.colocskitchenrace.data.model

enum class DietaryPreference(val displayName: String, val icon: String) {
    VEGETARIAN("Vegetarien", "\uD83E\uDD66"),
    VEGAN("Vegan", "\uD83C\uDF31"),
    GLUTEN_FREE("Sans gluten", "\uD83C\uDF3E"),
    LACTOSE_FREE("Sans lactose", "\uD83E\uDD5B"),
    NUT_FREE("Sans noix", "\uD83E\uDD5C");

    companion object {
        fun fromFirestore(value: String): DietaryPreference? = when (value) {
            "vegetarian" -> VEGETARIAN
            "vegan" -> VEGAN
            "gluten_free" -> GLUTEN_FREE
            "lactose_free" -> LACTOSE_FREE
            "nut_free" -> NUT_FREE
            else -> null
        }
    }

    fun toFirestore(): String = when (this) {
        VEGETARIAN -> "vegetarian"
        VEGAN -> "vegan"
        GLUTEN_FREE -> "gluten_free"
        LACTOSE_FREE -> "lactose_free"
        NUT_FREE -> "nut_free"
    }
}
