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

        var coverImage: UIImage? {
            coverImageData.flatMap { UIImage(data: $0) }
        }
    }

    enum Action {
        case coverImageLoaded(Data?)
        case openRegisterLink
        case refresh
        case path(StackActionOf<Path>)
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
                case .openRegisterLink:
                    guard let cohouse = state.cohouse
                    else { return .none }
                    return .run { [ckrClient] _ in
                        let result = ckrClient.registerCohouse(cohouse: cohouse)
                        if case let .failure(error) = result {
                            Logger.ckrLog.log(level: .error, "Failed to register cohouse: \(error)")
                        }
                    }
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
                case .path:
                    return .none
                case .delegate:
                    return .none
            }
        }
        .forEach(\.path, action: \.path)
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

                    Button {
                        self.store.send(.openRegisterLink)
                    } label: {
                        CountdownTileView(
                        nextKitchenRace: self.store.ckrGame?.nextGameDate,
                        countdownStart: self.store.ckrGame?.startCKRCountdown
                    )
                    }
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
