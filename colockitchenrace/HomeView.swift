//
//  HomeView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 08/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct HomeFeature: Reducer {

    // MARK: - Reducer

    struct State: Equatable {
        @PresentationState var addCohousing: CohousingFormFeature.State?
        var currentUser: User?
        var cohousing: Cohousing?
    }

    enum Action {
        case addCohousing(PresentationAction<CohousingFormFeature.Action>)
        case addCohousingButtonTapped
        case cancelCohousingButtonTapped
        case saveCohousingButtonTapped
        case signInButtonTapped
        case userProfileButtonTapped
    }

    @Dependency(\.uuid) var uuid
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addCohousing:
                return .none
            case .addCohousingButtonTapped:
                state.addCohousing = CohousingFormFeature.State(cohousing: Cohousing(id: self.uuid()))
                return .none
            case .cancelCohousingButtonTapped:
                state.addCohousing = nil
                return .none
            case .saveCohousingButtonTapped:
                guard let cohousing = state.addCohousing?.cohousing
                else { return .none }
                state.cohousing = cohousing
                state.addCohousing = nil
                return .none
            case .signInButtonTapped:
                return .none
            case .userProfileButtonTapped:
                return .none
            }
        }
        .ifLet(\.$addCohousing, action: /Action.addCohousing) {
            CohousingFormFeature()
        }
    }
}

struct HomeView: View {

    // MARK: - Store

    let store: StoreOf<HomeFeature>

    // MARK: - States

    @State var nowDate: Date = Date()

    // MARK: - Private properties

    private let nextKitchenRace = Date.from(year: 2024, month: 03, day: 23, hour: 18)
    private var timer: Timer {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {_ in
            self.nowDate = Date()
        }
    }
    private var countDownComponents: DateComponents {
        return Date.countdownDateComponents(from: self.nowDate, to: self.nextKitchenRace)
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                if let cohousing = viewStore.cohousing {
                    NavigationLink(
                        state: AppFeature.Path.State.detail(CohousingDetailFeature.State(cohousing: cohousing))
                    ) {
                        ZStack {
                            Image("defaultColocBackground")
                                .resizable()
                                .scaledToFill()
                            Rectangle()
                                .foregroundColor(.clear)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom))
                            if let name = viewStore.cohousing?.name {
                                Text(name)
                                    .font(.system(size: 40))
                                    .fontWeight(.heavy)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 40))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .padding()
                    }
                } else {
                    Button {
                        viewStore.send(.addCohousingButtonTapped)
                    } label: {
                        ZStack {
                            Image("defaultColocBackground")
                                .resizable()
                                .scaledToFill()
                            Rectangle()
                                .foregroundColor(.clear)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom))
                            if let name = viewStore.cohousing?.name {
                                Text(name)
                                    .font(.system(size: 40))
                                    .fontWeight(.heavy)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 40))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 130)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .padding()
                    }
                }
                VStack(alignment: .leading) {
                    Text("Prochaine Kitchen Race")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 30))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 30)

                    Spacer()

                    VStack(alignment: .leading, spacing: 30) {
                        Text("Day \(self.countDownComponents.formattedDays)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Hour \(self.countDownComponents.formattedHours)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Minute \(self.countDownComponents.formattedMinutes)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Second \(self.countDownComponents.formattedSeconds)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.white)
                    .font(.system(size: 45))
                    .fontWeight(.heavy)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    .onAppear(perform: {
                        _ = self.timer
                    })

                    Spacer()

                    Button(action: {}) {
                        Label("Sign In", systemImage: "arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding()

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.green)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding()

            }
            .navigationTitle("Bienvenue")
            .toolbar {
                NavigationLink(
                    state: AppFeature.Path.State.userProfile(UserProfileFeature.State(user: .mockUser))
                ) {
                    Image(systemName: "person.crop.circle.fill")
                }
            }
            .sheet(
                store: self.store.scope(
                    state: \.$addCohousing,
                    action: { .addCohousing($0) }
                )
            ) { store in
                NavigationStack {
                    CohousingFormView(store: store)
                        .navigationTitle("New cohouse")
                        .toolbar {
                            ToolbarItem {
                                Button("Add") {
                                    viewStore.send(.saveCohousingButtonTapped)
                                }
                            }

                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    viewStore.send(.cancelCohousingButtonTapped)
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
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }

}
