package dev.rahier.colockitchenrace.data.model

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
            "glutenFree" -> GLUTEN_FREE
            "lactoseFree" -> LACTOSE_FREE
            "nutFree" -> NUT_FREE
            else -> null
        }
    }

    fun toFirestore(): String = when (this) {
        VEGETARIAN -> "vegetarian"
        VEGAN -> "vegan"
        GLUTEN_FREE -> "glutenFree"
        LACTOSE_FREE -> "lactoseFree"
        NUT_FREE -> "nutFree"
    }
}
