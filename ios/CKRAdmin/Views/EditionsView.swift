//
//  EditionsView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 21/03/2026.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Reducer

@Reducer
struct EditionsFeature {

    @ObservableState
    struct State: Equatable {
        @Presents var createEditionForm: CreateEditionFormFeature.State?
        var editions: [CKRGame] = []
        var isLoading: Bool = false
        var error: String?
        var publishedJoinCode: String?
        var showPublishConfirmGameId: String?
    }

    enum Action {
        case onAppear
        case editionsLoaded(Result<[CKRGame], CKRError>)
        case createEditionButtonTapped
        case confirmCreateEdition
        case editionCreated(Result<(gameId: String, joinCode: String), CKRError>)
        case publishButtonTapped(String) // gameId
        case confirmPublishEdition
        case cancelPublish
        case editionPublished(Result<String, CKRError>) // joinCode
        case createEditionForm(PresentationAction<CreateEditionFormFeature.Action>)
        case dismissCreateForm
    }

    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let result = await ckrClient.getMyEditions()
                    await send(.editionsLoaded(result))
                }

            case let .editionsLoaded(.success(editions)):
                state.isLoading = false
                state.editions = editions
                return .none

            case let .editionsLoaded(.failure(error)):
                state.isLoading = false
                state.error = "Failed to load editions: \(error)"
                return .none

            case .createEditionButtonTapped:
                state.createEditionForm = CreateEditionFormFeature.State()
                return .none

            case .confirmCreateEdition:
                guard let formState = state.createEditionForm else { return .none }
                let title = formState.title
                let maxParticipants = formState.maxParticipants
                let pricePerPersonCents = formState.pricePerPersonCents
                state.createEditionForm = nil
                state.isLoading = true

                return .run { send in
                    let result = await ckrClient.createSpecialEdition(title, maxParticipants, pricePerPersonCents)
                    await send(.editionCreated(result))
                }

            case let .editionCreated(.success((_, joinCode))):
                state.isLoading = false
                state.publishedJoinCode = joinCode
                return .run { send in
                    let result = await ckrClient.getMyEditions()
                    await send(.editionsLoaded(result))
                }

            case let .editionCreated(.failure(error)):
                state.isLoading = false
                state.error = "Failed to create edition: \(error)"
                return .none

            case let .publishButtonTapped(gameId):
                state.showPublishConfirmGameId = gameId
                return .none

            case .confirmPublishEdition:
                guard let gameId = state.showPublishConfirmGameId else { return .none }
                state.showPublishConfirmGameId = nil
                state.isLoading = true
                return .run { send in
                    let result = await ckrClient.publishEdition(gameId)
                    await send(.editionPublished(result))
                }

            case .cancelPublish:
                state.showPublishConfirmGameId = nil
                return .none

            case let .editionPublished(.success(joinCode)):
                state.isLoading = false
                state.publishedJoinCode = joinCode
                return .run { send in
                    let result = await ckrClient.getMyEditions()
                    await send(.editionsLoaded(result))
                }

            case let .editionPublished(.failure(error)):
                state.isLoading = false
                state.error = "Failed to publish: \(error)"
                return .none

            case .dismissCreateForm:
                state.createEditionForm = nil
                return .none
            case .createEditionForm:
                return .none
            }
        }
        .ifLet(\.$createEditionForm, action: \.createEditionForm) {
            CreateEditionFormFeature()
        }
    }
}

// MARK: - Create Edition Form

@Reducer
struct CreateEditionFormFeature {
    @ObservableState
    struct State: Equatable {
        var title: String = ""
        var maxParticipants: Int = 100
        var pricePerPersonCents: Int = 500

        var isValid: Bool {
            !title.trimmingCharacters(in: .whitespaces).isEmpty
            && maxParticipants > 0
            && pricePerPersonCents >= 0
        }

        var priceInEuros: Double {
            get { Double(pricePerPersonCents) / 100.0 }
            set { pricePerPersonCents = Int((newValue * 100).rounded()) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

// MARK: - View

struct EditionsView: View {
    @Bindable var store: StoreOf<EditionsFeature>

    var body: some View {
        List {
            // Create button
            Section {
                Button {
                    store.send(.createEditionButtonTapped)
                } label: {
                    Label("Create Special Edition", systemImage: "plus.circle.fill")
                }
            }

            // Published join code banner
            if let code = store.publishedJoinCode {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.ckrCoral)
                        Text("Share this code with participants")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Error
            if let error = store.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            // Editions list
            if store.isLoading {
                Section {
                    ProgressView("Loading editions...")
                }
            } else if store.editions.isEmpty {
                Section {
                    Text("No special editions yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("My Editions") {
                    ForEach(store.editions, id: \.id) { edition in
                        EditionRow(
                            edition: edition,
                            onPublish: {
                                store.send(.publishButtonTapped(edition.id.uuidString))
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Editions")
        .task { store.send(.onAppear) }
        .sheet(
            item: $store.scope(
                state: \.createEditionForm,
                action: \.createEditionForm
            )
        ) { formStore in
            NavigationStack {
                CreateEditionFormView(store: formStore)
                    .navigationTitle("New Edition")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { store.send(.dismissCreateForm) }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") { store.send(.confirmCreateEdition) }
                                .disabled(!formStore.isValid)
                        }
                    }
            }
        }
        .alert(
            "Publish Edition",
            isPresented: Binding(
                get: { store.showPublishConfirmGameId != nil },
                set: { if !$0 { store.send(.cancelPublish) } }
            )
        ) {
            Button("Publish", role: .destructive) { store.send(.confirmPublishEdition) }
            Button("Cancel", role: .cancel) { store.send(.cancelPublish) }
        } message: {
            Text("Once published, users can join with the code. Are you sure?")
        }
    }
}

// MARK: - Edition Row

private struct EditionRow: View {
    let edition: CKRGame
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(edition.title ?? "Untitled")
                    .font(.headline)
                Spacer()
                StatusBadge(status: edition.status)
            }

            if let code = edition.joinCode {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }
            }

            HStack {
                Image(systemName: "person.2")
                Text("\(edition.totalRegisteredParticipants)/\(edition.maxParticipants)")
                Spacer()
                Text(edition.formattedPricePerPerson)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if edition.status == .draft {
                Button("Publish", action: onPublish)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ckrCoral)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: CKRGameStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .draft: .orange
        case .published: .green
        case .archived: .gray
        }
    }
}

// MARK: - Create Form View

struct CreateEditionFormView: View {
    @Bindable var store: StoreOf<CreateEditionFormFeature>

    var body: some View {
        Form {
            Section("Edition Info") {
                TextField("Title", text: $store.title)
            }

            Section("Capacity") {
                Stepper("Max participants: \(store.maxParticipants)", value: $store.maxParticipants, in: 4...1000, step: 4)
            }

            Section("Pricing") {
                HStack {
                    Text("Price per person")
                    Spacer()
                    TextField("Price", value: $store.priceInEuros, format: .currency(code: "EUR"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditionsView(
            store: Store(initialState: EditionsFeature.State()) {
                EditionsFeature()
            }
        )
    }
}
