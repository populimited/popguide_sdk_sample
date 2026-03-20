package io.populi.sdkapp

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.populi.sdk.PopuliSdk
import io.populi.sdk.download.DownloadState
import io.populi.sdk.download.DownloadStatus
import io.populi.sdk.server.model.response.detailsResponse.PopMapDetailsServer
import io.populi.sdkapp.components.AccountInfo
import io.populi.sdkapp.components.CredentialsInfo
import io.populi.sdkapp.components.PopMapInfoDetails
import io.populi.sdkapp.components.PopmapInfoList
import io.populi.sdkapp.ui.theme.PopguideSdkTheme
import io.populi.sdkapp.uimodel.AccountInfo
import io.populi.sdkapp.uimodel.LangPackInfo
import io.populi.sdkapp.uimodel.PopMapInfo
import io.populi.sdkapp.uimodel.PopmapDetailsInfo
import io.populi.sdkapp.uimodel.createAccountInfo
import io.populi.sdkapp.uimodel.createPopMapInfoList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : ComponentActivity() {

    private val sdk by lazy {
        PopuliSdk.Builder()
            .setAppContext(this.applicationContext)
            .setAppName("popguide")
            .setIsStaging(false)
            .setIsDebug(true)
            .setApiAppVersion("120")
            .setUserAgent(
                appName = "test",
                versionName = "test",
                versionCode = "test",
                deviceOS = "test",
                deviceModel = "test"
            )
            .build()
    }

    //     Default credentials
    private val userName = "POP-001600"
    private val passCode = "93043"

    private val accountUiState = mutableStateOf<AccountInfo?>(null)
    private val popmapInfoListUiState = mutableStateOf<List<PopMapInfo>>(emptyList())
    private val popmapDetailsInfoUiState = mutableStateOf<PopmapDetailsInfo?>(null)
    private val sdkScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val account by accountUiState
            val popmaps by popmapInfoListUiState
            val popmapDetailsInfo by popmapDetailsInfoUiState

            PopguideSdkTheme {
                // A surface container using the 'background' color from the theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    if (popmapDetailsInfo != null) {
                        Column(
                            modifier = Modifier
                                .padding(16.dp)
                                .fillMaxSize()
                        ) {
                            IconButton(onClick = {
                                closeChosenPopMap()
                            }) {
                                Icon(
                                    painterResource(id = android.R.drawable.ic_menu_close_clear_cancel),
                                    contentDescription = "descriptionIcon",
                                )
                            }
                            PopMapInfoDetails(popmapDetailsInfo!!, {
                                downloadPopMapDetails(popmapDetailsInfo!!)
                            })
                        }
                    } else {
                        Column(
                            modifier = Modifier,
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "PopGuideSdk",
                                modifier = Modifier.padding(16.dp)
                            )
                            CredentialsInfo(
                                name = userName,
                                pass = passCode,
                                modifier = Modifier.padding(16.dp)
                            )
                            if (account != null) {
                                AccountInfo(
                                    name = account?.name.orEmpty(),
                                    logo = account?.logo.orEmpty(),
                                    modifier = Modifier.padding(16.dp)
                                )
                            }
                            if (popmaps.isNotEmpty()) {
                                PopmapInfoList(
                                    popmaps = popmaps,
                                    itemClick = { popMap, lang ->
                                        choosePopmapInfo(popMap = popMap, lang = lang)
                                    },
                                    modifier = Modifier.padding(16.dp)
                                )
                            }

                            Spacer(modifier = Modifier.weight(1f))
                            Button(
                                modifier = Modifier.fillMaxWidth(0.8f),
                                onClick = { fetchAccount() }) {
                                Text(text = "Fetch account")
                            }
                        }
                    }
                }
            }
        }
    }


    override fun onDestroy() {
        sdkScope.coroutineContext.cancelChildren()
        super.onDestroy()
    }

    // Retrieves and updates details of the selected pop map
    private fun choosePopmapInfo(popMap: PopMapInfo, lang: LangPackInfo) {
        sdkScope.launch {
            val accountInfo = accountUiState.value
            // Fetches pop map details from the server or local
            val popMapDetails =
                try {
                    sdk.fetchLocalPopMapDetails(popMap.uid, lang.id)
                } catch (e: Exception) {
                    sdk.fetchPopMapDetailsServer(
                        accountId = accountInfo?.id ?: -1,
                        groupId = accountInfo?.groupId ?: -1,
                        popMapId = popMap.id,
                        languageId = lang.id,
                        version = popMap.version
                    )
                }
            // Updates UI state with the retrieved pop map details
            popmapDetailsInfoUiState.value = PopmapDetailsInfo(
                id = popMapDetails.id ?: throw IllegalStateException("id is null"),
                uid = popMapDetails.uid!!,
                langId = popMapDetails.language_id!!,
                name = popMapDetails.name!!,
                picture = popMapDetails.header?.image?.file.orEmpty(),
                version = popMapDetails.version.orEmpty()
            )

            // Fetches download status for the retrieved pop map details
            val status = sdk.fetchLocalDownloadStatus(popMapDetails)

            // Updates UI with download status
            updateDetailsStatus(popMapDetails, status)
        }
    }

    // Fetches account information and associated pop maps
    private fun fetchAccount() {
        sdkScope.launch {
            handleError {
                // Fetches account information from the server
                val loginResponse = sdk.fetchAccount(username = userName, password = passCode)

                // Retrieves account information from the login response
                val account = loginResponse.account ?: throw IllegalStateException("No accounts")
                accountUiState.value = createAccountInfo(account)

                // Retrieves pop maps associated with the account from the login response
                val popmaps = loginResponse.pop_maps ?: throw IllegalStateException("No popmaps")
                popmapInfoListUiState.value = createPopMapInfoList(popmaps)

                val starpoints =
                    sdk.fetchStarPoints(accountId = account.id, groupId = account.group_id)
                val adverts =
                    sdk.fetchAdvertSpots(accountId = account.id, groupId = account.group_id)

                val style = sdk.fetchMapStyle(accountId = account.id, groupId = account.group_id)

                val marketPlaces = sdk.fetchMarketPlaces(
                    accountId = account.id,
                    groupId = account.group_id,
                    languageId = 1
                )
            }
        }
    }

    // Downloads pop map details and associated files
    private fun downloadPopMapDetails(info: PopmapDetailsInfo) {
        sdkScope.launch {
            handleError {
                val accountInfo = accountUiState.value
                // Fetches pop map details from the server or local
                val popMapDetails =
                    try {
                        sdk.fetchLocalPopMapDetails(info.uid, info.langId)
                    } catch (e: Exception) {
                        sdk.fetchPopMapDetailsServer(
                            accountId = accountInfo?.id ?: -1,
                            groupId = accountInfo?.groupId ?: -1,
                            popMapId = info.id,
                            languageId = info.langId,
                            version = info.version
                        )
                    }
                // Fetches downloadables associated with the pop map details
                sdk.fetchPopMapDownloadables(popMapDetailsServer = popMapDetails) { status ->
                    // Updates UI with download status
                    updateDetailsStatus(popMapDetails, status)
                }
            }
        }
    }

    // Updates UI with download status
    private fun updateDetailsStatus(
        popMapDetailsServer: PopMapDetailsServer,
        status: DownloadStatus
    ) {
        if (popMapDetailsServer.uid != status.uid) return
        val downloadedSize = status.downloadedSize
        val sizeToDownload = status.sizeToDownload
        val downloadState = status.downloadState

        // Calculates download percentage
        val percentage = status.getPercentage()

        // Updates UI based on download state
        when (downloadState) {
            DownloadState.DOWNLOADING -> {
                // Updates UI for downloading state
                popmapDetailsInfoUiState.value?.copy(
                    percentage = percentage,
                    downloadedSize = downloadedSize,
                    sizeToDownload = sizeToDownload,
                    downloadState = downloadState
                )?.let { info ->
                    popmapDetailsInfoUiState.value = info
                }
            }

            DownloadState.NEED_UPDATE,
            DownloadState.DOWNLOADED_LIGHT,
            DownloadState.DOWNLOADED_FULL -> {
                // Retrieves downloaded files and updates UI
                val files = mutableListOf<File>().apply {
                    add(
                        sdk.fetchLocalFile(
                            uid = popMapDetailsServer.uid.orEmpty(),
                            anyUrl = popMapDetailsServer.header?.audio?.file.orEmpty()
                        )
                    )
                    add(
                        sdk.fetchLocalFile(
                            uid = popMapDetailsServer.uid.orEmpty(),
                            anyUrl = popMapDetailsServer.header?.image?.file.orEmpty()
                        )

                    )
                    addAll(
                        popMapDetailsServer.levels.orEmpty()
                            .flatMap { it.points.orEmpty() }
                            .flatMap { it.contents?.audios.orEmpty() }
                            .filter { it.file != null }
                            .map {
                                sdk.fetchLocalFile(
                                    uid = popMapDetailsServer.uid.orEmpty(),
                                    anyUrl = it.file!!
                                )
                            })
                }

                // Updates UI for downloaded state
                popmapDetailsInfoUiState.value?.copy(
                    percentage = percentage,
                    downloadState = status.downloadState,
                    downloadedSize = status.downloadedSize,
                    sizeToDownload = status.sizeToDownload,
                    downloadedFiles = files
                )?.let { info ->
                    popmapDetailsInfoUiState.value = info
                }
            }

            DownloadState.NONE -> {
                // Updates UI for none state
                popmapDetailsInfoUiState.value?.copy(
                    percentage = percentage,
                    downloadedSize = status.downloadedSize,
                    sizeToDownload = status.sizeToDownload,
                    downloadState = status.downloadState
                )?.let { info ->
                    popmapDetailsInfoUiState.value = info
                }
            }
        }
    }

    // Cancels all running coroutines related to the selected pop map
    private fun closeChosenPopMap() {
        sdkScope.coroutineContext.cancelChildren()
        popmapDetailsInfoUiState.value = null
    }

    private inline fun <R> handleError(block: () -> R) {
        try {
            block()
        } catch (e: Exception) {
            Log.e("sdk sample", e.localizedMessage.orEmpty())
            Toast.makeText(this, e.message, Toast.LENGTH_SHORT).show()
        }
    }
}

@Preview(showBackground = true)
@Composable
fun PopguideSdkPreview() {
    PopguideSdkTheme {
        Column {
            Text(text = "PopGuideSdk", Modifier.padding(16.dp))
            CredentialsInfo(name = "user", pass = "pass", Modifier.padding(16.dp))
            AccountInfo(
                name = "operator name",
                logo = "operator logo",
                modifier = Modifier.padding(16.dp)
            )
            PopmapInfoList(
                popmaps = listOf(
                    PopMapInfo(
                        id = 1, uid = "uid", name = "name", coverPicture = "picture",
                        langPacks = listOf(LangPackInfo(1, "en", "flag")),
                        version = "${System.currentTimeMillis()}"
                    ), PopMapInfo(
                        id = 1, uid = "uid", name = "name", coverPicture = "picture",
                        langPacks = listOf(LangPackInfo(1, "en", "flag")),
                        version = "${System.currentTimeMillis()}"
                    )
                ), { _, _ -> })
            Spacer(modifier = Modifier.weight(1f))
            Button(
                modifier = Modifier.fillMaxWidth(0.8f),
                onClick = { }
            ) { Text(text = "Fetch account") }
        }
    }
}