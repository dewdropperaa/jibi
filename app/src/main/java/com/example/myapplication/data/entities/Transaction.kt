package com.jibi.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

enum class TransactionType {
    EXPENSE,
    INCOME,
}

@Entity(tableName = "transactions")
data class Transaction(
    @PrimaryKey
    val id: String,
    val amount: Double,
    val categoryId: String,
    val date: String,
    val note: String? = null,
    val type: TransactionType,
    val receiptPhotoPath: String? = null,
)
