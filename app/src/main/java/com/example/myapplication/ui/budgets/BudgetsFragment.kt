package com.jibi.ui.budgets

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.jibi.MasroufiApplication
import com.jibi.R
import com.jibi.databinding.FragmentBudgetsBinding
import com.jibi.ui.transactions.TransactionsViewModelFactory
import com.jibi.ui.transactions.TransactionsViewModel
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import kotlinx.coroutines.launch

class BudgetsFragment : Fragment() {

    private var _binding: FragmentBudgetsBinding? = null
    private val binding get() = _binding!!

    private val viewModel: TransactionsViewModel by viewModels {
        val app = requireActivity().application as MasroufiApplication
        TransactionsViewModelFactory(app.database.transactionDao(), app.database.categoryDao())
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentBudgetsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    viewModel.categories.collect { categories ->
                        viewModel.transactions.collect { transactions ->
                            renderBudgets(categories, transactions)
                        }
                    }
                }
            }
        }
    }

    private fun renderBudgets(
        categories: List<com.jibi.data.entities.Category>,
        transactions: List<com.jibi.data.entities.Transaction>
    ) {
        binding.layoutBudgetList.removeAllViews()
        categories.filter { it.budgetLimit != null || true }.forEach { cat ->
            val card = layoutInflater.inflate(R.layout.item_budget_card, binding.layoutBudgetList, false)
            val spent = transactions.filter {
                it.categoryId == cat.id && it.type == com.jibi.data.entities.TransactionType.EXPENSE
            }.sumOf { it.amount }

            card.findViewById<TextView>(R.id.tvBudgetCardCategory).text = "${cat.name}"
            val limit = cat.budgetLimit ?: 0.0
            card.findViewById<TextView>(R.id.tvBudgetCardSpent).text =
                "${String.format("%.2f", spent)} / ${String.format("%.2f", limit)} DT"

            val progress = if (limit > 0) ((spent / limit) * 100).toInt().coerceAtMost(100) else 0
            card.findViewById<ProgressBar>(R.id.progressBudgetCard).progress = progress

            card.findViewById<TextView>(R.id.tvSetBudget).setOnClickListener {
                showSetBudgetDialog(cat)
            }
            binding.layoutBudgetList.addView(card)
        }
    }

    private fun showSetBudgetDialog(cat: com.jibi.data.entities.Category) {
        val dialogView = layoutInflater.inflate(R.layout.dialog_set_budget, null)
        val etLimit = dialogView.findViewById<TextInputEditText>(R.id.etBudgetLimit)
        etLimit.setText(cat.budgetLimit?.toString() ?: "")

        MaterialAlertDialogBuilder(requireContext())
            .setTitle("Plafond – ${cat.name}")
            .setView(dialogView)
            .setNegativeButton("Annuler", null)
            .setPositiveButton("Enregistrer") { _, _ ->
                val limit = etLimit.text?.toString()?.toDoubleOrNull()
                val updated = cat.copy(budgetLimit = limit)
                viewLifecycleOwner.lifecycleScope.launch {
                    viewModel.categoryDao.updateCategory(updated)
                }
            }
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
