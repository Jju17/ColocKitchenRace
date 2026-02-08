//
//  PictureChoiceFeatureTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Tests on 08/02/2026.
//

import ComposableArchitecture
import Testing
import UIKit

@testable import ColocsKitchenRace

@MainActor
struct PictureChoiceFeatureTests {

    // MARK: - Pick Flow

    @Test("pickTapped shows source sheet")
    func pickTapped() async {
        let store = TestStore(initialState: PictureChoiceFeature.State()) {
            PictureChoiceFeature()
        }

        await store.send(.pickTapped) {
            $0.sourceSheetPresented = true
        }
    }

    @Test("sourceChosen sets source and opens picker")
    func sourceChosen_camera() async {
        let store = TestStore(
            initialState: PictureChoiceFeature.State(sourceSheetPresented: true)
        ) {
            PictureChoiceFeature()
        }

        await store.send(.sourceChosen(.camera)) {
            $0.sourceSheetPresented = false
            $0.source = .camera
            $0.isImagePickerPresented = true
            $0.error = nil
        }
    }

    @Test("sourceChosen library opens photo library")
    func sourceChosen_library() async {
        let store = TestStore(
            initialState: PictureChoiceFeature.State(sourceSheetPresented: true)
        ) {
            PictureChoiceFeature()
        }

        await store.send(.sourceChosen(.library)) {
            $0.sourceSheetPresented = false
            $0.source = .library
            $0.isImagePickerPresented = true
            $0.error = nil
        }
    }

    // MARK: - Image Processing

//    @Test("imagePicked compresses and stores data")
//    func imagePicked_success() async {
//        // Create a small test image
//        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
//        let testImage = renderer.image { ctx in
//            UIColor.red.setFill()
//            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
//        }
//
//        let store = TestStore(initialState: PictureChoiceFeature.State()) {
//            PictureChoiceFeature()
//        }
//
//        await store.send(.imagePicked(testImage)) {
//            $0.isProcessing = true
//            $0.error = nil
//        }
//
//        await store.receive(\._finishProcessing.success) {
//            $0.isProcessing = false
//            // imageData should be set to compressed JPEG data
//            #expect($0.imageData != nil)
//            #expect($0.imageData!.count < PictureChoiceFeature.maxBytes)
//            $0.error = nil
//        }
//    }

    @Test("imagePicked with too large image shows error")
    func imagePicked_tooLarge() async {
        // Create a very large image that exceeds 3MB after compression
        // This is hard to do with a small renderer, so we test the error path directly
        let store = TestStore(initialState: PictureChoiceFeature.State()) {
            PictureChoiceFeature()
        }

        let largeBytes = PictureChoiceFeature.maxBytes + 1000
        await store.send(._finishProcessing(.failure(.tooLarge(largeBytes)))) {
            $0.isProcessing = false
            $0.imageData = nil
            $0.error = "Image is too large (\(ImagePipeline.humanSize(largeBytes))). Limit: \(ImagePipeline.humanSize(PictureChoiceFeature.maxBytes))."
        }
    }

    @Test("Compression failure shows error")
    func compressionFailed() async {
        let store = TestStore(initialState: PictureChoiceFeature.State()) {
            PictureChoiceFeature()
        }

        await store.send(._finishProcessing(.failure(.compressFailed))) {
            $0.isProcessing = false
            $0.imageData = nil
            $0.error = "Unable to compress the image. Please try again."
        }
    }

    // MARK: - Image Clear

    @Test("imageCleared resets state")
    func imageCleared() async {
        let store = TestStore(
            initialState: PictureChoiceFeature.State(
                imageData: Data([0xFF]),
                error: "Some error"
            )
        ) {
            PictureChoiceFeature()
        }

        await store.send(.imageCleared) {
            $0.imageData = nil
            $0.error = nil
        }
    }

    // MARK: - Unknown Error

    @Test("Unknown error shows generic message")
    func unknownError() async {
        let store = TestStore(initialState: PictureChoiceFeature.State()) {
            PictureChoiceFeature()
        }

        await store.send(._finishProcessing(.failure(.unknown))) {
            $0.isProcessing = false
            $0.imageData = nil
            $0.error = "Unknown error."
        }
    }
}
