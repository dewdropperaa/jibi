package com.example.myapplication.ui.dashboard

import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.example.myapplication.MasroufiApplication
import com.example.myapplication.R
import com.example.myapplication.databinding.FragmentDashboardBinding
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

class DashboardFragment : Fragment() {

    private var _binding: FragmentDashboardBinding? = null
    private val binding get() = _binding!!

    private val viewModel: DashboardViewModel by viewModels {
        val app = requireActivity().application as MasroufiApplication
        DashboardViewModelFactory(app.database.transactionDao(), app.database.categoryDao())
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val monthLabel = LocalDate.now().format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.FRENCH))
        binding.tvCurrentMonth.text = monthLabel.replaceFirstChar { it.uppercase() }

        binding.btnAddTransaction.setOnClickListener {
            findNavController().navigate(R.id.transactionsListFragment)
        }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    binding.tvBalance.text = String.format("%.2f DT", state.balance)
                    binding.tvTotalIncome.text = String.format("%.2f DT", state.totalIncome)
                    binding.tvTotalExpenses.text = String.format("%.2f DT", state.totalExpenses)

                    binding.tvBalance.setTextColor(
                        if (state.isNegative) ContextCompat.getColor(requireContext(), R.color.md_expense_red)
                        else ContextCompat.getColor(requireContext(), R.color.md_primary)
                    )

                    if (state.isNegative) {
                        binding.cardAlert.visibility = View.VISIBLE
                        binding.tvAlertMessage.text = "Votre solde est de ${String.format("%.2f", state.balance)} DT"
                    } else {
                        binding.cardAlert.visibility = View.GONE
                    }

                    renderBudgetAlerts(state.categoryAlerts)
                }
            }
        }
    }

    private fun renderBudgetAlerts(alerts: List<CategoryAlert>) {
        binding.layoutBudgetAlerts.removeAllViews()
        if (alerts.isEmpty()) {
            val tv = TextView(requireContext())
            tv.text = "✅ Aucun dépassement de budget ce mois"
            tv.setTextColor(ContextCompat.getColor(requireContext(), R.color.md_on_surface))
            tv.textSize = 13f
            binding.layoutBudgetAlerts.addView(tv)
            return
        }
        alerts.forEach { alert ->
            val card = layoutInflater.inflate(R.layout.item_budget_alert, binding.layoutBudgetAlerts, false)
            card.findViewById<TextView>(R.id.tvBudgetCategory).text = alert.categoryName
            card.findViewById<TextView>(R.id.tvBudgetAmount).text =
                "${String.format("%.0f", alert.spent)} / ${String.format("%.0f", alert.limit)} DT"
            val progress = ((alert.spent / alert.limit) * 100).toInt().coerceAtMost(100)
            card.findViewById<ProgressBar>(R.id.progressBudget).progress = progress
            binding.layoutBudgetAlerts.addView(card)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
