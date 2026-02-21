package dev.rahier.colockitchenrace.data.model

data class PostalAddress(
    val street: String = "",
    val city: String = "",
    val postalCode: String = "",
    val country: String = "Belgique",
) {
    val lowercased: PostalAddress
        get() = PostalAddress(
            street = street.trim().lowercase(),
            city = city.trim().lowercase(),
            postalCode = postalCode.trim().lowercase(),
            country = country.trim().lowercase(),
        )

    val formatted: String
        get() = listOf(street, "$postalCode $city", country)
            .filter { it.isNotBlank() }
            .joinToString(", ")
}
