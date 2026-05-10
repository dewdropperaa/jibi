package com.jibi.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.jibi.data.dao.CategoryDao
import com.jibi.data.dao.TransactionDao

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
