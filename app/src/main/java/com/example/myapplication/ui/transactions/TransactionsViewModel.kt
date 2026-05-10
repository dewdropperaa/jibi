package com.jibi.ui.transactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.jibi.data.dao.CategoryDao
import com.jibi.data.dao.TransactionDao
import com.jibi.data.entities.Category
import com.jibi.data.entities.Transaction
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class TransactionsViewModel(
    val transactionDao: TransactionDao,
    val categoryDao: CategoryDao
) : ViewModel() {

    val transactions: StateFlow<List<Transaction>> = transactionDao.getAllTransactions()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val categories: StateFlow<List<Category>> = categoryDao.getAllCategories()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun delete(transaction: Transaction) = viewModelScope.launch {
        transactionDao.deleteTransaction(transaction.id)
    }

    fun insert(transaction: Transaction) = viewModelScope.launch {
        transactionDao.insertTransaction(transaction)
    }

    fun update(transaction: Transaction) = viewModelScope.launch {
        transactionDao.updateTransaction(transaction)
    }

    fun insertCategory(category: Category) = viewModelScope.launch {
        categoryDao.insertCategory(category)
    }

    suspend fun getById(id: String): Transaction? = transactionDao.getTransactionById(id)
}

class TransactionsViewModelFactory(
    private val transactionDao: TransactionDao,
    private val categoryDao: CategoryDao
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(TransactionsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return TransactionsViewModel(transactionDao, categoryDao) as T
        }
        throw IllegalArgumentException("Unknown ViewModel")
    }
}
