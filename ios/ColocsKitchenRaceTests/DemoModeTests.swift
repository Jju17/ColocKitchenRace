//
//  DemoModeTests.swift
//  ColocsKitchenRaceTests
//
//  Created by Julien Rahier on 13/02/2026.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ColocsKitchenRace

// MARK: - DemoMode Configuration Tests

struct DemoModeConfigTests {

    @Test("DemoMode.demoEmail is the Apple reviewer email")
    func demoEmail() {
        #expect(DemoMode.demoEmail == "test_apple@colocskitchenrace.be")
    }

    @Test("DemoMode.isActive is false when no user is signed in")
    func isActiveWithNoUser() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = nil }
        #expect(DemoMode.isActive == false)
    }

    @Test("DemoMode.isActive is false for a regular user")
    func isActiveWithRegularUser() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = User(id: UUID(), email: "regular@example.com") }
        #expect(DemoMode.isActive == false)
        // Cleanup
        $userInfo.withLock { $0 = nil }
    }

    @Test("DemoMode.isActive is true for the demo user")
    func isActiveWithDemoUser() {
        @Shared(.userInfo) var userInfo
        $userInfo.withLock { $0 = User(id: UUID(), email: DemoMode.demoEmail) }
        #expect(DemoMode.isActive == true)
        // Cleanup
        $userInfo.withLock { $0 = nil }
    }
}

// MARK: - Stable IDs Tests

struct DemoModeStableIDsTests {

    @Test("All demo UUIDs are valid and distinct")
    func stableIdsAreDistinct() {
        let ids: Set<UUID> = [
            DemoMode.demoCohouseId,
            DemoMode.demoUserId,
            DemoMode.demoGameId,
            DemoMode.challengeId1,
            DemoMode.challengeId2,
            DemoMode.challengeId3,
            DemoMode.challengeId4,
            DemoMode.challengeId5,
        ]
        #expect(ids.count == 8, "All 8 stable IDs should be unique")
    }
}

// MARK: - Demo Cohouse Tests

struct DemoCohouseTests {

    @Test("Demo cohouse has correct name and address")
    func cohouseBasicInfo() {
        let cohouse = DemoMode.demoCohouse
        #expect(cohouse.id == DemoMode.demoCohouseId)
        #expect(cohouse.name == "La Coloc du Soleil")
        #expect(cohouse.address.city == "Bruxelles")
        #expect(cohouse.address.postalCode == "1000")
        #expect(cohouse.cohouseType == .mixed)
    }

    @Test("Demo cohouse has 3 users with admin set correctly")
    func cohouseUsers() {
        let cohouse = DemoMode.demoCohouse
        #expect(cohouse.users.count == 3)

        // First user should be admin and linked to demoUserId
        let admin = cohouse.users.first!
        #expect(admin.isAdmin == true)
        #expect(admin.userId == DemoMode.demoUserId.uuidString)

        // Others should not be admin
        #expect(cohouse.users.dropFirst().allSatisfy { !$0.isAdmin })
    }
}

// MARK: - Demo CKRGame Tests

struct DemoCKRGameTests {

    @Test("Demo game is revealed and demo cohouse is not yet registered")
    func gameIsRevealedAndNotRegistered() {
        let game = DemoMode.demoCKRGame
        #expect(game.isRevealed == true)
        // Demo cohouse is NOT pre-registered so the Apple reviewer sees the registration flow
        #expect(!game.cohouseIDs.contains(DemoMode.demoCohouseId.uuidString))
        #expect(game.isRegistrationOpen, "Registration should be open so the reviewer can register")
    }

    @Test("Demo game has event settings")
    func gameHasEventSettings() {
        let game = DemoMode.demoCKRGame
        #expect(game.eventSettings != nil)
        #expect(game.eventSettings?.partyName == "CKR Party")
    }

    @Test("Demo game has group plannings")
    func gameHasGroupPlannings() {
        let game = DemoMode.demoCKRGame
        #expect(game.groupPlannings != nil)
        #expect(game.groupPlannings?.count == 1)
        #expect(game.groupPlannings?.first?.cohouseA == DemoMode.demoCohouseId.uuidString)
    }

    @Test("Demo game has matched groups")
    func gameHasMatchedGroups() {
        let game = DemoMode.demoCKRGame
        #expect(game.matchedGroups != nil)
        #expect(game.matchedGroups?.first?.cohouseIds.contains(DemoMode.demoCohouseId.uuidString) == true)
    }

