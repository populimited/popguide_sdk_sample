package io.populi.sdkapp.uimodel

import io.populi.sdk.server.model.response.loginHandShakeResponses.model.PopMapServer

data class PopMapInfo(
    val id: Int,
    val uid: String,
    val name: String,
    val coverPicture: String,
    val langPacks: List<LangPackInfo>
)

data class LangPackInfo(val id: Int, val langName: String, val flagUrl: String)

fun createPopMapInfoList(popmapServer: List<PopMapServer>): List<PopMapInfo> {
    return popmapServer.map { popmapServer ->
        PopMapInfo(
            id = popmapServer.id,
            uid = popmapServer.uid.orEmpty(),
            name = popmapServer.name.orEmpty(),
            coverPicture = popmapServer.cover_picture.orEmpty(),
            langPacks = popmapServer.packages?.map {
                LangPackInfo(
                    id = it.language_id,
                    langName = it.language_name.orEmpty(),
                    flagUrl = it.language_flag.orEmpty()
                )
            }
                .orEmpty()
        )
    }
}