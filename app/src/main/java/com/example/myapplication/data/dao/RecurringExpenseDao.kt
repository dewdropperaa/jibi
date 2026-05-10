package com.jibi.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.jibi.data.entities.RecurringExpense
import kotlinx.coroutines.flow.Flow

@Dao
interface RecurringExpenseDao {
    @Query("SELECT * FROM recurring_expenses ORDER BY dayOfMonth ASC")
    fun getAllRecurringExpenses(): Flow<List<RecurringExpense>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRecurringExpense(expense: RecurringExpense)

    @Update
    suspend fun updateRecurringExpense(expense: RecurringExpense)

    @Query("DELETE FROM recurring_expenses WHERE id = :id")
    suspend fun deleteRecurringExpense(id: String)
}
