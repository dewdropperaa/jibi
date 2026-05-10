package com.jibi.ui.recurring

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.recyclerview.widget.LinearLayoutManager
import com.jibi.MasroufiApplication
import com.jibi.R
import com.jibi.data.dao.RecurringExpenseDao
import com.jibi.data.dao.TransactionDao
import com.jibi.data.entities.RecurringExpense
import com.jibi.data.entities.Transaction
import com.jibi.data.entities.TransactionType
import com.jibi.databinding.FragmentRecurringExpensesBinding
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID

// ViewModel
class RecurringViewModel(
    private val recurringDao: RecurringExpenseDao,
    private val transactionDao: TransactionDao
) : ViewModel() {

    val recurringExpenses: StateFlow<List<RecurringExpense>> = recurringDao.getAllRecurringExpenses()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun insert(expense: RecurringExpense) = viewModelScope.launch {
        recurringDao.insertRecurringExpense(expense)
        applyIfDue(expense)
    }

    fun delete(expense: RecurringExpense) = viewModelScope.launch {
        recurringDao.deleteRecurringExpense(expense.id)
    }

    private suspend fun applyIfDue(expense: RecurringExpense) {
        val today = LocalDate.now()
        val todayStr = today.format(DateTimeFormatter.ISO_LOCAL_DATE)
        val monthPrefix = today.format(DateTimeFormatter.ofPattern("yyyy-MM"))
        if (today.dayOfMonth == expense.dayOfMonth && expense.lastAppliedDate?.startsWith(monthPrefix) != true) {
            transactionDao.insertTransaction(
                Transaction(
                    id = UUID.randomUUID().toString(),
                    amount = expense.amount,
                    categoryId = expense.categoryId,
                    date = todayStr,
                    note = "Auto: ${expense.name}",
                    type = TransactionType.EXPENSE
                )
            )
            recurringDao.updateRecurringExpense(expense.copy(lastAppliedDate = todayStr))
        }
    }
}

class RecurringViewModelFactory(
    private val recurringDao: RecurringExpenseDao,
    private val transactionDao: TransactionDao
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return RecurringViewModel(recurringDao, transactionDao) as T
    }
}

// Fragment
class RecurringExpensesFragment : Fragment() {

    private var _binding: FragmentRecurringExpensesBinding? = null
    private val binding get() = _binding!!

    private val viewModel: RecurringViewModel by viewModels {
        val app = requireActivity().application as MasroufiApplication
        RecurringViewModelFactory(app.database.recurringExpenseDao(), app.database.transactionDao())
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentRecurringExpensesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val adapter = RecurringAdapter { expense -> viewModel.delete(expense) }
        binding.rvRecurring.layoutManager = LinearLayoutManager(requireContext())
        binding.rvRecurring.adapter = adapter

        binding.fabAddRecurring.setOnClickListener { showAddDialog() }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.recurringExpenses.collect { list ->
                    adapter.submitList(list)
                }
            }
        }
    }

    private fun showAddDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_add_recurring, null)
        val etName = dialogView.findViewById<TextInputEditText>(R.id.etChargeName)
        val etAmount = dialogView.findViewById<TextInputEditText>(R.id.etChargeAmount)
        val etDay = dialogView.findViewById<TextInputEditText>(R.id.etChargeDay)
        val etCategory = dialogView.findViewById<TextInputEditText>(R.id.etChargeCategory)

        MaterialAlertDialogBuilder(requireContext())
            .setTitle("Ajouter une charge fixe")
            .setView(dialogView)
            .setNegativeButton("Annuler") { dialog, _ -> dialog.dismiss() }
            .setPositiveButton("Ajouter") { _, _ ->
                val name = etName.text?.toString()?.trim() ?: ""
                val amount = etAmount.text?.toString()?.toDoubleOrNull() ?: 0.0
                val day = etDay.text?.toString()?.toIntOrNull() ?: 1
                val cat = etCategory.text?.toString()?.trim().takeIf { !it.isNullOrEmpty() } ?: "Charges"
                if (name.isNotEmpty() && amount > 0) {
                    viewModel.insert(
                        RecurringExpense(
                            id = UUID.randomUUID().toString(),
                            name = name,
                            amount = amount,
                            categoryId = cat,
                            dayOfMonth = day.coerceIn(1, 31)
                        )
                    )
                }
            }
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
