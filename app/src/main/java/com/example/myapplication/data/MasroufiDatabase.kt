package com.jibi.data

import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.RoomDatabase
import com.jibi.data.entities.Category
import com.jibi.data.entities.RecurringExpense
import com.jibi.data.entities.Transaction
import com.jibi.data.dao.CategoryDao
import com.jibi.data.dao.RecurringExpenseDao
import com.jibi.data.dao.TransactionDao

@Database(
    entities = [Transaction::class, Category::class, RecurringExpense::class],
    version = 2,
    exportSchema = false
)
abstract class MasroufiDatabase : RoomDatabase() {
    abstract fun transactionDao(): TransactionDao
    abstract fun categoryDao(): CategoryDao
    abstract fun recurringExpenseDao(): RecurringExpenseDao
}
