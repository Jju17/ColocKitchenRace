package dev.rahier.colocskitchenrace.data.repository.impl

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dev.rahier.colocskitchenrace.data.model.IdCardInfo
import dev.rahier.colocskitchenrace.data.model.IdCardScanResult
import dev.rahier.colocskitchenrace.data.repository.IdCardScannerRepository
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class IdCardScannerRepositoryImpl @Inject constructor() : IdCardScannerRepository {

    override suspend fun scanIdCard(imageData: ByteArray): IdCardScanResult {
        return try {
            val bitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size)
                ?: return IdCardScanResult.Error("Failed to decode image")

            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val result = recognizer.process(inputImage).await()

            val allText = result.text
            if (allText.isBlank()) {
                return IdCardScanResult.PoorQuality
            }

            val lines = result.textBlocks.flatMap { it.lines }.map { it.text }
            val score = computeBelgianIdScore(lines)

            if (score >= MIN_VALID_SCORE) {
                val info = extractIdCardInfo(lines, allText)
                IdCardScanResult.Valid(info)
            } else if (score >= MIN_POOR_QUALITY_SCORE) {
                IdCardScanResult.PoorQuality
            } else {
                IdCardScanResult.NotAnIdCard
            }
        } catch (e: Exception) {
            IdCardScanResult.Error(e.message ?: "Unknown OCR error")
        }
    }

    private fun computeBelgianIdScore(lines: List<String>): Int {
        val upperLines = lines.map { it.uppercase() }
        val joinedText = upperLines.joinToString(" ")
        var score = 0

        // Country keywords
        if (COUNTRY_KEYWORDS.any { joinedText.contains(it) }) score++

        // Document type keywords
        if (DOCUMENT_TYPE_KEYWORDS.any { joinedText.contains(it) }) score++

        // Field labels
        val matchingLabels = FIELD_LABELS.count { label -> upperLines.any { it.contains(label) } }
        if (matchingLabels >= 2) score++
        if (matchingLabels >= 4) score++

        // Date pattern (DD.MM.YYYY or DD/MM/YYYY or DD-MM-YYYY)
        if (DATE_PATTERN.containsMatchIn(joinedText)) score++

        // Belgian national register number (YY.MM.DD-XXX.XX)
        if (NATIONAL_REGISTER_PATTERN.containsMatchIn(joinedText)) score++

        return score
    }

    private fun extractIdCardInfo(lines: List<String>, allText: String): IdCardInfo {
        val upperLines = lines.map { it.uppercase() }
        val joinedText = upperLines.joinToString(" ")

        val documentType = DOCUMENT_TYPE_KEYWORDS.firstOrNull { joinedText.contains(it) }

        val nationality = COUNTRY_KEYWORDS.firstOrNull { joinedText.contains(it) }

        // Try to find name (line after NOM/NAAM label)
        val nameLineIndex = lines.indexOfFirst { line ->
            NAME_LABELS.any { line.uppercase().contains(it) }
        }
        val name = if (nameLineIndex >= 0 && nameLineIndex + 1 < lines.size) {
            lines[nameLineIndex + 1].trim()
        } else {
            null
        }

        // Find date of birth
        val dateMatch = DATE_PATTERN.find(joinedText)
        val dateOfBirth = dateMatch?.value

        return IdCardInfo(
            documentType = documentType,
            name = name,
            dateOfBirth = dateOfBirth,
            nationality = nationality,
            recognizedTextSnippet = allText.take(200),
        )
    }

    companion object {
        private const val MIN_VALID_SCORE = 3
        private const val MIN_POOR_QUALITY_SCORE = 1

        private val COUNTRY_KEYWORDS = listOf(
            "BELGIQUE", "BELGIE", "BELGIEN", "BELGIUM",
        )

        private val DOCUMENT_TYPE_KEYWORDS = listOf(
            "CARTE D'IDENTITE", "IDENTITEITSKAART", "PERSONALAUSWEIS",
            "IDENTITY CARD", "IDENTITE",
        )

        private val FIELD_LABELS = listOf(
            "NOM", "NAAM", "NAME",
            "PRENOM", "VOORNAAM", "VORNAME",
            "NATIONALITE", "NATIONALITEIT",
            "DATE DE NAISSANCE", "GEBOORTEDATUM",
            "LIEU DE NAISSANCE", "GEBOORTEPLAATS",
            "SEXE", "GESLACHT",
        )

        private val NAME_LABELS = listOf("NOM", "NAAM", "NAME")

        private val DATE_PATTERN = Regex("""\d{2}[./\-]\d{2}[./\-]\d{4}""")
        private val NATIONAL_REGISTER_PATTERN = Regex("""\d{2}\.\d{2}\.\d{2}-\d{3}\.\d{2}""")
    }
}