    @Test("Demo game has future dates")
    func gameDatesAreInFuture() {
        let game = DemoMode.demoCKRGame
        let now = Date()
        #expect(game.nextGameDate > now)
        #expect(game.registrationDeadline > now)
    }
}

// MARK: - Demo Planning Tests

struct DemoPlanningTests {

    @Test("Demo planning has apero as visitor")
    func aperoIsVisitor() {
        let planning = DemoMode.demoPlanning
        #expect(planning.apero.role == .visitor)
        #expect(!planning.apero.cohouseName.isEmpty)
        #expect(!planning.apero.address.isEmpty)
    }

    @Test("Demo planning has diner as host")
    func dinerIsHost() {
        let planning = DemoMode.demoPlanning
        #expect(planning.diner.role == .host)
        #expect(!planning.diner.cohouseName.isEmpty)
    }

    @Test("Demo planning has party info")
    func partyInfoExists() {
        let planning = DemoMode.demoPlanning
        #expect(!planning.party.name.isEmpty)
        #expect(!planning.party.address.isEmpty)
    }

    @Test("Demo planning times are chronological")
    func planningTimesAreChronological() {
        let planning = DemoMode.demoPlanning
        #expect(planning.apero.startTime < planning.apero.endTime)
        #expect(planning.apero.endTime <= planning.diner.startTime)
        #expect(planning.diner.startTime < planning.diner.endTime)
        #expect(planning.diner.endTime <= planning.party.startTime)
        #expect(planning.party.startTime < planning.party.endTime)
    }
}

// MARK: - Demo News Tests

struct DemoNewsTests {

    @Test("Demo news has 3 articles")
    func newsCount() {
        #expect(DemoMode.demoNews.count == 3)
    }

    @Test("Each demo news has title and body")
    func newsHaveTitlesAndBodies() {
        for news in DemoMode.demoNews {
            #expect(!news.title.isEmpty)
            #expect(!news.body.isEmpty)
            #expect(!news.id.isEmpty)
        }
    }
}

// MARK: - Demo Challenges Tests

struct DemoChallengesTests {

    @Test("Demo challenges has 5 challenges")
    func challengeCount() {
        #expect(DemoMode.demoChallenges.count == 5)
    }

    @Test("Demo challenges have various states")
    func challengeStates() {
        let challenges = DemoMode.demoChallenges
        let states = Set(challenges.map(\.state))
        // Should have at least 2 different states (ongoing + done or notStarted)
        #expect(states.count >= 2)
    }

    @Test("Demo challenges have various content types")
    func challengeContentTypes() {
        let challenges = DemoMode.demoChallenges
        let hasPicture = challenges.contains { if case .picture = $0.content { return true } else { return false } }
        let hasMultipleChoice = challenges.contains { if case .multipleChoice = $0.content { return true } else { return false } }
        let hasSingleAnswer = challenges.contains { if case .singleAnswer = $0.content { return true } else { return false } }
        let hasNoChoice = challenges.contains { if case .noChoice = $0.content { return true } else { return false } }

        #expect(hasPicture)
        #expect(hasMultipleChoice)
        #expect(hasSingleAnswer)
        #expect(hasNoChoice)
    }

    @Test("Demo challenges use stable IDs")
    func challengeIds() {
        let ids = Set(DemoMode.demoChallenges.map(\.id))
        #expect(ids.contains(DemoMode.challengeId1))
        #expect(ids.contains(DemoMode.challengeId2))
        #expect(ids.contains(DemoMode.challengeId3))
        #expect(ids.contains(DemoMode.challengeId4))
        #expect(ids.contains(DemoMode.challengeId5))
    }
}

// MARK: - Demo Challenge Responses Tests

struct DemoChallengeResponsesTests {

    @Test("Demo responses has 3 responses")
    func responseCount() {
        #expect(DemoMode.demoChallengeResponses.count == 3)
    }

    @Test("Demo responses reference the demo cohouse")
    func responsesReferenceCohouse() {
        for response in DemoMode.demoChallengeResponses {
            #expect(response.cohouseId == DemoMode.demoCohouseId.uuidString)
            #expect(response.cohouseName == "La Coloc du Soleil")
        }
    }

