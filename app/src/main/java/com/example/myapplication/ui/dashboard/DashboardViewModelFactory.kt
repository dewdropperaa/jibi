package com.example.myapplication.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.myapplication.data.dao.CategoryDao
import com.example.myapplication.data.dao.TransactionDao

class DashboardViewModelFactory(
    private val transactionDao: TransactionDao,
    private val categoryDao: CategoryDao
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(DashboardViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return DashboardViewModel(transactionDao, categoryDao) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
