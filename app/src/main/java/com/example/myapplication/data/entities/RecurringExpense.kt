package com.jibi.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "recurring_expenses")
data class RecurringExpense(
    @PrimaryKey
    val id: String,
    val name: String,
    val amount: Double,
    val categoryId: String,
    val dayOfMonth: Int,
    val lastAppliedDate: String? = null
)
