//
//  CohousingDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohousingDetailFeature {

    @ObservableState
    struct State: Equatable {
        @Presents var editCohousing: CohousingFormFeature.State?
        var cohousing: Cohouse
    }

    enum Action: Equatable {
        case cancelCohousingButtonTapped
        case delegate(Delegate)
        case editButtonTapped
        case editCohousing(PresentationAction<CohousingFormFeature.Action>)
        case saveCohousingButtonTapped
        enum Delegate: Equatable {
            case cohousingUpdated(Cohouse)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .cancelCohousingButtonTapped:
                state.editCohousing = nil
                return .none
            case .delegate:
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
//        .ifLet(\.$editCohousing , action: /Action.editCohousing) {
//            CohousingFormFeature()
//        }
//        .onChange(of: \.cohousing) { oldValue, newValue in
//            Reduce { state, action in
//                .send(.delegate(.cohousingUpdated(newValue)))
//            }
//        }
    }
}

struct CohousingDetailView: View {
    @Perception.Bindable var store: StoreOf<CohousingDetailFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("Contact person") {
                    HStack {
                        Text("\(store.cohousing.contactUser?.firstName ?? "")")
                        Spacer()
                        Text("\(store.cohousing.contactUser?.phoneNumber ?? "")")
                    }
                }

                Section("Localisation") {
                    Text(store.cohousing.address.street)
                    Text("\(store.cohousing.address.postalCode) \(store.cohousing.address.city)")
                }

                Section("Membres") {
                    ForEach(store.cohousing.users) { user in
                        Text(user.firstName)
                    }
                }
            }
            .navigationBarTitle(store.cohousing.name)
            .toolbar {
                Button("Edit") {
                    store.send(.editButtonTapped)
                }
            }
//                .sheet(
//                    item: $store.scope(
//                        state: \.editCohousing,
//                        action: \.editCohousing
//                    )
//                ) { store in
//                    NavigationStack {
//                        CohousingFormView(store: store)
//                            .navigationTitle("Edit Cohousing")
//                            .toolbar {
//                                ToolbarItem {
//                                    Button("Save") {
//                                        store.send(.saveCohousingButtonTapped)
//                                    }
//                                }
//                                ToolbarItem(placement: .cancellationAction) {
//                                    Button("Cancel") {
//                                        store.send(.cancelCohousingButtonTapped)
//                                    }
//                                }
//                            }
//                    }
//                }
        }
    }
}

#Preview {
    NavigationStack {
        CohousingDetailView(store: Store(initialState: CohousingDetailFeature.State(cohousing: .mock)) {
                CohousingDetailFeature()
            }
        )
    }
}
