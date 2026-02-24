package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.AddressValidationResult
import dev.rahier.colocskitchenrace.data.model.PostalAddress

interface AddressValidatorRepository {
    suspend fun validate(address: PostalAddress): AddressValidationResult
}
