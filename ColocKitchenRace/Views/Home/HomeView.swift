//
//  HomeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import os
import SwiftUI
import UIKit

@Reducer
struct HomeFeature {

    @Reducer
    enum Path {
        case profile(UserProfileDetailFeature)
    }

    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        @Shared(.news) var news
        @Shared(.userInfo) var userInfo
        var coverImageData: Data?
        @Presents var registrationForm: CKRRegistrationFormFeature.State?

        var coverImage: UIImage? {
            coverImageData.flatMap { UIImage(data: $0) }
        }

        var isRegistrationOpen: Bool {
            ckrGame?.isRegistrationOpen ?? false
        }

        var isAlreadyRegistered: Bool {
            guard let game = ckrGame, let cohouse else { return false }
            return game.participantsID.contains(cohouse.id.uuidString)
        }
    }

    enum Action {
        case coverImageLoaded(Data?)
        case openRegisterForm
        case refresh
        case path(StackActionOf<Path>)
        case registrationForm(PresentationAction<CKRRegistrationFormFeature.Action>)
        case delegate(Delegate)

        enum Delegate: Equatable {
            case switchToCohouseButtonTapped
        }
    }

    @Dependency(\.ckrClient) var ckrClient
    @Dependency(\.cohouseClient) var cohouseClient
    @Dependency(\.newsClient) var newsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                case let .coverImageLoaded(data):
                    state.coverImageData = data
                    return .none
                case .openRegisterForm:
                    guard let cohouse = state.cohouse,
                          let game = state.ckrGame,
                          game.isRegistrationOpen,
                          !state.isAlreadyRegistered
                    else { return .none }

                    state.registrationForm = CKRRegistrationFormFeature.State(
                        cohouse: cohouse,
                        gameId: game.id.uuidString,
                        cohouseType: cohouse.cohouseType ?? .mixed
                    )
                    return .none
                case .refresh:
                    let coverImagePath = state.cohouse?.coverImagePath
                    return .run { [ckrClient, newsClient, cohouseClient] send in
                        let _ = try? await ckrClient.getLast()
                        let _ = try? await newsClient.getLast()
                        if let path = coverImagePath {
                            let data = try? await cohouseClient.loadCoverImage(path)
                            await send(.coverImageLoaded(data))
                        } else {
                            await send(.coverImageLoaded(nil))
                        }
                    }
                case .registrationForm(.presented(.delegate(.registrationSucceeded))):
                    state.registrationForm = nil
                    return .send(.refresh)
                case .registrationForm:
                    return .none
                case .path:
                    return .none
                case .delegate:
                    return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$registrationForm, action: \.registrationForm) {
            CKRRegistrationFormFeature()
        }
    }
}

extension HomeFeature.Path.State: Equatable {}

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(spacing: 15) {
                    Button {
                        store.send(.delegate(.switchToCohouseButtonTapped))
                    } label: {
                        CohouseTileView(name: store.cohouse?.name, coverImage: store.coverImage)
                    }

                    if store.ckrGame != nil, store.cohouse != nil {
                        Button {
                            store.send(.openRegisterForm)
                        } label: {
                            RegistrationTileView(
                                registrationDeadline: store.ckrGame?.registrationDeadline,
                                isRegistrationOpen: store.isRegistrationOpen,
                                isAlreadyRegistered: store.isAlreadyRegistered
                            )
                        }
                    }

                    CountdownTileView(
                        nextKitchenRace: self.store.ckrGame?.nextGameDate,
                        countdownStart: self.store.ckrGame?.startCKRCountdown
                    )

                    NewsTileView(allNews: self.store.$news)
                }
            }
            .refreshable {
                await store.send(.refresh).finish()
            }
            .task {
                await store.send(.refresh).finish()
            }
            .padding(.horizontal)
            .navigationTitle("Colocs Kitchen Race")
            .toolbar {
                NavigationLink(
                    state: HomeFeature.Path.State.profile(UserProfileDetailFeature.State())
                ) {
                    Image(systemName: "person.crop.circle.fill")
                }
            }
            .sheet(item: $store.scope(state: \.registrationForm, action: \.registrationForm)) { formStore in
                NavigationStack {
                    CKRRegistrationFormView(store: formStore)
                        .navigationTitle("CKR Registration")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    store.send(.registrationForm(.dismiss))
                                }
                            }
                        }
                }
            }
        } destination: { store in
            switch store.case {
                case let .profile(store):
                    UserProfileDetailView(store: store)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }

}
