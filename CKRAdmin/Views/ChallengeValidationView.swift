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
        var filterStatus: FilterStatus = .all
    }

    enum Action: BindableAction {
        case addAllMockChallengeResponses
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
                case .addAllMockChallengeResponses:
                    return .run { send in
                        let result = await challengeResponseClient.addAllMockChallengeResponses()
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
    @State private var selectedImagePath: String?

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
                                        Text("Submitted on: \(response.submissionDate, formatter: dateFormatter)")
                                            .font(.caption)
                                        Text("Status: \(statusLabel(for: response.status))")
                                            .font(.caption)
                                            .foregroundColor(statusColor(for: response.status))
                                        // Display response content
                                        switch response.content {
                                            case .picture(let path):
                                                StorageImage(path: path)
                                                    .onTapGesture {
                                                        selectedImagePath = path
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
                                        ValidationButton(
                                            label: "Validate",
                                            color: .green,
                                            isActive: response.status == .validated
                                        ) {
                                            store.send(.setResponseStatus(response.id, .validated))
                                        }
                                        
                                        .disabled(response.status == .validated)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel("Validate response \(response.id.uuidString)")
                                        ValidationButton(
                                            label: "Invalidate",
                                            color: .red,
                                            isActive: response.status == .invalidated
                                        ) {
                                            store.send(.setResponseStatus(response.id, .invalidated))
                                        }
                                        .disabled(response.status == .invalidated)
                                        .contentShape(Rectangle())
                                        .accessibilityLabel("Invalidate response \(response.id.uuidString)")
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                        }
                        .listStyle(.plain)
                    }
                    .fullScreenCover(item: $selectedImagePath) { path in
                        FullScreenImageView(imagePath: path)
                    }
                }
            }
            .navigationTitle("Challenge responses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        store.send(.addAllMockChallengeResponses)
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
            case .waiting: return "Waiting"
            case .validated: return "Validate"
            case .invalidated: return "Invalidate"
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

extension String: Identifiable {
    public var id: String { self }
}

#Preview {
    ChallengeValidationView(
        store: Store(initialState: ChallengeValidationFeature.State(responses: ChallengeResponse.mockList)) {
            ChallengeValidationFeature()
        }
    )
}
