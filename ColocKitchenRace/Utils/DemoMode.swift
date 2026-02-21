//
//  DemoMode.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 13/02/2026.
//

import ComposableArchitecture
import FirebaseFirestore
import Foundation

/// Centralized demo mode configuration for Apple App Review.
///
/// When the Apple reviewer signs in with the demo account, this module
/// provides pre-populated mock data for every screen of the app.
/// Each data-loading client checks `DemoMode.isActive` to return
/// demo data instead of hitting Firestore.
enum DemoMode {

    // MARK: - Configuration

    static let demoEmail = "test_apple@colocskitchenrace.be"

    /// Whether demo mode is currently active (the signed-in user is the demo account).
    static var isActive: Bool {
        @Shared(.userInfo) var userInfo
        return userInfo?.email == demoEmail
    }

    // MARK: - Stable IDs (consistent references across models)

    static let demoCohouseId = UUID(uuidString: "DE000001-0000-0000-0000-000000000001")!
    static let demoUserId = UUID(uuidString: "DE000002-0000-0000-0000-000000000001")!
    static let demoGameId = UUID(uuidString: "DE000003-0000-0000-0000-000000000001")!

    // Challenge IDs (stable so responses can reference them)
    static let challengeId1 = UUID(uuidString: "DE00C001-0000-0000-0000-000000000001")!
    static let challengeId2 = UUID(uuidString: "DE00C002-0000-0000-0000-000000000002")!
    static let challengeId3 = UUID(uuidString: "DE00C003-0000-0000-0000-000000000003")!
    static let challengeId4 = UUID(uuidString: "DE00C004-0000-0000-0000-000000000004")!
    static let challengeId5 = UUID(uuidString: "DE00C005-0000-0000-0000-000000000005")!

    // MARK: - Demo Cohouse

    static var demoCohouse: Cohouse {
        Cohouse(
            id: demoCohouseId,
            name: "La Coloc du Soleil",
            address: PostalAddress(
                street: "42 Rue de la Loi",
                city: "Bruxelles",
                postalCode: "1000",
                country: "Belgique"
            ),
            code: "A1B2C3D4",
            latitude: 50.8466,
            longitude: 4.3528,
            users: IdentifiedArray(uniqueElements: demoCohouseUsers),
            cohouseType: .mixed
        )
    }

    static var demoCohouseUsers: [CohouseUser] {
        [
            CohouseUser(id: UUID(uuidString: "DE000A01-0000-0000-0000-000000000001")!,
                         isAdmin: true, surname: "Apple Reviewer", userId: demoUserId.uuidString),
            CohouseUser(id: UUID(uuidString: "DE000A02-0000-0000-0000-000000000002")!,
                         isAdmin: false, surname: "Marie Dupont"),
            CohouseUser(id: UUID(uuidString: "DE000A03-0000-0000-0000-000000000003")!,
                         isAdmin: false, surname: "Lucas Martin"),
        ]
    }

    // MARK: - Demo CKRGame (revealed, with planning)

    static var demoCKRGame: CKRGame {
        // Registration deadline and game date are always in the future so the
        // Apple reviewer can go through the full registration + payment flow.
        let gameDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let deadline = Calendar.current.date(byAdding: .day, value: -5, to: gameDate)!

        return CKRGame(
            id: demoGameId,
            editionNumber: 3,
            startCKRCountdown: Date.from(year: 2026, month: 1, day: 1),
            nextGameDate: gameDate,
            registrationDeadline: deadline,
            maxParticipants: 100,
            pricePerPersonCents: 500,
            publishedTimestamp: Date.from(year: 2026, month: 1, day: 15),
            // Demo cohouse is NOT in cohouseIDs so the reviewer sees the registration flow.
            // After successful mock payment, registerForGame adds it locally.
            cohouseIDs: ["other-cohouse-1", "other-cohouse-2", "other-cohouse-3"],
            totalRegisteredParticipants: 48,
            matchedGroups: [
                MatchedGroup(cohouseIds: [demoCohouseId.uuidString, "other-cohouse-1", "other-cohouse-2", "other-cohouse-3"])
            ],
            matchedAt: Date.from(year: 2026, month: 4, day: 11),
            eventSettings: CKREventSettings(
                aperoStartTime: Date.from(year: 2026, month: 4, day: 15, hour: 18),
                aperoEndTime: Date.from(year: 2026, month: 4, day: 15, hour: 20),
                dinerStartTime: Date.from(year: 2026, month: 4, day: 15, hour: 20),
                dinerEndTime: Date.from(year: 2026, month: 4, day: 15, hour: 22),
                partyStartTime: Date.from(year: 2026, month: 4, day: 15, hour: 23),
                partyEndTime: Date.from(year: 2026, month: 4, day: 16, hour: 4),
                partyAddress: "Le Fuse, 208 Rue Blaes, 1000 Bruxelles",
                partyName: "CKR Party",
                partyNote: "Dress code: cuisine du monde!"
            ),
            groupPlannings: [
                GroupPlanning(
                    groupIndex: 1,
                    cohouseA: demoCohouseId.uuidString,
                    cohouseB: "other-cohouse-1",
                    cohouseC: "other-cohouse-2",
                    cohouseD: "other-cohouse-3"
                )
            ],
            isRevealed: true,
            revealedAt: Date.from(year: 2026, month: 4, day: 12)
        )
    }

