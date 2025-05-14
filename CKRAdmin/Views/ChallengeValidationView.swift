//
//  ChallengeValidationView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 14/05/2025.
//

import ComposableArchitecture
import FirebaseFirestore
import SwiftUI

@Reducer
struct ChallengeValidationFeature {
    @ObservableState
    struct State {
        var responses: [ChallengeResponse] = []
        var isLoading: Bool = false
        var errorMessage: String?
        var filterStatus: FilterStatus = .waiting
    }

    enum Action: BindableAction {
        case addAllMockChallenges
        case binding(BindingAction<State>)
        case fetchResponses
        case responsesLoaded(Result<[ChallengeResponse], ChallengeResponseError>)
        case setResponseStatus(UUID, ChallengeResponseStatus)
        case setFilterStatus(FilterStatus)
    }

    enum FilterStatus: String, CaseIterable, Identifiable {
        case all = "All"
        case waiting = "Waiting"
        case processed = "Processed"
        var id: String { rawValue }
    }

    @Dependency(\.challengeResponseClient) var challengeResponseClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .addAllMockChallenges:
                    return .run { send in
                        let result = await challengeResponseClient.addAllMockChallenges()
                        switch result {
                            case .success:
                                let fetchResult = await challengeResponseClient.getAll()
                                await send(.responsesLoaded(fetchResult))
                            case .failure(let error):
                                await send(.responsesLoaded(.failure(error)))
                        }
                    }
                case .binding:
                    return .none
                case .fetchResponses:
                    state.isLoading = true
                    return .run { send in
                        let result = await self.challengeResponseClient.getAll()
                        await send(.responsesLoaded(result))
                    }
                case .responsesLoaded(.success(let responses)):
                    state.responses = responses
                    state.isLoading = false
                    state.errorMessage = nil
                    return .none
                case .responsesLoaded(.failure(let error)):
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                    return .none
                case .setResponseStatus(let responseId, let status):
                    return .run { [state] send in
                        let result = await self.challengeResponseClient.updateStatus(responseId, status)
                        switch result {
                            case .success:
                                var updatedResponses = state.responses
                                if let index = updatedResponses.firstIndex(where: { $0.id == responseId }) {
                                    updatedResponses[index].status = status
                                }
                                await send(.responsesLoaded(.success(updatedResponses)))
                            case .failure(let error):
                                await send(.responsesLoaded(.failure(error)))
                        }
                    }
                case .setFilterStatus(let filterStatus):
                    state.filterStatus = filterStatus
                    return .none
            }
        }
    }
}

struct ChallengeValidationView: View {
    @Bindable var store: StoreOf<ChallengeValidationFeature>

    var body: some View {
        NavigationView {
            Group {
                if store.isLoading {
                    ProgressView("Loading responses...")
                } else if let errorMessage = store.errorMessage {
                    Text("Error : \(errorMessage)")
                        .foregroundColor(.red)
                } else if store.responses.isEmpty {
                    Text("No challenge response at the moment")
                        .foregroundColor(.gray)
                } else {
                    VStack {
                        Picker("Filter responses", selection: $store.filterStatus) {
                            ForEach(ChallengeValidationFeature.FilterStatus.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.palette)
                        .padding(.horizontal)

                        List {
                            ForEach(filteredResponses) { response in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Challenge ID: \(response.challengeId.uuidString.prefix(8))")
                                            .font(.headline)
                                        Text("Cohouse: \(response.cohouseId)")
                                            .font(.subheadline)
                                        Text("Submitted on: \(response.submissionDate.dateValue(), formatter: dateFormatter)")
                                            .font(.caption)
                                        Text("Status: \(statusLabel(for: response.status))")
                                            .font(.caption)
                                            .foregroundColor(statusColor(for: response.status))
                                        // Display response content
                                        switch response.content {
                                            case .picture(let data):
                                                if let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(height: 100)
                                                        .cornerRadius(8)
                                                } else {
                                                    Text("Image not available")
                                                }
                                            case .multipleChoice(let indices):
                                                Text("Choice: \(indices.map { String($0 + 1) }.joined(separator: ", "))")
                                            case .singleAnswer(let answer):
                                                Text("Response: \(answer)")
                                            case .noChoice:
                                                Text("No specific response")
                                        }
                                    }
                                    Spacer()
                                    // Validation buttons
                                    VStack(spacing: 8) {
                                        Button(action: {
                                            store.send(.setResponseStatus(response.id, .validated))
                                        }) {
                                            Text("Validate")
                                                .foregroundColor(.green)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(response.status == .validated ? Color.green.opacity(0.2) : Color.clear)
                                                .cornerRadius(8)
                                        }
                                        .disabled(response.status == .validated)
                                        .accessibilityLabel("Valider la réponse \(response.id.uuidString)")
                                        Button(action: {
                                            store.send(.setResponseStatus(response.id, .invalidated))
                                        }) {
                                            Text("Invalidate")
                                                .foregroundColor(.red)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(response.status == .invalidated ? Color.red.opacity(0.2) : Color.clear)
                                                .cornerRadius(8)
                                        }
                                        .disabled(response.status == .invalidated)
                                        .accessibilityLabel("Invalidate response \(response.id.uuidString)")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Challenge responses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.send(.addAllMockChallenges)
                    }) {
                        Image(systemName: "plus.circle")
                            .accessibilityLabel("Add test responses")
                    }
                }
            }
            .onAppear {
                store.send(.fetchResponses)
            }
        }
    }

    private var filteredResponses: [ChallengeResponse] {
        switch store.filterStatus {
            case .all:
                return store.responses
            case .waiting:
                return store.responses.filter { $0.status == .waiting }
            case .processed:
                return store.responses.filter { $0.status == .validated || $0.status == .invalidated }
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "Europe/Paris") // CEST timezone
        return formatter
    }()

    private func statusLabel(for status: ChallengeResponseStatus) -> String {
        switch status {
            case .waiting: return "En attente"
            case .validated: return "Validé"
            case .invalidated: return "Invalidé"
        }
    }

    private func statusColor(for status: ChallengeResponseStatus) -> Color {
        switch status {
            case .waiting: return .orange
            case .validated: return .green
            case .invalidated: return .red
        }
    }
}

#Preview {
    ChallengeValidationView(
        store: Store(initialState: ChallengeValidationFeature.State(responses: ChallengeResponse.mockList)) {
            ChallengeValidationFeature()
        }
    )
}
