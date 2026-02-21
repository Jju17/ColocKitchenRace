//
//  IdCardScannerClient.swift
//  ColocsKitchenRace
//
//  Created by Julien Rahier on 09/02/2026.
//

import ComposableArchitecture
import UIKit
import Vision

// MARK: - Result Types

struct IdCardInfo: Equatable, Sendable {
    var documentType: String?
    var name: String?
    var dateOfBirth: String?
    var nationality: String?
    var recognizedTextSnippet: String?
}

enum IdCardScanResult: Equatable, Sendable {
    case valid(IdCardInfo)
    case notAnIdCard
    case poorQuality
    case error(String)
}

// MARK: - Client Interface

@DependencyClient
struct IdCardScannerClient {
    var scanIdCard: @Sendable (_ imageData: Data) async -> IdCardScanResult = { _ in .notAnIdCard }
}

// MARK: - Implementations

extension IdCardScannerClient: DependencyKey {

    // MARK: Live

    static let liveValue = Self(
        scanIdCard: { imageData in
            guard let cgImage = UIImage(data: imageData)?.cgImage else {
                return .error("Could not decode image data")
            }

            // Step 1: Document segmentation
            let documentConfidence: Float
            do {
                documentConfidence = try await detectDocument(in: cgImage)
            } catch {
                return .error("Document detection failed: \(error.localizedDescription)")
            }

            guard documentConfidence >= 0.5 else {
                return .notAnIdCard
            }

            let isLowQualityDocument = documentConfidence < 0.75

            // Step 2: OCR
            let recognizedTexts: [String]
            do {
                recognizedTexts = try await recognizeText(in: cgImage)
            } catch {
                return .error("Text recognition failed: \(error.localizedDescription)")
            }

            let allText = recognizedTexts.joined(separator: " ").uppercased()

            guard allText.count >= 10 else {
                return isLowQualityDocument ? .poorQuality : .notAnIdCard
            }

            // Step 3: Heuristic validation
            let info = extractIdCardInfo(from: recognizedTexts, allText: allText)
            let score = computeIdCardScore(allText: allText)

            if score >= 3 {
                return .valid(info)
            } else if score >= 1 || isLowQualityDocument {
                return .poorQuality
            } else {
                return .notAnIdCard
            }
        }
    )

    // MARK: Test

    static let testValue = Self(
        scanIdCard: { _ in .valid(IdCardInfo()) }
    )

    // MARK: Preview

    static let previewValue = Self(
        scanIdCard: { _ in
            .valid(IdCardInfo(
                documentType: "Carte d'identite",
                name: "RAHIER Julien",
                dateOfBirth: "01.01.1990",
                nationality: "Belgian"
            ))
        }
    )

    // MARK: - Private Helpers

    private static func detectDocument(in cgImage: CGImage) async throws -> Float {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectDocumentSegmentationRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = request.results?.first as? VNRectangleObservation else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: result.confidence)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func recognizeText(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let texts = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: texts)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr", "nl", "de", "en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func computeIdCardScore(allText: String) -> Int {
        var score = 0

        // Belgian country identifiers
        let countryKeywords = ["BELGIQUE", "BELGIE", "BELGIEN", "BELGIUM", "KONINKRIJK", "ROYAUME"]
        if countryKeywords.contains(where: { allText.contains($0) }) { score += 1 }

        // Document type identifiers
        let docTypeKeywords = [
            "CARTE D'IDENTITE", "CARTE D IDENTITE", "IDENTITEITSKAART",
            "PERSONALAUSWEIS", "IDENTITY CARD"
        ]
        if docTypeKeywords.contains(where: { allText.contains($0) }) { score += 1 }

        // Field labels found on Belgian eID
        let fieldLabels = [
            "NOM", "NAAM", "NAME",
            "PRENOM", "VOORNAAM", "GIVEN",
            "NATIONALITE", "NATIONALITEIT", "NATIONALITY",
            "DATE DE NAISSANCE", "GEBOORTEDATUM",
            "LIEU DE NAISSANCE", "GEBOORTEPLAATS",
            "SEXE", "GESLACHT",
            "SIGNATURE", "HANDTEKENING",
            "VALABLE", "GELDIG"
        ]
        let fieldMatchCount = fieldLabels.filter { allText.contains($0) }.count
        if fieldMatchCount >= 2 { score += 1 }
        if fieldMatchCount >= 4 { score += 1 }

        // Date patterns (DD.MM.YYYY or DD/MM/YYYY or DD-MM-YYYY)
        let datePattern = #"\d{2}[./\-]\d{2}[./\-]\d{4}"#
        if allText.range(of: datePattern, options: .regularExpression) != nil { score += 1 }

        // National register number pattern (YY.MM.DD-XXX.XX)
        let nrnPattern = #"\d{2}\.\d{2}\.\d{2}[-–]\d{3}\.\d{2}"#
        if allText.range(of: nrnPattern, options: .regularExpression) != nil { score += 1 }

        return score
    }

    private static func extractIdCardInfo(from texts: [String], allText: String) -> IdCardInfo {
        var info = IdCardInfo()
        info.recognizedTextSnippet = String(allText.prefix(200))

        if allText.contains("CARTE D") && allText.contains("IDENTITE") {
            info.documentType = "Carte d'identite"
        } else if allText.contains("IDENTITEITSKAART") {
            info.documentType = "Identiteitskaart"
        }

        if allText.contains("BELGE") || allText.contains("BELGISCH") {
            info.nationality = "Belgian"
        }

        for (index, text) in texts.enumerated() {
            let upper = text.uppercased()
            if upper.contains("NAISSANCE") || upper.contains("GEBOORTEDATUM") || upper.contains("BIRTH") {
                let datePattern = #"\d{2}[./\-]\d{2}[./\-]\d{4}"#
                if let range = upper.range(of: datePattern, options: .regularExpression) {
                    info.dateOfBirth = String(upper[range])
                } else if index + 1 < texts.count,
                          let range = texts[index + 1].range(of: datePattern, options: .regularExpression) {
                    info.dateOfBirth = String(texts[index + 1][range])
                }
            }
        }

        return info
    }
}

// MARK: - Registration

extension DependencyValues {
    var idCardScannerClient: IdCardScannerClient {
        get { self[IdCardScannerClient.self] }
        set { self[IdCardScannerClient.self] = newValue }
    }
}
