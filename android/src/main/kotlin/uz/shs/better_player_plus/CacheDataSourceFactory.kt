package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.FileDataSource
import androidx.media3.datasource.cache.CacheDataSink
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter

internal class CacheDataSourceFactory(
    private val context: Context,
    private val maxCacheSize: Long,
    private val maxFileSize: Long,
    upstreamDataSource: DataSource.Factory?
) : DataSource.Factory {
    private var defaultDatasourceFactory: DefaultDataSource.Factory? = null
    override fun createDataSource(): CacheDataSource {
        val betterPlayerCache = BetterPlayerCache.createCache(context, maxCacheSize)
            ?: throw IllegalStateException("Cache can't be null.")

        return CacheDataSource.Factory()
            .setCache(betterPlayerCache)
            .setUpstreamDataSourceFactory(defaultDatasourceFactory)
            .setCacheReadDataSourceFactory(FileDataSource.Factory())
            .setCacheWriteDataSinkFactory(CacheDataSink.Factory().setCache(betterPlayerCache).setFragmentSize(maxFileSize))
            .setFlags(CacheDataSource.FLAG_BLOCK_ON_CACHE or CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
            .createDataSource()
    }

    init {
        val bandwidthMeter = DefaultBandwidthMeter.Builder(context).build()
        upstreamDataSource?.let {
            defaultDatasourceFactory = DefaultDataSource.Factory(context, upstreamDataSource)
            defaultDatasourceFactory?.setTransferListener(bandwidthMeter)
        }
    }
}