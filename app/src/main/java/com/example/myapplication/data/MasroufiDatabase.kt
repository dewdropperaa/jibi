package com.example.myapplication.data

import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.RoomDatabase
import com.example.myapplication.data.entities.Category
import com.example.myapplication.data.entities.RecurringExpense
import com.example.myapplication.data.entities.Transaction
import com.example.myapplication.data.dao.CategoryDao
import com.example.myapplication.data.dao.RecurringExpenseDao
import com.example.myapplication.data.dao.TransactionDao

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