    // MARK: - Demo Planning

    static var demoPlanning: CKRMyPlanning {
        CKRMyPlanning(
            apero: PlanningStep(
                role: .visitor,
                cohouseName: "Les Joyeux Lurons",
                address: "15 Rue Haute, 1000 Bruxelles",
                hostPhone: "+32 470 12 34 56",
                visitorPhone: "+32 471 65 43 21",
                totalPeople: 6,
                dietarySummary: ["Vegetarien": 1, "Sans gluten": 1],
                startTime: Date.from(year: 2026, month: 4, day: 15, hour: 18),
                endTime: Date.from(year: 2026, month: 4, day: 15, hour: 20)
            ),
            diner: PlanningStep(
                role: .host,
                cohouseName: "La Bande a Manu",
                address: "42 Rue de la Loi, 1000 Bruxelles",
                hostPhone: "+32 471 65 43 21",
                visitorPhone: "+32 472 78 90 12",
                totalPeople: 7,
                dietarySummary: ["Sans lactose": 2],
                startTime: Date.from(year: 2026, month: 4, day: 15, hour: 20),
                endTime: Date.from(year: 2026, month: 4, day: 15, hour: 22)
            ),
            party: PartyInfo(
                name: "CKR Party",
                address: "Le Fuse, 208 Rue Blaes, 1000 Bruxelles",
                startTime: Date.from(year: 2026, month: 4, day: 15, hour: 23),
                endTime: Date.from(year: 2026, month: 4, day: 16, hour: 4),
                note: "Dress code: cuisine du monde!"
            )
        )
    }

    // MARK: - Demo News

    static var demoNews: [News] {
        [
            News(
                id: "demo-news-1",
                title: "Inscriptions ouvertes pour la CKR #3!",
                body: "Les inscriptions pour la troisieme edition de la Colocs Kitchen Race sont officiellement ouvertes! Inscrivez votre coloc et preparez-vous pour une soiree inoubliable de cuisine, de rencontres et de fete.",
                publicationTimestamp: Timestamp(date: Date.from(year: 2026, month: 2, day: 1))
            ),
            News(
                id: "demo-news-2",
                title: "Nouveau: les defis sont la!",
                body: "Participez aux defis pour gagner des points bonus avant le jour J. Photos, quiz, enigmes... tout est permis! Rendez-vous dans l'onglet Challenges.",
                publicationTimestamp: Timestamp(date: Date.from(year: 2026, month: 2, day: 5))
            ),
            News(
                id: "demo-news-3",
                title: "Plus que quelques places!",
                body: "Il ne reste que 52 places pour la CKR #3. Ne tardez pas a inscrire votre coloc pour participer a cette edition!",
                publicationTimestamp: Timestamp(date: Date.from(year: 2026, month: 2, day: 10))
            ),
        ]
    }

    // MARK: - Demo Challenges (various states)

