package dev.rahier.colockitchenrace.data.repository

import dev.rahier.colockitchenrace.data.model.Cohouse
import dev.rahier.colockitchenrace.data.model.CohouseUser
import kotlinx.coroutines.flow.StateFlow

interface CohouseRepository {
    val currentCohouse: StateFlow<Cohouse?>

    suspend fun add(cohouse: Cohouse)
    suspend fun get(id: String): Cohouse
    suspend fun getByCode(code: String): Cohouse
    suspend fun set(id: String, cohouse: Cohouse)
    suspend fun setUser(user: CohouseUser, cohouseId: String)
    suspend fun quitCohouse()
    suspend fun checkDuplicate(name: String, street: String, city: String): DuplicateResult
    suspend fun uploadCoverImage(cohouseId: String, imageData: ByteArray): String
    suspend fun loadCoverImage(path: String): ByteArray
    fun setCurrentCohouse(cohouse: Cohouse?)
}

data class DuplicateResult(
    val isDuplicate: Boolean,
    val reason: String? = null,
)
