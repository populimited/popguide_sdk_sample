package io.populi.sdkapp.uimodel

import io.populi.sdk.server.model.response.loginHandShakeResponses.model.AccountServer

data class AccountInfo(
    val id: Int,
    val name: String,
    val logo: String,
    val groupId: Long? = null
)


fun createAccountInfo(account: AccountServer): AccountInfo {
    return AccountInfo(
        id = account.id,
        name = account.operator_name.orEmpty(),
        logo = account.branding_data?.logo.orEmpty(),
        groupId = account.group_id
    )
}