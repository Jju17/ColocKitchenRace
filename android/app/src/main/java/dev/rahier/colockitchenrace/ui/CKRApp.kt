package dev.rahier.colockitchenrace.ui

import androidx.compose.runtime.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import dev.rahier.colockitchenrace.ui.auth.emailverification.EmailVerificationScreen
import dev.rahier.colockitchenrace.ui.auth.profilecompletion.ProfileCompletionScreen
import dev.rahier.colockitchenrace.ui.auth.signin.SignInScreen
import dev.rahier.colockitchenrace.ui.main.MainScreen
import dev.rahier.colockitchenrace.ui.splash.SplashScreen

object CKRRoutes {
    const val SPLASH = "splash"
    const val SIGN_IN = "sign_in"
    const val EMAIL_VERIFICATION = "email_verification"
    const val PROFILE_COMPLETION = "profile_completion"
    const val MAIN = "main"
}

@Composable
fun CKRApp(
    appViewModel: CKRAppViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    val authState by appViewModel.authState.collectAsStateWithLifecycle()

    // React to auth state changes
    LaunchedEffect(authState) {
        when (authState) {
            AuthState.UNAUTHENTICATED -> {
                navController.navigate(CKRRoutes.SIGN_IN) {
                    popUpTo(0) { inclusive = true }
                }
            }
            AuthState.NEEDS_EMAIL_VERIFICATION -> {
                navController.navigate(CKRRoutes.EMAIL_VERIFICATION) {
                    popUpTo(0) { inclusive = true }
                }
            }
            AuthState.NEEDS_PROFILE_COMPLETION -> {
                navController.navigate(CKRRoutes.PROFILE_COMPLETION) {
                    popUpTo(0) { inclusive = true }
                }
            }
            AuthState.AUTHENTICATED -> {
                navController.navigate(CKRRoutes.MAIN) {
                    popUpTo(0) { inclusive = true }
                }
            }
            AuthState.LOADING -> {} // Stay on splash
        }
    }

    NavHost(navController = navController, startDestination = CKRRoutes.SPLASH) {
        composable(CKRRoutes.SPLASH) {
            SplashScreen()
        }
        composable(CKRRoutes.SIGN_IN) {
            SignInScreen(
                onNavigateToMain = { navController.navigate(CKRRoutes.MAIN) { popUpTo(0) { inclusive = true } } },
                onNavigateToEmailVerification = { navController.navigate(CKRRoutes.EMAIL_VERIFICATION) { popUpTo(0) { inclusive = true } } },
                onNavigateToProfileCompletion = { navController.navigate(CKRRoutes.PROFILE_COMPLETION) { popUpTo(0) { inclusive = true } } },
            )
        }
        composable(CKRRoutes.EMAIL_VERIFICATION) {
            EmailVerificationScreen(
                onNavigateToProfileCompletion = { navController.navigate(CKRRoutes.PROFILE_COMPLETION) { popUpTo(0) { inclusive = true } } },
                onNavigateToMain = { navController.navigate(CKRRoutes.MAIN) { popUpTo(0) { inclusive = true } } },
                onNavigateToSignIn = { navController.navigate(CKRRoutes.SIGN_IN) { popUpTo(0) { inclusive = true } } },
            )
        }
        composable(CKRRoutes.PROFILE_COMPLETION) {
            ProfileCompletionScreen(
                onNavigateToMain = { navController.navigate(CKRRoutes.MAIN) { popUpTo(0) { inclusive = true } } },
            )
        }
        composable(CKRRoutes.MAIN) {
            MainScreen()
        }
    }
}
