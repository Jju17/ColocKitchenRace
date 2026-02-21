package dev.rahier.colockitchenrace

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dagger.hilt.android.AndroidEntryPoint
import dev.rahier.colockitchenrace.ui.CKRApp
import dev.rahier.colockitchenrace.ui.theme.CKRTheme

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CKRTheme {
                CKRApp()
            }
        }
    }
}
