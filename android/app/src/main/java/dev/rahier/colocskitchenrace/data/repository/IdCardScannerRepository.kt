package dev.rahier.colocskitchenrace.data.repository

import dev.rahier.colocskitchenrace.data.model.IdCardScanResult

interface IdCardScannerRepository {
    suspend fun scanIdCard(imageData: ByteArray): IdCardScanResult
}
