package dev.rahier.colocskitchenrace

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.stripe.android.PaymentConfiguration
import dagger.hilt.android.AndroidEntryPoint
import dev.rahier.colocskitchenrace.ui.CKRApp
import dev.rahier.colocskitchenrace.ui.components.ErrorBoundary
import dev.rahier.colocskitchenrace.ui.theme.CKRTheme

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize Stripe SDK
        PaymentConfiguration.init(
            context = applicationContext,
            publishableKey = BuildConfig.STRIPE_PUBLISHABLE_KEY,
        )

        setContent {
            CKRTheme {
                ErrorBoundary {
                    CKRApp()
                }
            }
        }
    }
}
