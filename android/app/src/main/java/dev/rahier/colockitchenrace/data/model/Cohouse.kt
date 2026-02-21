package dev.rahier.colockitchenrace.data.model

import java.util.UUID

data class Cohouse(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val address: PostalAddress = PostalAddress(),
    val code: String = "",
    val latitude: Double? = null,
    val longitude: Double? = null,
    val users: List<CohouseUser> = emptyList(),
    val coverImagePath: String? = null,
    val cohouseType: CohouseType? = null,
) {
    val totalUsers: Int get() = users.size

    fun isAdmin(userId: String?): Boolean {
        if (userId == null) return false
        return users.any { it.userId == userId && it.isAdmin }
    }
}
