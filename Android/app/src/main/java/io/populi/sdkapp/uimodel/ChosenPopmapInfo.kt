package io.populi.sdkapp.uimodel

import io.populi.sdk.download.DownloadState
import java.io.File

data class PopmapDetailsInfo(
    val id: Int,
    val uid: String,
    val langId: Int,
    val name: String,
    val picture: String,
    val percentage: Int = 0,
    val downloadedSize: Long = 0L,
    val sizeToDownload: Long = 0L,
    val downloadState: DownloadState = DownloadState.NONE,
    val downloadedFiles: List<File> = emptyList()
)