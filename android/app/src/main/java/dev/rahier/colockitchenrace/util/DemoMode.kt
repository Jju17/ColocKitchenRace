package dev.rahier.colockitchenrace.util

import dev.rahier.colockitchenrace.data.model.*
import java.util.Calendar
import java.util.Date

/**
 * Centralized demo mode configuration for Google Play / App Store review.
 *
 * When the reviewer signs in with the demo account, this module
 * provides pre-populated mock data for every screen of the app.
 * Each repository checks [isActive] to return demo data instead of hitting Firestore.
 */
object DemoMode {

    // -- Configuration --

    const val DEMO_EMAIL = "test_apple@colocskitchenrace.be"

    /** Whether demo mode is currently active (checked by repositories). */
    var isActive: Boolean = false
        private set

    fun activate() { isActive = true }
    fun deactivate() { isActive = false }

    // -- Stable IDs --

    const val DEMO_COHOUSE_ID = "DE000001-0000-0000-0000-000000000001"
    const val DEMO_USER_ID = "DE000002-0000-0000-0000-000000000001"
    const val DEMO_GAME_ID = "DE000003-0000-0000-0000-000000000001"

    private const val CHALLENGE_ID_1 = "DE00C001-0000-0000-0000-000000000001"
    private const val CHALLENGE_ID_2 = "DE00C002-0000-0000-0000-000000000002"
    private const val CHALLENGE_ID_3 = "DE00C003-0000-0000-0000-000000000003"
    private const val CHALLENGE_ID_4 = "DE00C004-0000-0000-0000-000000000004"
    private const val CHALLENGE_ID_5 = "DE00C005-0000-0000-0000-000000000005"

    // -- Demo Cohouse --

    val demoCohouse: Cohouse
        get() = Cohouse(
            id = DEMO_COHOUSE_ID,
            name = "La Coloc du Soleil",
            address = PostalAddress(
                street = "42 Rue de la Loi",
                city = "Bruxelles",
                postalCode = "1000",
                country = "Belgique",
            ),
            code = "A1B2C3D4",
            latitude = 50.8466,
            longitude = 4.3528,
            users = demoCohouseUsers,
            cohouseType = CohouseType.MIXED,
        )

    val demoCohouseUsers: List<CohouseUser>
        get() = listOf(
            CohouseUser(
                id = "DE000A01-0000-0000-0000-000000000001",
                isAdmin = true,
                surname = "Apple Reviewer",
                userId = DEMO_USER_ID,
            ),
            CohouseUser(
                id = "DE000A02-0000-0000-0000-000000000002",
                isAdmin = false,
                surname = "Marie Dupont",
            ),
            CohouseUser(
                id = "DE000A03-0000-0000-0000-000000000003",
                isAdmin = false,
                surname = "Lucas Martin",
            ),
        )

    // -- Demo CKRGame --

    val demoCKRGame: CKRGame
        get() {
            val cal = Calendar.getInstance()
            cal.add(Calendar.MONTH, 2)
            val gameDate = cal.time

            cal.add(Calendar.DAY_OF_MONTH, -5)
            val deadline = cal.time

            return CKRGame(
                id = DEMO_GAME_ID,
                editionNumber = 3,
                startCKRCountdown = dateOf(2026, 1, 1),
                nextGameDate = gameDate,
                registrationDeadline = deadline,
                maxParticipants = 100,
                pricePerPersonCents = 500,
                publishedTimestamp = dateOf(2026, 1, 15),
                cohouseIDs = listOf("other-cohouse-1", "other-cohouse-2", "other-cohouse-3"),
                totalRegisteredParticipants = 48,
                matchedGroups = listOf(
                    MatchedGroup(
                        cohouseIds = listOf(DEMO_COHOUSE_ID, "other-cohouse-1", "other-cohouse-2", "other-cohouse-3"),
                    ),
                ),
                matchedAt = dateOf(2026, 4, 11),
                eventSettings = CKREventSettings(
                    aperoStartTime = dateOf(2026, 4, 15, 18),
                    aperoEndTime = dateOf(2026, 4, 15, 20),
                    dinerStartTime = dateOf(2026, 4, 15, 20),
                    dinerEndTime = dateOf(2026, 4, 15, 22),
                    partyStartTime = dateOf(2026, 4, 15, 23),
                    partyEndTime = dateOf(2026, 4, 16, 4),
                    partyAddress = "Le Fuse, 208 Rue Blaes, 1000 Bruxelles",
                    partyName = "CKR Party",
                    partyNote = "Dress code: cuisine du monde!",
                ),
                groupPlannings = listOf(
                    GroupPlanning(
                        groupIndex = 1,
                        cohouseA = DEMO_COHOUSE_ID,
                        cohouseB = "other-cohouse-1",
                        cohouseC = "other-cohouse-2",
                        cohouseD = "other-cohouse-3",
                    ),
                ),
                isRevealed = true,
                revealedAt = dateOf(2026, 4, 12),
            )
        }

    // -- Demo Planning --

