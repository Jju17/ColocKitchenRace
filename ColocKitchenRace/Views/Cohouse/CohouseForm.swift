//
//  CohouseFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import os
import SwiftUI

@Reducer
struct CohouseFormFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
        var wipCohouse: Cohouse
        var isNewCohouse: Bool = false
        var originalAddress: PostalAddress?
        var addressValidationResult: AddressValidationResult?
        var isValidatingAddress: Bool = false
        var creationError: String?

        // ID card
        var idCardImageData: Data?
        var isIdCardPickerPresented: Bool = false
        var isProcessingIdCard: Bool = false

        /// Whether the address has been modified from the original (relevant for edit mode).
        var hasAddressChanged: Bool {
            guard let original = originalAddress else { return true }
            return wipCohouse.address != original
        }
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case assignAdmin(userId: CohouseUser.ID)
        case binding(BindingAction<State>)
        case deleteUsers(atOffset: IndexSet)
        case quitCohouseButtonTapped
        case addressValidationResponse(TaskResult<AddressValidationResult>)
        case applySuggestedAddress(ValidatedAddress)

        // ID card
        case idCardPickTapped
        case idCardPicked(Data)
        case idCardCleared
    }

    private enum CancelID { case addressValidation }

    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.addressValidatorClient) var addressValidatorClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
                case .addUserButtonTapped:
                    state.wipCohouse.users.append(CohouseUser(id: uuid()))
                    return .none
                case let .assignAdmin(userId):
                    for index in state.wipCohouse.users.indices {
                        state.wipCohouse.users[index].isAdmin = (state.wipCohouse.users[index].id == userId)
                    }
                    return .none
                case .binding:
                    state.creationError = nil

                    // Check if address fields changed → trigger auto-validation
                    let address = state.wipCohouse.address
                    let trimmedStreet = address.street.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedCity = address.city.trimmingCharacters(in: .whitespacesAndNewlines)

                    // If address is too short, just clear validation
                    guard trimmedStreet.count >= 5, trimmedCity.count >= 2 else {
                        state.addressValidationResult = nil
                        state.isValidatingAddress = false
                        return .cancel(id: CancelID.addressValidation)
                    }

                    // If address matches the one already validated, don't re-validate
                    if let result = state.addressValidationResult {
                        switch result {
                        case .valid(let v), .lowConfidence(let v):
                            if v.input == address { return .none }
                        default:
                            break
                        }
                    }

                    state.addressValidationResult = nil
                    state.isValidatingAddress = true

                    return .run { [address] send in
                        try await clock.sleep(for: .milliseconds(600))
                        await send(
                            .addressValidationResponse(
                                TaskResult {
                                    await addressValidatorClient.validate(address)
                                }
                            )
                        )
                    }
                    .cancellable(id: CancelID.addressValidation, cancelInFlight: true)

                case let .deleteUsers(atOffset: indices):
                    let nonAdminIndexes = indices.filter {
                        !state.wipCohouse.users[$0].isAdmin
                    }

                    for index in nonAdminIndexes.sorted(by: >) {
                        state.wipCohouse.users.remove(at: index)
                    }

                    if state.wipCohouse.users.isEmpty {
                        state.wipCohouse.users.append(CohouseUser(id: uuid(), isAdmin: true))
                    }
                    return .none
                case .quitCohouseButtonTapped:
                    return .run { _ in
                        try await self.cohouseClient.quitCohouse()
                    } catch: { error, _ in
                        Logger.cohouseLog.log(level: .error, "Failed to quit cohouse: \(error)")
                    }
                case let .addressValidationResponse(.success(result)):
                    state.isValidatingAddress = false
                    state.addressValidationResult = result
                    return .none
                case .addressValidationResponse(.failure):
                    state.isValidatingAddress = false
                    state.addressValidationResult = .notFound
                    return .none
                case .applySuggestedAddress(let validated):
                    let suggestion = PostalAddress(
                        street: validated.normalizedStreet ?? validated.input.street,
                        city: validated.normalizedCity ?? validated.input.city,
                        postalCode: validated.normalizedPostalCode ?? validated.input.postalCode,
                        country: validated.normalizedCountry ?? validated.input.country
                    )
                    state.wipCohouse.address = suggestion
                    state.addressValidationResult = nil
                    return .none

                // ID card
                case .idCardPickTapped:
                    state.isIdCardPickerPresented = true
                    return .none
                case let .idCardPicked(data):
                    state.idCardImageData = data
                    state.isIdCardPickerPresented = false
                    state.creationError = nil
                    return .none
                case .idCardCleared:
                    state.idCardImageData = nil
                    return .none
            }
        }
    }
}

struct CohouseFormView: View {
    @Bindable var store: StoreOf<CohouseFormFeature>

