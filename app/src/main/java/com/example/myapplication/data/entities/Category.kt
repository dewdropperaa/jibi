package com.example.myapplication.data.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "categories")
data class Category(
    @PrimaryKey
    val id: String,
    val name: String,
    val icon: String,
    val color: String,
    val isCustom: Boolean = false,
    val budgetLimit: Double? = null
)
