package dev.rahier.colocskitchenrace.ui.main

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
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
import dev.rahier.colocskitchenrace.ui.challenges.ChallengesScreen
import dev.rahier.colocskitchenrace.ui.challenges.LeaderboardBottomSheet
import dev.rahier.colocskitchenrace.ui.cohouse.CohouseScreen
import dev.rahier.colocskitchenrace.ui.cohouse.form.CohouseFormScreen
import dev.rahier.colocskitchenrace.ui.home.HomeScreen
import dev.rahier.colocskitchenrace.ui.home.registration.PaymentSummaryScreen
import dev.rahier.colocskitchenrace.ui.home.registration.RegistrationFormScreen
import dev.rahier.colocskitchenrace.ui.planning.PlanningScreen
import dev.rahier.colocskitchenrace.ui.profile.UserProfileFormScreen
import dev.rahier.colocskitchenrace.ui.profile.UserProfileScreen
import dev.rahier.colocskitchenrace.MainActivity
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.theme.CkrGray
import dev.rahier.colocskitchenrace.ui.theme.CkrLavender
import dev.rahier.colocskitchenrace.ui.theme.CkrWhite
import androidx.compose.ui.platform.LocalContext

enum class Tab(val route: String, @StringRes val labelRes: Int, val icon: ImageVector) {
    HOME("tab_home", R.string.tab_home, Icons.Default.Home),
    CHALLENGES("tab_challenges", R.string.tab_challenges, Icons.Default.Star),
    PLANNING("tab_planning", R.string.tab_planning, Icons.Default.DateRange),
    COHOUSE("tab_cohouse", R.string.tab_cohouse, Icons.Default.People),
}

object MainRoutes {
    const val PROFILE = "profile"
    const val PROFILE_EDIT = "profile_edit"
    const val REGISTRATION_FORM = "registration_form"
    const val PAYMENT_SUMMARY = "payment_summary/{gameId}/{cohouseId}/{averageAge}/{cohouseType}/{totalPriceCents}/{participantCount}/{attendingUserIds}"
    const val COHOUSE_CREATE = "cohouse_create"
    const val COHOUSE_EDIT = "cohouse_edit"

    fun paymentSummary(
        gameId: String,
        cohouseId: String,
        averageAge: Int,
        cohouseType: String,
        totalPriceCents: Int,
        participantCount: Int,
        attendingUserIds: List<String>,
    ): String {
        val encodedIds = java.net.URLEncoder.encode(attendingUserIds.joinToString(","), "UTF-8")
        return "payment_summary/$gameId/$cohouseId/$averageAge/$cohouseType/$totalPriceCents/$participantCount/$encodedIds"
    }
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

    // Deep link handling from push notifications
    val activity = LocalContext.current as? MainActivity
    val pendingDeepLink by activity?.pendingDeepLink?.collectAsStateWithLifecycle()
        ?: remember { mutableStateOf(null) }

    LaunchedEffect(pendingDeepLink) {
        val type = pendingDeepLink ?: return@LaunchedEffect
        val targetRoute = when {
            type.contains("challenge") -> Tab.CHALLENGES.route
            type.contains("apero") || type.contains("diner") || type.contains("party") ||
                type.contains("planning") -> Tab.PLANNING.route
            else -> Tab.HOME.route
        }
        navController.navigate(targetRoute) {
            popUpTo(navController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
        activity?.consumeDeepLink()
    }

    Scaffold(
        bottomBar = {
            if (isOnTab) {
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface,
                ) {
                    val currentDestination = navBackStackEntry?.destination

                    tabs.forEach { tab ->
                        NavigationBarItem(
                            icon = { Icon(tab.icon, contentDescription = stringResource(tab.labelRes)) },
                            label = { Text(stringResource(tab.labelRes), style = MaterialTheme.typography.labelSmall) },
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
                                unselectedIconColor = CkrGray,
                                unselectedTextColor = CkrGray,
                                indicatorColor = CkrLavender.copy(alpha = 0.12f),
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
            modifier = Modifier
                .padding(innerPadding)
                .consumeWindowInsets(innerPadding),
        ) {
            // Tab destinations
            composable(Tab.HOME.route) {
                HomeScreen(
                    onNavigateToProfile = { navController.navigate(MainRoutes.PROFILE) },
                    onNavigateToRegistration = { navController.navigate(MainRoutes.REGISTRATION_FORM) },
                    onNavigateToCohouse = {
                        navController.navigate(Tab.COHOUSE.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
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
                        navController.navigate(
                            MainRoutes.paymentSummary(gameId, cohouseId, averageAge, cohouseType, totalPriceCents, participantCount, attendingUserIds)
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
                    navArgument("attendingUserIds") { type = NavType.StringType },
                ),
            ) { backStackEntry ->
                val gameId = backStackEntry.arguments?.getString("gameId") ?: ""
                val cohouseId = backStackEntry.arguments?.getString("cohouseId") ?: ""
                val averageAge = backStackEntry.arguments?.getInt("averageAge") ?: 0
                val cohouseType = backStackEntry.arguments?.getString("cohouseType") ?: ""
                val totalPriceCents = backStackEntry.arguments?.getInt("totalPriceCents") ?: 0
                val participantCount = backStackEntry.arguments?.getInt("participantCount") ?: 0
                val attendingUserIds = backStackEntry.arguments?.getString("attendingUserIds")
                    ?.let { java.net.URLDecoder.decode(it, "UTF-8") }
                    ?.split(",")
                    ?.filter { it.isNotBlank() }
                    ?: emptyList()

                PaymentSummaryScreen(
                    gameId = gameId,
                    cohouseId = cohouseId,
                    attendingUserIds = attendingUserIds,
                    averageAge = averageAge,
                    cohouseType = cohouseType,
                    totalPriceCents = totalPriceCents,
                    participantCount = participantCount,
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
