package io.populi.sdkapp.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.zIndex
import coil.compose.SubcomposeAsyncImage
import io.populi.sdkapp.uimodel.PopmapDetailsInfo

@Composable
fun PopMapInfoDetails(
    detailsInfo: PopmapDetailsInfo, fetchClick: () -> Unit, modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Box(modifier = modifier.fillMaxSize()) {
        Button(modifier = Modifier
            .fillMaxWidth(0.8f)
            .align(Alignment.BottomCenter)
            .zIndex(4f),
            onClick = {
                fetchClick()
            }) { Text(text = "DonwloadInfo") }

        Column(modifier = Modifier.verticalScroll(scrollState)) {
            SubcomposeAsyncImage(
                modifier = Modifier.fillMaxWidth(),
                model = detailsInfo.picture,
                contentDescription = "imageFile"
            )
            Text(text = "uid: ${detailsInfo.uid}")
            Text(text = "name: ${detailsInfo.name}")
            Text(text = "language id :${detailsInfo.langId}")
            Text(text = "percentage: ${detailsInfo.percentage}%")
            Text(text = "downloaded size: ${detailsInfo.downloadedSize}")
            Text(text = "size to download: ${detailsInfo.sizeToDownload}")
            Text(text = "downloadState: ${detailsInfo.downloadState}")
            Text(text = "files: \n${detailsInfo.downloadedFiles}")
        }
    }

}