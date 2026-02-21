package dev.rahier.colockitchenrace.ui.main

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import dev.rahier.colockitchenrace.ui.challenges.ChallengesScreen
import dev.rahier.colockitchenrace.ui.challenges.LeaderboardBottomSheet
import dev.rahier.colockitchenrace.ui.cohouse.CohouseScreen
import dev.rahier.colockitchenrace.ui.cohouse.form.CohouseFormScreen
import dev.rahier.colockitchenrace.ui.home.HomeScreen
import dev.rahier.colockitchenrace.ui.home.registration.PaymentSummaryScreen
import dev.rahier.colockitchenrace.ui.home.registration.RegistrationFormScreen
import dev.rahier.colockitchenrace.ui.planning.PlanningScreen
import dev.rahier.colockitchenrace.ui.profile.UserProfileFormScreen
import dev.rahier.colockitchenrace.ui.profile.UserProfileScreen
import dev.rahier.colockitchenrace.ui.theme.CkrLavender

enum class Tab(val route: String, val label: String, val icon: ImageVector) {
    HOME("tab_home", "Accueil", Icons.Default.Home),
    CHALLENGES("tab_challenges", "Challenges", Icons.Default.Star),
    PLANNING("tab_planning", "Planning", Icons.Default.DateRange),
    COHOUSE("tab_cohouse", "Coloc", Icons.Default.People),
}

object MainRoutes {
    const val PROFILE = "profile"
    const val PROFILE_EDIT = "profile_edit"
    const val REGISTRATION_FORM = "registration_form"
    const val PAYMENT_SUMMARY = "payment_summary/{gameId}/{cohouseId}/{averageAge}/{cohouseType}/{totalPriceCents}/{participantCount}"
    const val COHOUSE_CREATE = "cohouse_create"
    const val COHOUSE_EDIT = "cohouse_edit"

    fun paymentSummary(
        gameId: String,
        cohouseId: String,
        averageAge: Int,
        cohouseType: String,
        totalPriceCents: Int,
        participantCount: Int,
    ) = "payment_summary/$gameId/$cohouseId/$averageAge/$cohouseType/$totalPriceCents/$participantCount"
}

@Composable
fun MainScreen(
    viewModel: MainViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    val showPlanning by viewModel.showPlanningTab.collectAsStateWithLifecycle()
    val tabs = remember(showPlanning) {
        if (showPlanning) Tab.entries.toList() else Tab.entries.filter { it != Tab.PLANNING }
    }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val isOnTab = tabs.any { it.route == currentRoute }

    var showLeaderboard by remember { mutableStateOf(false) }

    Scaffold(
        bottomBar = {
            if (isOnTab) {
                NavigationBar {
                    val currentDestination = navBackStackEntry?.destination

                    tabs.forEach { tab ->
                        NavigationBarItem(
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                            selected = currentDestination?.hierarchy?.any { it.route == tab.route } == true,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = CkrLavender,
                                selectedTextColor = CkrLavender,
                            ),
                        )
                    }
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Tab.HOME.route,
            modifier = Modifier.padding(innerPadding),
        ) {
            // Tab destinations
            composable(Tab.HOME.route) {
                HomeScreen(
                    onNavigateToProfile = { navController.navigate(MainRoutes.PROFILE) },
                    onNavigateToRegistration = { navController.navigate(MainRoutes.REGISTRATION_FORM) },
                )
            }
            composable(Tab.CHALLENGES.route) {
                ChallengesScreen(
                    onShowLeaderboard = { showLeaderboard = true },
                )
            }
            composable(Tab.PLANNING.route) { PlanningScreen() }
            composable(Tab.COHOUSE.route) {
                CohouseScreen(
                    onNavigateToCreate = { navController.navigate(MainRoutes.COHOUSE_CREATE) },
                    onNavigateToEdit = { navController.navigate(MainRoutes.COHOUSE_EDIT) },
                )
            }

            // Secondary destinations
            composable(MainRoutes.PROFILE) {
                UserProfileScreen(
                    onSignedOut = { /* handled by CKRApp auth state */ },
                    onNavigateToEdit = { navController.navigate(MainRoutes.PROFILE_EDIT) },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(MainRoutes.PROFILE_EDIT) {
                UserProfileFormScreen(
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(MainRoutes.REGISTRATION_FORM) {
                RegistrationFormScreen(
                    onNavigateToPayment = { gameId, cohouseId, attendingUserIds, averageAge, cohouseType, totalPriceCents, participantCount ->
                        navController.currentBackStackEntry?.savedStateHandle?.set("attendingUserIds", attendingUserIds)
                        navController.navigate(
                            MainRoutes.paymentSummary(gameId, cohouseId, averageAge, cohouseType, totalPriceCents, participantCount)
                        )
                    },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                MainRoutes.PAYMENT_SUMMARY,
                arguments = listOf(
                    navArgument("gameId") { type = NavType.StringType },
                    navArgument("cohouseId") { type = NavType.StringType },
                    navArgument("averageAge") { type = NavType.IntType },
                    navArgument("cohouseType") { type = NavType.StringType },
                    navArgument("totalPriceCents") { type = NavType.IntType },
                    navArgument("participantCount") { type = NavType.IntType },
                ),
            ) { backStackEntry ->
                val gameId = backStackEntry.arguments?.getString("gameId") ?: ""
                val cohouseId = backStackEntry.arguments?.getString("cohouseId") ?: ""
                val averageAge = backStackEntry.arguments?.getInt("averageAge") ?: 0
                val cohouseType = backStackEntry.arguments?.getString("cohouseType") ?: ""
                val totalPriceCents = backStackEntry.arguments?.getInt("totalPriceCents") ?: 0
                val participantCount = backStackEntry.arguments?.getInt("participantCount") ?: 0
                val attendingUserIds = navController.previousBackStackEntry
                    ?.savedStateHandle?.get<List<String>>("attendingUserIds") ?: emptyList()

                PaymentSummaryScreen(
                    gameId = gameId,
                    cohouseId = cohouseId,
                    attendingUserIds = attendingUserIds,
                    averageAge = averageAge,
                    cohouseType = cohouseType,
                    totalPriceCents = totalPriceCents,
                    participantCount = participantCount,
                    onPaymentSheet = { _, _, _ ->
                        // Stripe PaymentSheet is presented via Activity result in real implementation
                    },
                    onRegistrationComplete = {
                        navController.popBackStack(Tab.HOME.route, inclusive = false)
                    },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(MainRoutes.COHOUSE_CREATE) {
                CohouseFormScreen(
                    isEditMode = false,
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(MainRoutes.COHOUSE_EDIT) {
                CohouseFormScreen(
                    isEditMode = true,
                    onSaved = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
        }
    }

    if (showLeaderboard) {
        LeaderboardBottomSheet(onDismiss = { showLeaderboard = false })
    }
}
