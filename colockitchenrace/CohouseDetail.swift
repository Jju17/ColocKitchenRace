//
//  CohouseDetailView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohouseDetailFeature {

    @Reducer
    enum Destination {
        case edit(CohouseFormFeature)
    }

    @ObservableState
    struct State {
        @Shared var cohouse: Cohouse
        @Presents var destination: Destination.State?
    }

    enum Action {
        case confirmEditohouseButtonTapped
        case dismissEditCohouseButtonTapped
        case editButtonTapped
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .confirmEditohouseButtonTapped: //TODO: Add edit cohouse client
                guard let cohouse = state.destination?.edit?.wipCohouse
                else { return .none}
                state.cohouse = cohouse
                state.destination = nil
                return .none
            case .dismissEditCohouseButtonTapped:
                state.destination = nil
                return .none
            case .destination:
                return .none
            case .editButtonTapped:
                state.destination = .edit(
                    CohouseFormFeature.State(wipCohouse: state.cohouse)
                )
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

struct CohouseDetailView: View {
    @Perception.Bindable var store: StoreOf<CohouseDetailFeature>

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section("") {
                    Image("defaultColocBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                Section("") {
                    HStack {
                        Text("Code : \(store.cohouse.joinCohouseId)")
                            .foregroundStyle(.white)
                        Spacer()
                        Button {

                        } label: {
                            Image(systemName: "info.circle")
                                .tint(.white)
                        }
                    }
                }
                .font(Font.system(size: 20, weight: .semibold))
                .listRowBackground(Color.CKRPurple)

                Section("LOCATION") {
                    LabeledContent("Address", value: store.cohouse.address.street)
                    LabeledContent("ZIP Code", value: store.cohouse.address.postalCode)
                    LabeledContent("City", value: store.cohouse.address.city)
                }

                Section("MEMBERS") {
                    ForEach(store.cohouse.users) { user in
                        Text(user.surname)
                    }
                }
            }
            .navigationBarTitle(store.cohouse.name)
            .toolbar {
                Button("Edit") {
                    store.send(.editButtonTapped)
                }
            }
            .sheet(
                item: $store.scope(state: \.destination?.edit, action: \.destination.edit)
            ) { editCohouseStore in
                NavigationStack {
                    CohouseFormView(store: editCohouseStore)
                        .navigationTitle("New cohouse")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Dismiss") {
                                    store.send(.dismissEditCohouseButtonTapped)
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Confirm") {
                                    store.send(.confirmEditohouseButtonTapped)
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
        CohouseDetailView(
            store: Store(
                initialState: CohouseDetailFeature.State(
                    cohouse: Shared(.mock)
                )
            ) {
                CohouseDetailFeature()
            }
        )
    }
}
