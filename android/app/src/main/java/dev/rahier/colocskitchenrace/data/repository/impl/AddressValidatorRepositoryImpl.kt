package dev.rahier.colocskitchenrace.data.repository.impl

import com.google.firebase.functions.FirebaseFunctions
import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.PostalAddress
import dev.rahier.colocskitchenrace.data.model.ValidatedAddress
import dev.rahier.colocskitchenrace.data.repository.AddressValidatorRepository
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AddressValidatorRepositoryImpl @Inject constructor(
    private val functions: FirebaseFunctions,
) : AddressValidatorRepository {

    override suspend fun validate(address: PostalAddress): AddressValidationResult {
        // Quick offline syntax check
        if (address.street.trim().length < 5 || address.city.trim().length < 2) {
            return AddressValidationResult.InvalidSyntax
        }

        val result = functions.getHttpsCallable("validateAddress")
            .call(
                hashMapOf(
                    "street" to address.street,
                    "city" to address.city,
                    "postalCode" to address.postalCode,
                    "country" to address.country,
                )
            )
            .await()

        @Suppress("UNCHECKED_CAST")
        val data = result.getData() as? Map<String, Any?> ?: return AddressValidationResult.NotFound

        val isValid = data["isValid"] as? Boolean ?: false
        if (!isValid) return AddressValidationResult.NotFound

        val normalizedStreet = data["street"] as? String ?: ""
        val normalizedCity = data["city"] as? String ?: ""
        val normalizedPostalCode = data["postalCode"] as? String ?: ""
        val normalizedCountry = data["country"] as? String ?: ""
        val latitude = (data["latitude"] as? Number)?.toDouble() ?: 0.0
        val longitude = (data["longitude"] as? Number)?.toDouble() ?: 0.0

        val validatedAddress = ValidatedAddress(
            street = normalizedStreet,
            city = normalizedCity,
            postalCode = normalizedPostalCode,
            country = normalizedCountry,
            latitude = latitude,
            longitude = longitude,
        )

        // Compute confidence score based on field matching (same as iOS)
        var confidence = 0.0
        if (normalizedCountry.equals(address.country.trim(), ignoreCase = true)) confidence += 0.2
        if (normalizedPostalCode.equals(address.postalCode.trim(), ignoreCase = true)) confidence += 0.4
        if (normalizedCity.equals(address.city.trim(), ignoreCase = true)) confidence += 0.2
        if (normalizedStreet.lowercase().contains(address.street.trim().lowercase())) confidence += 0.2

        return if (confidence >= CONFIDENCE_THRESHOLD) {
            AddressValidationResult.Valid(validatedAddress)
        } else {
            AddressValidationResult.LowConfidence(validatedAddress)
        }
    }

    companion object {
        private const val CONFIDENCE_THRESHOLD = 0.8
    }
}
