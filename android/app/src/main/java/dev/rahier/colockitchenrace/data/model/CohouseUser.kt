package dev.rahier.colockitchenrace.data.model

import java.util.UUID

data class CohouseUser(
    val id: String = UUID.randomUUID().toString(),
    val isAdmin: Boolean = false,
    val surname: String = "",
    val userId: String? = null,
) {
    val isAssignedToRealUser: Boolean get() = userId != null
}
