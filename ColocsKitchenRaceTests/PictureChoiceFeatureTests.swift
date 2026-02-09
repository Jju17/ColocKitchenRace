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

    @Test("finishProcessing with data stores it")
    func finishProcessing_success() async {
        let store = TestStore(
            initialState: PictureChoiceFeature.State(isProcessing: true)
        ) {
            PictureChoiceFeature()
        }

        let sampleData = Data([0xFF, 0xD8, 0xFF]) // fake JPEG header
        await store.send(._finishProcessing(sampleData)) {
            $0.isProcessing = false
            $0.imageData = sampleData
            $0.error = nil
        }
    }

    @Test("finishProcessing nil shows compression error")
    func finishProcessing_failure() async {
        let store = TestStore(
            initialState: PictureChoiceFeature.State(isProcessing: true)
        ) {
            PictureChoiceFeature()
        }

        await store.send(._finishProcessing(nil)) {
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
}