    @Test("Demo responses reference existing challenge IDs")
    func responsesReferenceChallenges() {
        let challengeIds = Set(DemoMode.demoChallenges.map(\.id))
        for response in DemoMode.demoChallengeResponses {
            #expect(challengeIds.contains(response.challengeId),
                    "Response for '\(response.challengeTitle)' should reference an existing demo challenge")
        }
    }

    @Test("Demo responses have various statuses")
    func responseStatuses() {
        let statuses = Set(DemoMode.demoChallengeResponses.map(\.status))
        #expect(statuses.contains(.waiting))
        #expect(statuses.contains(.validated))
    }
}

// MARK: - Seed Shared State Tests

struct DemoModeSeedTests {

    @Test("seedSharedState populates all @Shared keys")
    func seedPopulatesAllKeys() {
        // Setup: create a demo user
        let demoUser = User(id: DemoMode.demoUserId, email: DemoMode.demoEmail)

        // Seed
        DemoMode.seedSharedState(for: demoUser)

        // Verify all @Shared are populated
        @Shared(.userInfo) var userInfo
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        @Shared(.news) var news
        @Shared(.challenges) var challenges

        #expect(userInfo != nil)
        #expect(userInfo?.email == DemoMode.demoEmail)
        #expect(userInfo?.cohouseId == DemoMode.demoCohouseId.uuidString)

        #expect(cohouse != nil)
        #expect(cohouse?.name == "La Coloc du Soleil")

        #expect(ckrGame != nil)
        #expect(ckrGame?.isRevealed == true)

        #expect(news.count == 3)
        #expect(challenges.count == 5)

        // Cleanup
        $userInfo.withLock { $0 = nil }
        $cohouse.withLock { $0 = nil }
        $ckrGame.withLock { $0 = nil }
        $news.withLock { $0 = [] }
        $challenges.withLock { $0 = [] }
    }

    @Test("seedSharedState sets cohouseId on the user")
    func seedSetsCohouseId() {
        // User without a cohouseId
        let user = User(id: UUID(), email: DemoMode.demoEmail)
        #expect(user.cohouseId == nil)

        DemoMode.seedSharedState(for: user)

        @Shared(.userInfo) var userInfo
        #expect(userInfo?.cohouseId == DemoMode.demoCohouseId.uuidString)

        // Cleanup
        $userInfo.withLock { $0 = nil }
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        @Shared(.news) var news
        @Shared(.challenges) var challenges
        $cohouse.withLock { $0 = nil }
        $ckrGame.withLock { $0 = nil }
        $news.withLock { $0 = [] }
        $challenges.withLock { $0 = [] }
    }
}

// MARK: - Planning Tab Visibility Integration Tests

struct DemoModePlanningVisibilityTests {

    @Test("Planning tab is visible after demo user registers")
    func planningTabVisibleAfterRegistration() {
        // Seed demo data
        let demoUser = User(id: DemoMode.demoUserId, email: DemoMode.demoEmail)
        DemoMode.seedSharedState(for: demoUser)

        @Shared(.ckrGame) var ckrGame
        @Shared(.cohouse) var cohouse

        let isRevealed = ckrGame?.isRevealed ?? false
        #expect(isRevealed == true)

        // Initially, demo cohouse is NOT registered (so registration flow is accessible)
        let isRegisteredBefore: Bool = {
            guard let game = ckrGame, let cohouse else { return false }
            return game.cohouseIDs.contains(cohouse.id.uuidString)
        }()
        #expect(isRegisteredBefore == false)

        // After mock registration, the cohouseId is appended locally
        if var game = ckrGame, let cohouse {
            game.cohouseIDs.append(cohouse.id.uuidString)
            $ckrGame.withLock { $0 = game }
        }

        let isRegisteredAfter: Bool = {
            guard let game = ckrGame, let cohouse else { return false }
            return game.cohouseIDs.contains(cohouse.id.uuidString)
        }()
        #expect(isRegisteredAfter == true)

        // Cleanup
        @Shared(.userInfo) var userInfo
        @Shared(.news) var news
        @Shared(.challenges) var challenges
        $userInfo.withLock { $0 = nil }
        $cohouse.withLock { $0 = nil }
        $ckrGame.withLock { $0 = nil }
        $news.withLock { $0 = [] }
        $challenges.withLock { $0 = [] }
    }
}
