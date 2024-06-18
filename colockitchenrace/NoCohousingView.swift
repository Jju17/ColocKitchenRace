//
//  NoCohousingView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/02/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NoCohouseFeature {

    @Reducer(state: .equatable)
    enum Destination {
      case create(CohousingFormFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var cohouseCode: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case confirmCreateCohouseButtonTapped
        case createCohouseButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case dismissCreateCohouseButtonTapped
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .confirmCreateCohouseButtonTapped:
                guard case let .some(.create(editState)) = state.destination
                else { return .none }
                var newCohouse = editState.cohousing
                let _ = try? self.cohouseClient.add(newCohouse)
                state.destination = nil
                return .none
            case .createCohouseButtonTapped:
                state.destination = .create(
                    CohousingFormFeature.State(cohousing: Cohouse(id: .init()))
                )
                return .none
            case .destination:
              return .none
            case .dismissCreateCohouseButtonTapped:
                state.destination = nil
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

}

struct NoCohousingView: View {
    @Perception.Bindable var store: StoreOf<NoCohouseFeature>
    @FocusState var codeIsFocused: Bool

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    HStack(spacing: 50) {
                        Text("Code")
                        TextField(text: $store.cohouseCode) {
                            Text("Code")
                        }
                        .focused($codeIsFocused)
                    }
                    Button("Join existing cohouse") {}
                }

                Section {
                    Button("Create new cohouse") {
                        store.send(.createCohouseButtonTapped)
                    }
                }
            }
            .navigationTitle("Cohouse")
            .onAppear {
                self.codeIsFocused = true
            }
            .sheet(
              item: $store.scope(state: \.destination?.create, action: \.destination.create)
            ) { createCohouseStore in
              NavigationStack {
                CohousingFormView(store: createCohouseStore)
                  .navigationTitle("New cohouse")
                  .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                      Button("Dismiss") {
                        store.send(.dismissCreateCohouseButtonTapped)
                      }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                      Button("Create") {
                          store.send(.confirmCreateCohouseButtonTapped)
                      }
                    }
                  }
              }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NoCohousingView(store: .init(initialState: NoCohouseFeature.State(), reducer: {
            NoCohouseFeature()
        }))
    }
}
