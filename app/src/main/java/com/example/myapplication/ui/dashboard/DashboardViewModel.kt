package com.example.myapplication.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.myapplication.data.dao.CategoryDao
import com.example.myapplication.data.dao.TransactionDao
import com.example.myapplication.data.entities.TransactionType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.time.LocalDate
import java.time.format.DateTimeFormatter

data class CategoryAlert(val categoryName: String, val spent: Double, val limit: Double)

data class DashboardUiState(
    val balance: Double = 0.0,
    val totalIncome: Double = 0.0,
    val totalExpenses: Double = 0.0,
    val isNegative: Boolean = false,
    val categoryAlerts: List<CategoryAlert> = emptyList()
)

class DashboardViewModel(
    private val transactionDao: TransactionDao,
    private val categoryDao: CategoryDao
) : ViewModel() {

    private val currentMonthPrefix: String
        get() {
            val now = LocalDate.now()
            return now.format(DateTimeFormatter.ofPattern("yyyy-MM"))
        }

    val uiState: StateFlow<DashboardUiState> = combine(
        transactionDao.getTransactionsByMonth(currentMonthPrefix),
        categoryDao.getAllCategories()
    ) { transactions, categories ->
        val income = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        val balance = income - expenses

        val alerts = categories.filter { it.budgetLimit != null && it.budgetLimit > 0 }.mapNotNull { cat ->
            val spent = transactions.filter { it.type == TransactionType.EXPENSE && it.categoryId == cat.id }.sumOf { it.amount }
            if (spent >= cat.budgetLimit!!) CategoryAlert(cat.name, spent, cat.budgetLimit) else null
        }

        DashboardUiState(
            balance = balance,
            totalIncome = income,
            totalExpenses = expenses,
            isNegative = balance < 0,
            categoryAlerts = alerts
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = DashboardUiState()
    )
}
