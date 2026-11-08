package com.infintykey.tager2

import android.app.Application
import androidx.work.Configuration

/**
 * Supplies WorkManager configuration for on-demand initialization.
 * The default AndroidX Startup initializer is removed from the manifest so
 * WorkManager's database is not opened before the first Activity can start.
 */
class Tager2Application : Application(), Configuration.Provider {
    override fun getWorkManagerConfiguration(): Configuration =
        Configuration.Builder().build()
}
