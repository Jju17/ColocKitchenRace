package dev.rahier.colocskitchenrace.data.repository.impl

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.storage.FirebaseStorage
import dev.rahier.colocskitchenrace.data.model.Cohouse
import dev.rahier.colocskitchenrace.data.model.CohouseType
import dev.rahier.colocskitchenrace.data.model.CohouseUser
import dev.rahier.colocskitchenrace.data.model.PostalAddress
import dev.rahier.colocskitchenrace.data.repository.CohouseRepository
import dev.rahier.colocskitchenrace.data.repository.DuplicateResult
import dev.rahier.colocskitchenrace.util.Constants
import dev.rahier.colocskitchenrace.util.DemoMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CohouseRepositoryImpl @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val functions: FirebaseFunctions,
    private val storage: FirebaseStorage,
) : CohouseRepository {

    private val _currentCohouse = MutableStateFlow<Cohouse?>(null)
    override val currentCohouse: StateFlow<Cohouse?> = _currentCohouse.asStateFlow()

    override suspend fun add(cohouse: Cohouse) {
        val data = cohouseToMap(cohouse)
        firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(cohouse.id)
            .set(data)
            .await()

        // Add users as subcollection
        val batch = firestore.batch()
        for (user in cohouse.users) {
            val userRef = firestore.collection(Constants.COHOUSES_COLLECTION)
                .document(cohouse.id)
                .collection("users")
                .document(user.id)
            batch.set(userRef, cohouseUserToMap(user))
        }
        batch.commit().await()
        _currentCohouse.value = cohouse
        refreshCohouseClaim()
    }

    override suspend fun get(id: String): Cohouse {
        if (DemoMode.isActive) return DemoMode.demoCohouse

        val doc = firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(id)
            .get()
            .await()
        val cohouse = mapToCohouse(doc.data!!, doc.id)

        // Load users subcollection
        val usersSnapshot = firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(id)
            .collection("users")
            .get()
            .await()
        val users = usersSnapshot.documents.map { mapToCohouseUser(it.data!!, it.id) }
        return cohouse.copy(users = users)
    }

    override suspend fun getByCode(code: String): Cohouse {
        val snapshot = firestore.collection(Constants.COHOUSES_COLLECTION)
            .whereEqualTo("code", code)
            .limit(1)
            .get()
            .await()
        if (snapshot.documents.isEmpty()) throw Exception("No cohouse found with code $code")
        val doc = snapshot.documents[0]
        val cohouse = mapToCohouse(doc.data!!, doc.id)

        val usersSnapshot = firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(cohouse.id)
            .collection("users")
            .get()
            .await()
        val users = usersSnapshot.documents.map { mapToCohouseUser(it.data!!, it.id) }
        return cohouse.copy(users = users)
    }

    override suspend fun set(id: String, cohouse: Cohouse) {
        firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(id)
            .set(cohouseToMap(cohouse))
            .await()

        // Rewrite users subcollection
        val existingUsers = firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(id).collection("users").get().await()
        val batch = firestore.batch()
        for (doc in existingUsers.documents) {
            batch.delete(doc.reference)
        }
        for (user in cohouse.users) {
            val ref = firestore.collection(Constants.COHOUSES_COLLECTION)
                .document(id).collection("users").document(user.id)
            batch.set(ref, cohouseUserToMap(user))
        }
        batch.commit().await()
        _currentCohouse.value = cohouse
    }

    override suspend fun setUser(user: CohouseUser, cohouseId: String) {
        firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(cohouseId)
            .collection("users")
            .document(user.id)
            .set(cohouseUserToMap(user))
            .await()
        refreshCohouseClaim()
    }

    override suspend fun removeUser(cohouseUserId: String, cohouseId: String) {
        firestore.collection(Constants.COHOUSES_COLLECTION)
            .document(cohouseId)
            .collection("users")
            .document(cohouseUserId)
            .delete()
            .await()
    }

    override suspend fun quitCohouse() {
        _currentCohouse.value = null
        refreshCohouseClaim()
    }

    override suspend fun checkDuplicate(name: String, street: String, city: String): DuplicateResult {
        val result = functions.getHttpsCallable("checkDuplicateCohouse")
            .call(hashMapOf("name" to name, "street" to street, "city" to city))
            .await()
        @Suppress("UNCHECKED_CAST")
        val data = result.getData() as Map<String, Any>
        return DuplicateResult(
            isDuplicate = data["isDuplicate"] as Boolean,
            reason = data["reason"] as? String,
        )
    }

    override suspend fun uploadCoverImage(cohouseId: String, imageData: ByteArray): String {
        val ref = storage.reference.child("cohouses/$cohouseId/cover_image.jpg")
        ref.putBytes(imageData).await()
        return ref.path
    }

    override suspend fun uploadIdCard(cohouseId: String, imageData: ByteArray): String {
        val ref = storage.reference.child("cohouses/$cohouseId/id_card.jpg")
        ref.putBytes(imageData).await()
        return ref.path
    }

    override suspend fun loadCoverImage(path: String): ByteArray {
        return storage.reference.child(path).getBytes(5 * 1024 * 1024).await()
    }

    override fun setCurrentCohouse(cohouse: Cohouse?) {
        _currentCohouse.value = cohouse
    }

    /**
     * Calls the setCohouseClaim Cloud Function and forces a token refresh
     * so that Firestore security rules see the updated cohouseId claim.
     */
    private suspend fun refreshCohouseClaim() {
        try {
            functions.getHttpsCallable("setCohouseClaim").call().await()
            FirebaseAuth.getInstance().currentUser?.getIdToken(true)?.await()
        } catch (e: Exception) {
            // Non-blocking: claim refresh failure shouldn't break the main flow.
            // The claim will be set on next app launch or token refresh.
            android.util.Log.w("CohouseRepository", "Failed to refresh cohouse claim", e)
        }
    }

    companion object {
        fun cohouseToMap(cohouse: Cohouse): Map<String, Any?> = mapOf(
            "id" to cohouse.id,
            "name" to cohouse.name,
            "nameLower" to cohouse.name.trim().lowercase(),
            "address" to mapOf(
                "street" to cohouse.address.street,
                "city" to cohouse.address.city,
                "postalCode" to cohouse.address.postalCode,
                "country" to cohouse.address.country,
            ),
            "addressLower" to mapOf(
                "street" to cohouse.address.street.trim().lowercase(),
                "city" to cohouse.address.city.trim().lowercase(),
                "postalCode" to cohouse.address.postalCode.trim().lowercase(),
                "country" to cohouse.address.country.trim().lowercase(),
            ),
            "code" to cohouse.code,
            "latitude" to cohouse.latitude,
            "longitude" to cohouse.longitude,
            "coverImagePath" to cohouse.coverImagePath,
            "cohouseType" to cohouse.cohouseType?.toFirestore(),
        )

        @Suppress("UNCHECKED_CAST")
        fun mapToCohouse(data: Map<String, Any?>, docId: String): Cohouse {
            val address = data["address"] as? Map<String, Any?> ?: emptyMap()
            return Cohouse(
                id = data["id"] as? String ?: docId,
                name = data["name"] as? String ?: "",
                address = PostalAddress(
                    street = address["street"] as? String ?: "",
                    city = address["city"] as? String ?: "",
                    postalCode = address["postalCode"] as? String ?: "",
                    country = address["country"] as? String ?: "Belgique",
                ),
                code = data["code"] as? String ?: "",
                latitude = (data["latitude"] as? Number)?.toDouble(),
                longitude = (data["longitude"] as? Number)?.toDouble(),
                coverImagePath = data["coverImagePath"] as? String,
                cohouseType = (data["cohouseType"] as? String)?.let { CohouseType.fromFirestore(it) },
            )
        }

        fun cohouseUserToMap(user: CohouseUser): Map<String, Any?> = mapOf(
            "id" to user.id,
            "isAdmin" to user.isAdmin,
            "surname" to user.surname,
            "userId" to user.userId,
        )

        fun mapToCohouseUser(data: Map<String, Any?>, docId: String): CohouseUser = CohouseUser(
            id = data["id"] as? String ?: docId,
            isAdmin = data["isAdmin"] as? Boolean ?: false,
            surname = data["surname"] as? String ?: "",
            userId = data["userId"] as? String,
        )
    }
}
