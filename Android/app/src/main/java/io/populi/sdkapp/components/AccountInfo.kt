package io.populi.sdkapp.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage

@Composable
fun AccountInfo(name: String, logo: String, modifier: Modifier = Modifier) {
    Column(modifier) {
        Row(horizontalArrangement = Arrangement.SpaceBetween) {
            Text(text = name, Modifier.weight(1f))
            SubcomposeAsyncImage(
                model = logo,
                contentDescription = "logo",
                modifier = Modifier
                    .height(50.dp)
                    .width(100.dp),
                contentScale = ContentScale.Crop
            )
        }
    }
}
