//
//  CohousingDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct CohousingDetailFeature: Reducer {

    // MARK: - Reducer

    struct State: Equatable {
        @PresentationState var editCohousing: CohousingFormFeature.State?
        var cohousing: Cohousing
    }

    enum Action {
        case cancelCohousingButtonTapped
        case editButtonTapped
        case editCohousing(PresentationAction<CohousingFormFeature.Action>)
        case saveCohousingButtonTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .cancelCohousingButtonTapped:
                state.editCohousing = nil
                return .none
            case .editButtonTapped:
                state.editCohousing = CohousingFormFeature.State(cohousing: state.cohousing)
                return .none
            case .editCohousing(_):
                return .none
            case .saveCohousingButtonTapped:
                guard let cohousing = state.editCohousing?.cohousing
                else { return .none}
                state.cohousing = cohousing
                state.editCohousing = nil
                return .none
            }
        }
        .ifLet(\.$editCohousing , action: /Action.editCohousing) {
            CohousingFormFeature()
        }
    }
}

struct CohousingDetailView: View {
    let store: StoreOf<CohousingDetailFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Form {
                Section("Personne de contact") {
                    HStack {
                        Text("\(viewStore.cohousing.contactUser?.displayName ?? "")")
                        Spacer()
                        Text("\(viewStore.cohousing.contactUser?.phoneNumber ?? "")")
                    }
                }

                Section("Localisation") {
                    Text(viewStore.cohousing.address)
                    Text("\(viewStore.cohousing.postCode) \(viewStore.cohousing.city)")
                }

                Section("Membres") {
                    ForEach(viewStore.cohousing.users) { user in
                        Text(user.displayName)
                    }
                }
            }
            .navigationBarTitle(viewStore.cohousing.name)
            .toolbar {
                Button("Edit") {
                    viewStore.send(.editButtonTapped)
                }
            }
            .sheet(
                store: self.store.scope(
                    state: \.$editCohousing,
                    action: { .editCohousing($0) }
                )
            ) { store in
                NavigationStack {
                    CohousingFormView(store: store)
                        .navigationTitle("Edit Cohousing")
                        .toolbar {
                            ToolbarItem {
                                Button("Save") {
                                    viewStore.send(.saveCohousingButtonTapped)
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    <#code#>
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
        CohousingDetailView(
            store: Store(initialState: CohousingDetailFeature.State(cohousing: .mock)) {
                CohousingDetailFeature()
            }
        )
    }
}
