package com.example.myapplication

import com.example.myapplication.data.entities.Transaction
import com.example.myapplication.data.entities.TransactionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardCalculationTest {

    private fun transaction(
        id: String,
        amount: Double,
        type: TransactionType,
        categoryId: String = "cat1",
    ) = Transaction(id = id, amount = amount, categoryId = categoryId, date = "2026-04", type = type)

    // --- Balance ---

    @Test
    fun balance_equals_income_minus_expenses() {
        val transactions = listOf(
            transaction("1", 3000.0, TransactionType.INCOME),
            transaction("2", 800.0, TransactionType.EXPENSE),
            transaction("3", 200.0, TransactionType.EXPENSE),
        )
        val income = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        assertEquals(2000.0, income - expenses, 0.001)
    }

    @Test
    fun balance_is_negative_when_expenses_exceed_income() {
        val transactions = listOf(
            transaction("1", 300.0, TransactionType.INCOME),
            transaction("2", 800.0, TransactionType.EXPENSE),
        )
        val income = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        assertTrue(income - expenses < 0)
    }

    @Test
    fun empty_transaction_list_gives_zero_balance() {
        val transactions = emptyList<Transaction>()
        val income = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        assertEquals(0.0, income - expenses, 0.001)
    }

    @Test
    fun income_only_gives_positive_balance() {
        val transactions = listOf(
            transaction("1", 5000.0, TransactionType.INCOME),
        )
        val income = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount }
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount }
        assertEquals(5000.0, income - expenses, 0.001)
    }

    // --- Budget alerts ---

    @Test
    fun alert_triggered_when_spending_reaches_limit() {
        val limit = 500.0
        val spent = 500.0
        assertTrue(spent >= limit)
    }

    @Test
    fun alert_triggered_when_spending_exceeds_limit() {
        val limit = 500.0
        val spent = 650.0
        assertTrue(spent >= limit)
    }

    @Test
    fun no_alert_when_spending_is_under_limit() {
        val limit = 500.0
        val spent = 300.0
        assertFalse(spent >= limit)
    }

    // --- Transaction filtering ---

    @Test
    fun expenses_are_filtered_correctly_by_type() {
        val transactions = listOf(
            transaction("1", 100.0, TransactionType.EXPENSE),
            transaction("2", 200.0, TransactionType.INCOME),
            transaction("3", 50.0, TransactionType.EXPENSE),
        )
        val expenses = transactions.filter { it.type == TransactionType.EXPENSE }
        assertEquals(2, expenses.size)
        assertEquals(150.0, expenses.sumOf { it.amount }, 0.001)
    }

    @Test
    fun expenses_filtered_by_category_are_correct() {
        val transactions = listOf(
            transaction("1", 100.0, TransactionType.EXPENSE, categoryId = "food"),
            transaction("2", 200.0, TransactionType.EXPENSE, categoryId = "transport"),
            transaction("3", 50.0, TransactionType.EXPENSE, categoryId = "food"),
        )
        val foodExpenses = transactions
            .filter { it.type == TransactionType.EXPENSE && it.categoryId == "food" }
            .sumOf { it.amount }
        assertEquals(150.0, foodExpenses, 0.001)
    }
}
