package dev.rahier.colocskitchenrace.data.model

import java.util.Date

data class News(
    val id: String = "",
    val title: String = "",
    val body: String = "",
    val publicationDate: Date = Date(),
)
