package io.populi.sdkapp.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun CredentialsInfo(name: String, pass: String, modifier: Modifier = Modifier) {
    Column(modifier) {
        Row(horizontalArrangement = Arrangement.SpaceBetween) {
            Text(text = name, Modifier.weight(1f))
            Text(text = pass, Modifier.weight(1f))
        }
    }
}
