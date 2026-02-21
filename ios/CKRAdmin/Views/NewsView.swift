//
//  NewsView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 31/01/2026.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NewsFeature {

    @Reducer
    enum Destination {
        case addNews(NewsFormFeature)
        case editNews(NewsFormFeature)
        case deleteAlert(AlertState<Action.Alert>)

        @CasePathable
        enum Action {
            case addNews(NewsFormFeature.Action)
            case editNews(NewsFormFeature.Action)
            case deleteAlert(Alert)

            enum Alert: Equatable {
                case confirmDelete(String)
            }
        }
    }

    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
        var news: [News] = []
        var isLoading: Bool = false
        var error: String?
        var newsToDelete: String?
    }

    enum Action {
        case onTask
        case newsLoaded([News])
        case loadingFailed(String)
        case addNewsButtonTapped
        case editNewsTapped(News)
        case deleteNewsTapped(String)
        case destination(PresentationAction<Destination.Action>)
        case dismissDestination
        case confirmAddNews
        case confirmEditNews
        case newsAdded(News)
        case newsDeleted(String)
        case newsUpdated
    }

    @Dependency(\.newsClient) var newsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                state.isLoading = true
                return .run { send in
                    do {
                        let news = try await newsClient.getAll()
                        await send(.newsLoaded(news))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case let .newsLoaded(news):
                state.isLoading = false
                state.news = news
                return .none

            case let .loadingFailed(error):
                state.isLoading = false
                state.error = error
                return .none

            case .addNewsButtonTapped:
                state.destination = .addNews(NewsFormFeature.State())
                return .none

            case let .editNewsTapped(news):
                state.destination = .editNews(NewsFormFeature.State(
                    title: news.title,
                    body: news.body,
                    existingNews: news
                ))
                return .none

            case let .deleteNewsTapped(newsId):
                state.newsToDelete = newsId
                state.destination = .deleteAlert(
                    AlertState {
                        TextState("Delete this news?")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmDelete(newsId)) {
                            TextState("Delete")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("This action is irreversible.")
                    }
                )
                return .none

            case .destination(.presented(.deleteAlert(.confirmDelete(let newsId)))):
                state.destination = nil
                return .run { send in
                    do {
                        try await newsClient.delete(newsId)
                        await send(.newsDeleted(newsId))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case let .newsDeleted(newsId):
                state.news.removeAll { $0.id == newsId }
                return .none

            case .dismissDestination:
                state.destination = nil
                return .none

            case .confirmAddNews:
                guard case let .some(.addNews(formState)) = state.destination else {
                    return .none
                }

                let title = formState.title
                let body = formState.body
                state.destination = nil

                return .run { send in
                    do {
                        let news = try await newsClient.add(title, body)
                        await send(.newsAdded(news))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case let .newsAdded(news):
                state.news.insert(news, at: 0)
                return .none

            case .confirmEditNews:
                guard case let .some(.editNews(formState)) = state.destination,
                      let existingNews = formState.existingNews else {
                    return .none
                }

                var updatedNews = existingNews
                updatedNews.title = formState.title
                updatedNews.body = formState.body
                state.destination = nil

                return .run { [updatedNews] send in
                    do {
                        try await newsClient.update(updatedNews)
                        await send(.newsUpdated)
                        // Reload to get fresh data
                        let news = try await newsClient.getAll()
                        await send(.newsLoaded(news))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case .newsUpdated:
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

// MARK: - News Form Feature

@Reducer
struct NewsFormFeature {
    @ObservableState
    struct State: Equatable {
        var title: String = ""
        var body: String = ""
        var existingNews: News? = nil

        var isValid: Bool {
            !title.isEmpty && !body.isEmpty
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

// MARK: - Views

struct NewsView: View {
    @Bindable var store: StoreOf<NewsFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.news.isEmpty {
                    ProgressView("Loading...")
                } else if store.news.isEmpty {
                    ContentUnavailableView(
                        "No news",
                        systemImage: "newspaper",
                        description: Text("Tap + to create a news")
                    )
                } else {
                    List {
                        ForEach(store.news) { news in
                            NewsRowView(news: news)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.editNewsTapped(news))
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.send(.deleteNewsTapped(news.id))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("News")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addNewsButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                store.send(.onTask)
            }
        }
        .alert(
            $store.scope(
                state: \.destination?.deleteAlert,
                action: \.destination.deleteAlert
            )
        )
        .sheet(
            item: $store.scope(state: \.destination?.addNews, action: \.destination.addNews)
        ) { formStore in
            NavigationStack {
                NewsFormView(store: formStore)
                    .navigationTitle("New News")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                store.send(.dismissDestination)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                store.send(.confirmAddNews)
                            }
                            .disabled(!formStore.isValid)
                        }
                    }
            }
        }
        .sheet(
            item: $store.scope(state: \.destination?.editNews, action: \.destination.editNews)
        ) { formStore in
            NavigationStack {
                NewsFormView(store: formStore)
                    .navigationTitle("Edit News")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                store.send(.dismissDestination)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.confirmEditNews)
                            }
                            .disabled(!formStore.isValid)
                        }
                    }
            }
        }
        .task {
            store.send(.onTask)
        }
    }
}

struct NewsRowView: View {
    let news: News

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(news.title)
                .font(.headline)
            Text(news.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(news.publicationDate, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct NewsFormView: View {
    @Bindable var store: StoreOf<NewsFormFeature>

    var body: some View {
        Form {
            Section(header: Text("Content")) {
                TextField("Title", text: $store.title)
                TextField("Message", text: $store.body, axis: .vertical)
                    .lineLimit(5...10)
            }
        }
    }
}

#Preview {
    NewsView(
        store: Store(initialState: NewsFeature.State()) {
            NewsFeature()
        }
    )
}