    val demoPlanning: CKRMyPlanning
        get() = CKRMyPlanning(
            apero = PlanningStep(
                role = StepRole.VISITOR,
                cohouseName = "Les Joyeux Lurons",
                address = "15 Rue Haute, 1000 Bruxelles",
                hostPhone = "+32 470 12 34 56",
                visitorPhone = "+32 471 65 43 21",
                totalPeople = 6,
                dietarySummary = mapOf("Vegetarien" to 1, "Sans gluten" to 1),
                startTime = dateOf(2026, 4, 15, 18),
                endTime = dateOf(2026, 4, 15, 20),
            ),
            diner = PlanningStep(
                role = StepRole.HOST,
                cohouseName = "La Bande a Manu",
                address = "42 Rue de la Loi, 1000 Bruxelles",
                hostPhone = "+32 471 65 43 21",
                visitorPhone = "+32 472 78 90 12",
                totalPeople = 7,
                dietarySummary = mapOf("Sans lactose" to 2),
                startTime = dateOf(2026, 4, 15, 20),
                endTime = dateOf(2026, 4, 15, 22),
            ),
            party = PartyInfo(
                name = "CKR Party",
                address = "Le Fuse, 208 Rue Blaes, 1000 Bruxelles",
                startTime = dateOf(2026, 4, 15, 23),
                endTime = dateOf(2026, 4, 16, 4),
                note = "Dress code: cuisine du monde!",
            ),
        )

    // -- Demo News --

    val demoNews: List<News>
        get() = listOf(
            News(
                id = "demo-news-1",
                title = "Inscriptions ouvertes pour la CKR #3!",
                body = "Les inscriptions pour la troisieme edition de la Colocs Kitchen Race sont officiellement ouvertes! Inscrivez votre coloc et preparez-vous pour une soiree inoubliable de cuisine, de rencontres et de fete.",
                publicationDate = dateOf(2026, 2, 1),
            ),
            News(
                id = "demo-news-2",
                title = "Nouveau: les defis sont la!",
                body = "Participez aux defis pour gagner des points bonus avant le jour J. Photos, quiz, enigmes... tout est permis! Rendez-vous dans l'onglet Challenges.",
                publicationDate = dateOf(2026, 2, 5),
            ),
            News(
                id = "demo-news-3",
                title = "Plus que quelques places!",
                body = "Il ne reste que 52 places pour la CKR #3. Ne tardez pas a inscrire votre coloc pour participer a cette edition!",
                publicationDate = dateOf(2026, 2, 10),
            ),
        )

    // -- Demo Challenges --

    val demoChallenges: List<Challenge>
        get() = listOf(
            Challenge(
                id = CHALLENGE_ID_1,
                title = "Photo de coloc!",
                startDate = dateOf(2025, 12, 1),
                endDate = dateOf(2026, 6, 1),
                body = "Prenez la plus belle photo de groupe de votre coloc et montrez votre esprit d'equipe!",
                content = ChallengeContent.Picture(),
                points = 10,
            ),
            Challenge(
                id = CHALLENGE_ID_2,
                title = "Quiz Culture Belge",
                startDate = dateOf(2025, 12, 15),
                endDate = dateOf(2026, 6, 1),
                body = "Quelle est la specialite culinaire la plus celebre de Bruxelles?",
                content = ChallengeContent.MultipleChoice(
                    choices = listOf("La gaufre", "Les moules-frites", "La carbonade", "Toutes ces reponses"),
                    correctAnswerIndex = 3,
                ),
                points = 5,
            ),
            Challenge(
                id = CHALLENGE_ID_3,
                title = "Premiere inscription!",
                startDate = dateOf(2025, 11, 1),
                endDate = dateOf(2025, 12, 31),
                body = "Soyez parmi les premiers a vous inscrire a la CKR!",
                content = ChallengeContent.NoChoice(),
                points = 3,
            ),
            Challenge(
                id = CHALLENGE_ID_4,
                title = "Meilleur deguisement",
                startDate = dateOf(2026, 4, 1),
                endDate = dateOf(2026, 4, 20),
                body = "Montrez-nous votre plus beau deguisement de cuisine du monde!",
                content = ChallengeContent.Picture(),
                points = 15,
            ),
            Challenge(
                id = CHALLENGE_ID_5,
                title = "Enigme du chef",
                startDate = dateOf(2026, 1, 1),
                endDate = dateOf(2026, 5, 1),
                body = "Je suis un ustensile de cuisine. On me tourne mais je ne suis pas une page. Qui suis-je?",
                content = ChallengeContent.SingleAnswer(),
                points = 8,
            ),
        )

    // -- Demo Challenge Responses --

    val demoChallengeResponses: List<ChallengeResponse>
        get() = listOf(
            ChallengeResponse(
                id = "DE00B001-0000-0000-0000-000000000001",
                challengeId = CHALLENGE_ID_1,
                cohouseId = DEMO_COHOUSE_ID,
                challengeTitle = "Photo de coloc!",
                cohouseName = "La Coloc du Soleil",
                content = ChallengeResponseContent.Picture(url = ""),
                status = ChallengeResponseStatus.WAITING,
                submissionDate = dateOf(2026, 2, 8),
            ),
            ChallengeResponse(
                id = "DE00B002-0000-0000-0000-000000000002",
                challengeId = CHALLENGE_ID_2,
                cohouseId = DEMO_COHOUSE_ID,
                challengeTitle = "Quiz Culture Belge",
                cohouseName = "La Coloc du Soleil",
                content = ChallengeResponseContent.MultipleChoice(selectedIndices = listOf(3)),
                status = ChallengeResponseStatus.VALIDATED,
                submissionDate = dateOf(2026, 1, 20),
            ),
            ChallengeResponse(
                id = "DE00B003-0000-0000-0000-000000000003",
                challengeId = CHALLENGE_ID_3,
                cohouseId = DEMO_COHOUSE_ID,
                challengeTitle = "Premiere inscription!",
                cohouseName = "La Coloc du Soleil",
                content = ChallengeResponseContent.NoChoice,
                status = ChallengeResponseStatus.VALIDATED,
                submissionDate = dateOf(2025, 11, 5),
            ),
        )

    // -- Helper --

    private fun dateOf(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0): Date {
        val cal = Calendar.getInstance(DateUtils.BRUSSELS_TZ)
        cal.set(year, month - 1, day, hour, minute, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.time
    }
}
