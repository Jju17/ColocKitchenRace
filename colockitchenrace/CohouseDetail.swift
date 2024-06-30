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
        case saveCohouseButtonTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .confirmEditohouseButtonTapped:
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
            case .saveCohouseButtonTapped:
                guard let cohouse = state.destination?.edit?.wipCohouse
                else { return .none}

//                state.cohouse = cohouse
                state.destination = nil
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
                Section("Contact person") {
                    HStack {
                        Text("\(store.cohouse.contactUser?.firstName ?? "")")
                        Spacer()
                        Text("\(store.cohouse.contactUser?.phoneNumber ?? "")")
                    }
                }

                Section("Localisation") {
                    Text(store.cohouse.address.street)
                    Text("\(store.cohouse.address.postalCode) \(store.cohouse.address.city)")
                }

                Section("Membres") {
                    ForEach(store.cohouse.users) { user in
                        Text(user.firstName)
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
                      Button("Edit") {
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
        CohouseDetailView(store: Store(initialState: CohouseDetailFeature.State(cohouse: Shared(.mock))) {
                CohouseDetailFeature()
            }
        )
    }
}