    static var demoChallenges: [Challenge] {
        [
            // ONGOING — picture challenge, has a "waiting" response
            Challenge(
                id: challengeId1,
                title: "Photo de coloc!",
                startDate: Date.from(year: 2025, month: 12, day: 1),
                endDate: Date.from(year: 2026, month: 6, day: 1),
                body: "Prenez la plus belle photo de groupe de votre coloc et montrez votre esprit d'equipe!",
                content: .picture(PictureContent()),
                points: 10
            ),
            // ONGOING — multiple choice quiz, has a "validated" response
            Challenge(
                id: challengeId2,
                title: "Quiz Culture Belge",
                startDate: Date.from(year: 2025, month: 12, day: 15),
                endDate: Date.from(year: 2026, month: 6, day: 1),
                body: "Quelle est la specialite culinaire la plus celebre de Bruxelles?",
                content: .multipleChoice(MultipleChoiceContent(
                    choices: ["La gaufre", "Les moules-frites", "La carbonade", "Toutes ces reponses"],
                    correctAnswerIndex: 3,
                    shuffleAnswers: false
                )),
                points: 5
            ),
            // DONE — ended in the past, has a "validated" response
            Challenge(
                id: challengeId3,
                title: "Premiere inscription!",
                startDate: Date.from(year: 2025, month: 11, day: 1),
                endDate: Date.from(year: 2025, month: 12, day: 31),
                body: "Soyez parmi les premiers a vous inscrire a la CKR!",
                content: .noChoice(NoChoiceContent()),
                points: 3
            ),
            // NOT STARTED — starts in the future
            Challenge(
                id: challengeId4,
                title: "Meilleur deguisement",
                startDate: Date.from(year: 2026, month: 4, day: 1),
                endDate: Date.from(year: 2026, month: 4, day: 20),
                body: "Montrez-nous votre plus beau deguisement de cuisine du monde!",
                content: .picture(PictureContent()),
                points: 15
            ),
            // ONGOING — single answer enigma, no response yet
            Challenge(
                id: challengeId5,
                title: "Enigme du chef",
                startDate: Date.from(year: 2026, month: 1, day: 1),
                endDate: Date.from(year: 2026, month: 5, day: 1),
                body: "Je suis un ustensile de cuisine. On me tourne mais je ne suis pas une page. Qui suis-je?",
                content: .singleAnswer(SingleAnswerContent()),
                points: 8
            ),
        ]
    }

    // MARK: - Demo Challenge Responses

    static var demoChallengeResponses: [ChallengeResponse] {
        [
            // "Photo de coloc!" — waiting for review
            ChallengeResponse(
                id: UUID(uuidString: "DE00B001-0000-0000-0000-000000000001")!,
                challengeId: challengeId1,
                cohouseId: demoCohouseId.uuidString,
                challengeTitle: "Photo de coloc!",
                cohouseName: "La Coloc du Soleil",
                content: .picture(""),
                status: .waiting,
                submissionDate: Date.from(year: 2026, month: 2, day: 8)
            ),
            // "Quiz Culture Belge" — validated
            ChallengeResponse(
                id: UUID(uuidString: "DE00B002-0000-0000-0000-000000000002")!,
                challengeId: challengeId2,
                cohouseId: demoCohouseId.uuidString,
                challengeTitle: "Quiz Culture Belge",
                cohouseName: "La Coloc du Soleil",
                content: .multipleChoice([3]),
                status: .validated,
                submissionDate: Date.from(year: 2026, month: 1, day: 20)
            ),
            // "Premiere inscription!" — validated (done challenge)
            ChallengeResponse(
                id: UUID(uuidString: "DE00B003-0000-0000-0000-000000000003")!,
                challengeId: challengeId3,
                cohouseId: demoCohouseId.uuidString,
                challengeTitle: "Premiere inscription!",
                cohouseName: "La Coloc du Soleil",
                content: .noChoice,
                status: .validated,
                submissionDate: Date.from(year: 2025, month: 11, day: 5)
            ),
        ]
    }

    // MARK: - Seed all @Shared state for demo user

    /// Populates all `@Shared` states with demo data.
    /// Called once after the demo user signs in.
    static func seedSharedState(for user: User) {
        @Shared(.userInfo) var userInfo
        @Shared(.cohouse) var cohouse
        @Shared(.ckrGame) var ckrGame
        @Shared(.news) var news
        @Shared(.challenges) var challenges

        // Ensure the user's cohouseId points to the demo cohouse
        var demoUser = user
        demoUser.cohouseId = demoCohouseId.uuidString
        demoUser.phoneNumber = "+32 470 00 00 00"
        $userInfo.withLock { $0 = demoUser }

        $cohouse.withLock { $0 = demoCohouse }
        $ckrGame.withLock { $0 = demoCKRGame }
        $news.withLock { $0 = demoNews }
        $challenges.withLock { $0 = demoChallenges }
    }
}
