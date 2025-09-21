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
        @Shared(.userInfo) var userInfo
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
            case .confirmEditohouseButtonTapped:
                guard var wipCohouse = state.destination?.edit?.wipCohouse
                else { return .none}

                wipCohouse.users.removeAll { user in
                    user.surname.isEmpty && !user.isAdmin
                }

                state.$cohouse.withLock { $0 = wipCohouse } //TODO: Add firestore set cohouse
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
    @Bindable var store: StoreOf<CohouseDetailFeature>

    var body: some View {
            Form {
                Section("") {
                    Image("defaultColocBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))

                Section("") {
                    VStack(alignment: .leading) {
                        Text("Code : \(store.cohouse.code)")
                            .font(Font.system(size: 20, weight: .semibold))
                        Text("Share this code with your cohouse buddies")
                            .font(.footnote)
                    }
                }
                .foregroundStyle(.white)
                .listRowBackground(Color.CKRPurple)

                Section("LOCATION") {
                    LabeledContent("Address", value: store.cohouse.address.street)
                    LabeledContent("ZIP Code", value: store.cohouse.address.postalCode)
                    LabeledContent("City", value: store.cohouse.address.city)
                }

                Section("MEMBERS (\(store.cohouse.users.count))") {
                    ForEach(store.cohouse.users) { user in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.surname)
                                if user.isAdmin {
                                    Text("Admin")
                                        .foregroundStyle(.gray)
                                        .font(.footnote)
                                }
                            }
                            Spacer()
                            if user.userId == self.store.userInfo?.id.uuidString {
                                Text("Me")
                                    .foregroundStyle(.gray)
                            }
                        }
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
                        .navigationTitle("Edit cohouse")
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

#Preview {
    NavigationStack {
        CohouseDetailView(
            store: Store(
                initialState: CohouseDetailFeature.State(
                    cohouse: Shared(value: .mock)
                )
            ) {
                CohouseDetailFeature()
            }
        )
    }
}
