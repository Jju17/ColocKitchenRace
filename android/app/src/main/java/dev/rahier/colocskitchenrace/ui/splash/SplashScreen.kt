package dev.rahier.colocskitchenrace.ui.splash

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import dev.rahier.colocskitchenrace.R
import dev.rahier.colocskitchenrace.ui.theme.CkrDark
import dev.rahier.colocskitchenrace.ui.theme.CkrGray
import dev.rahier.colocskitchenrace.ui.theme.CkrSkyLight

@Composable
fun SplashScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(CkrSkyLight),
    ) {
        // Centered logo + loading indicator
        Column(
            modifier = Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Image(
                painter = painterResource(id = R.drawable.ckr_logo),
                contentDescription = "Colocs Kitchen Race",
                modifier = Modifier.size(150.dp),
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Loading indicator
            CircularProgressIndicator(
                color = CkrDark,
                strokeWidth = 3.dp,
            )
        }

        // Bottom text
        Text(
            text = "Made with \u2764\uFE0F by Julien",
            style = MaterialTheme.typography.bodySmall,
            color = CkrGray,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 48.dp),
        )
    }
}