    var body: some View {
        Form {
            if let error = store.creationError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                TextField("Cohouse name", text: $store.wipCohouse.name)
            }

            Section("Location") {
                TextField(text: $store.wipCohouse.address.street) {
                    Text("Address")
                }
                TextField(text: $store.wipCohouse.address.postalCode) {
                    Text("Postcode")
                }
                TextField(text: $store.wipCohouse.address.city) {
                    Text("City")
                }

                self.addressValidationView
            }

            Section("Members") {
                ForEach($store.wipCohouse.users) { $user in
                    HStack {
                        TextField("Name", text: $user.surname)
                        if user.isAdmin {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.footnote)
                        }
                        if !store.isNewCohouse && isCurrentUserAdmin() && !user.isAdmin {
                            Button {
                                store.send(.assignAdmin(userId: user.id))
                            } label: {
                                Text("Make admin")
                                    .font(.caption)
                                    .foregroundStyle(Color.CKRPurple)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .onDelete { indices in
                    store.send(.deleteUsers(atOffset: indices))
                }

                Button("Add user") {
                    store.send(.addUserButtonTapped)
                }
            }

            if store.isNewCohouse {
                self.idCardSection
            }

            if !store.isNewCohouse && !self.isCurrentUserAdmin() {
                Section {
                    Button("Quit cohouse") {
                        store.send(.quitCohouseButtonTapped)
                    }
                    .foregroundStyle(.red)
                }
            }

        }
        .fullScreenCover(isPresented: $store.isIdCardPickerPresented) {
            ImagePicker(
                selected: { image in
                    if let data = ImagePipeline.jpegDataCompressed(from: image) {
                        store.send(.idCardPicked(data))
                    } else {
                        store.send(.idCardCleared)
                    }
                },
                cancelled: {
                    store.send(.binding(.set(\.isIdCardPickerPresented, false)))
                },
                source: .camera
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - ID Card section

    @ViewBuilder
    private var idCardSection: some View {
        Section("ID Card") {
            if let imageData = store.idCardImageData,
               let uiImage = UIImage(data: imageData) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)

                    Button(role: .destructive) {
                        store.send(.idCardCleared)
                    } label: {
                        Label("Remove photo", systemImage: "trash")
                            .font(.footnote)
                    }
                }
            } else {
                Button {
                    store.send(.idCardPickTapped)
                } label: {
                    Label("Take a photo of your ID card", systemImage: "camera")
                }
            }

            Text("Required to verify your identity when creating a cohouse.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Address validation subview

    @ViewBuilder
    private var addressValidationView: some View {
        if store.isValidatingAddress {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Validating address…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        if let result = store.addressValidationResult {
            switch result {
            case .invalidSyntax:
                Text("Invalid address (incorrect format).")
                    .font(.footnote)
                    .foregroundStyle(.red)

            case .notFound:
                Text("Address not found or not recognized.")
                    .font(.footnote)
                    .foregroundStyle(.orange)

            case .lowConfidence(let validated):
                VStack(alignment: .leading, spacing: 2) {
                    Text("Address found but uncertain:")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                    if let suggestion = formattedSuggestion(from: validated) {
                        Button {
                            store.send(.applySuggestedAddress(validated))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.magnifyingglass")
                                Text(suggestion)
                            }
                            .font(.footnote)
                        }
                    }
                }

            case .valid(let validated):
                VStack(alignment: .leading, spacing: 2) {
                    Text("Valid address ✅")
                        .font(.footnote)
                        .foregroundStyle(.green)
                    if let suggestion = formattedSuggestion(from: validated) {
                        Text(suggestion)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func formattedSuggestion(from validated: ValidatedAddress) -> String? {
        let street = validated.normalizedStreet ?? validated.input.street
        let city = validated.normalizedCity ?? validated.input.city
        let postalCode = validated.normalizedPostalCode ?? validated.input.postalCode
        let country = validated.normalizedCountry ?? validated.input.country

        let line1 = street
        let line2 = [postalCode, city]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let line3 = country

        let lines = [line1, line2, line3].filter { !$0.isEmpty }

        return lines.isEmpty ? nil : lines.joined(separator: ", ")
    }

    // MARK: - Helpers

    func isCurrentUserAdmin() -> Bool {
        let adminUser = store.wipCohouse.users.first { $0.isAdmin }?.userId
        let userInfo = store.userInfo?.id.uuidString
        return adminUser == userInfo
    }
}

#Preview {
    CohouseFormView(
        store: Store(
            initialState: CohouseFormFeature.State(
                wipCohouse: .mock,
                isNewCohouse: true
            )
        ) {
            CohouseFormFeature()
        }
    )
}
