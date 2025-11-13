//
//  CohouseFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import FirebaseAuth
import SwiftUI

@Reducer
struct CohouseFormFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.userInfo) var userInfo
        var wipCohouse: Cohouse
        var isNewCohouse: Bool = false
        var addressValidationResult: AddressValidationResult?
        var isValidatingAddress: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case addUserButtonTapped
        case assignAdminButtonTapped
        case binding(BindingAction<State>)
        case deleteUsers(atOffset: IndexSet)
        case quitCohouseButtonTapped
        case validateAddressButtonTapped
        case addressValidationResponse(TaskResult<AddressValidationResult>)
        case applySuggestedAddress(ValidatedAddress)
    }

    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.addressValidatorClient) var addressValidatorClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce {
            state,
            action in
            switch action {
                case .addUserButtonTapped:
                    state.wipCohouse.users.append(CohouseUser(id: UUID()))
                    return .none
                case .assignAdminButtonTapped:
                    return .none
                case .binding:
                    state.addressValidationResult = nil
                    return .none
                case let .deleteUsers(atOffset: indices):
                    let nonAdminIndexes = indices.filter {
                        !state.wipCohouse.users[$0].isAdmin
                    }
                    
                    for index in nonAdminIndexes.sorted(by: >) {
                        state.wipCohouse.users.remove(at: index)
                    }
                    
                    if state.wipCohouse.users.isEmpty {
                        state.wipCohouse.users.append(CohouseUser(id: UUID(), isAdmin: true))
                    }
                    return .none
                case .quitCohouseButtonTapped:
                    return .run { _ in
                        try await self.cohouseClient.quitCohouse()
                    }
                case .validateAddressButtonTapped:
                    state.isValidatingAddress = true
                    let address = state.wipCohouse.address
                    
                    return .run { [address, addressValidatorClient] send in
                        await send(
                            .addressValidationResponse(
                                TaskResult {
                                    await addressValidatorClient.validate(address)
                                }
                            )
                        )
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
            }
        }
    }
}

struct CohouseFormView: View {
    @Bindable var store: StoreOf<CohouseFormFeature>

    var body: some View {
        Form {
            Section {
                TextField("Cohouse name", text: $store.wipCohouse.name)
            }

            Section("Localisation") {
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

            Section("Membres") {
                ForEach($store.wipCohouse.users) { $user in
                    TextField("Name", text: $user.surname)
                }
                .onDelete { indices in
                    store.send(.deleteUsers(atOffset: indices))
                }

                Button("Add user") {
                    store.send(.addUserButtonTapped)
                }
            }

            if !store.isNewCohouse && !self.isActualUserIsAdmin() {
                Section {
                    Button("Quit cohouse") {
                        store.send(.quitCohouseButtonTapped)
                    }
                    .foregroundStyle(.red)
                }
            }

            //TODO: Handle admin swap
//            if !store.isNewCohouse && self.isActualUserIsAdmin() {
//                Section {
//                    Button("Assign another admin") {
//                        store.send(.assignAdminButtonTapped)
//                    }
//                    .foregroundStyle(.red)
//                }
//            }
        }
    }

    // MARK: - Address validation subview

    @ViewBuilder
    private var addressValidationView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button("Validate address") {
                    store.send(.validateAddressButtonTapped)
                }

                if store.isValidatingAddress {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if let result = store.addressValidationResult {
                switch result {
                case .invalidSyntax:
                    Text("Adresse invalide (format incorrect).")
                        .font(.footnote)
                        .foregroundStyle(.red)

                case .notFound:
                    Text("Adresse introuvable ou non reconnue.")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                case .lowConfidence(let validated):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adresse trouvée mais incertaine :")
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
                        Text("Adresse valide ✅")
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

    func isActualUserIsAdmin() -> Bool {
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

#Preview {
    CohouseFormView(
        store: Store(initialState: CohouseFormFeature.State(wipCohouse: .mock, isNewCohouse: true)) {
            CohouseFormFeature()
        })
}
