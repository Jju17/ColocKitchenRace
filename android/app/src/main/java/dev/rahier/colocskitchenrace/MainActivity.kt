package dev.rahier.colocskitchenrace

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.stripe.android.PaymentConfiguration
import dagger.hilt.android.AndroidEntryPoint
import dev.rahier.colocskitchenrace.ui.CKRApp
import dev.rahier.colocskitchenrace.ui.theme.CKRTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    private val _pendingDeepLink = MutableStateFlow<String?>(null)
    val pendingDeepLink: StateFlow<String?> = _pendingDeepLink.asStateFlow()

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize Stripe SDK
        PaymentConfiguration.init(
            context = applicationContext,
            publishableKey = BuildConfig.STRIPE_PUBLISHABLE_KEY,
        )

        handleDeepLink(intent)

        setContent {
            CKRTheme {
                CKRApp()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        val type = intent?.getStringExtra(CKRFirebaseMessagingService.EXTRA_NOTIFICATION_TYPE)
        if (type != null) {
            _pendingDeepLink.value = type
            intent.removeExtra(CKRFirebaseMessagingService.EXTRA_NOTIFICATION_TYPE)
        }
    }

    fun consumeDeepLink() {
        _pendingDeepLink.value = null
    }
}
