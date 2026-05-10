package com.jibi

import android.app.Application
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.jibi.data.MasroufiDatabase

class MasroufiApplication : Application() {
    val database: MasroufiDatabase by lazy {
        Room.databaseBuilder(
            this,
            MasroufiDatabase::class.java,
            "masroufi_database",
        )
            .addMigrations(MIGRATION_1_2)
            .build()
    }

    companion object {
        val MIGRATION_1_2 =
            object : Migration(1, 2) {
                override fun migrate(db: SupportSQLiteDatabase) {
                    db.execSQL("ALTER TABLE transactions ADD COLUMN receiptPhotoPath TEXT")
                }
            }
    }
}
