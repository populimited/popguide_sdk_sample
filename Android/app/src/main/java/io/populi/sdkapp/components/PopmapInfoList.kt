package io.populi.sdkapp.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import io.populi.sdkapp.uimodel.LangPackInfo
import io.populi.sdkapp.uimodel.PopMapInfo

@Composable
fun PopmapInfoList(
    popmaps: List<PopMapInfo>,
    itemClick: (PopMapInfo, LangPackInfo) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier) {
        LazyColumn {
            items(popmaps) { popmap ->
                Column {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.padding(10.dp)
                    ) {
                        Text(text = popmap.name, Modifier.weight(1f))
                        SubcomposeAsyncImage(
                            model = popmap.coverPicture,
                            contentDescription = "logo",
                            modifier = Modifier
                                .height(50.dp)
                                .width(100.dp),
                            contentScale = ContentScale.Crop
                        )
                    }
                    LazyRow {
                        items(popmap.langPacks) { langPack ->
                            SubcomposeAsyncImage(
                                model = langPack.flagUrl,
                                contentDescription = "flag",
                                modifier = Modifier
                                    .height(35.dp)
                                    .width(35.dp)
                                    .padding(2.dp)
                                    .clickable {
                                        itemClick.invoke(
                                            popmap,
                                            langPack
                                        )
                                    },
                                contentScale = ContentScale.Crop
                            )
                        }
                    }
                }
            }
        }
    }
}