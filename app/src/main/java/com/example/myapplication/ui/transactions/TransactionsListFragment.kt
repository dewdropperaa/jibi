package com.jibi.ui.transactions

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.os.bundleOf
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.jibi.MasroufiApplication
import com.jibi.R
import com.jibi.databinding.FragmentTransactionsListBinding
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import kotlinx.coroutines.launch

class TransactionsListFragment : Fragment() {

    private var _binding: FragmentTransactionsListBinding? = null
    private val binding get() = _binding!!

    private val viewModel: TransactionsViewModel by viewModels {
        val app = requireActivity().application as MasroufiApplication
        TransactionsViewModelFactory(app.database.transactionDao(), app.database.categoryDao())
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentTransactionsListBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val adapter = TransactionAdapter(
            onEdit = { tx ->
                val bundle = bundleOf("transactionId" to tx.id)
                findNavController().navigate(R.id.addTransactionFragment, bundle)
            },
            onDelete = { tx ->
                MaterialAlertDialogBuilder(requireContext())
                    .setTitle("Supprimer")
                    .setMessage("Confirmer la suppression de cette transaction ?")
                    .setNegativeButton("Annuler", null)
                    .setPositiveButton("Supprimer") { _, _ -> viewModel.delete(tx) }
                    .show()
            }
        )

        binding.rvTransactions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvTransactions.adapter = adapter

        binding.fabAddTransaction.setOnClickListener {
            findNavController().navigate(R.id.addTransactionFragment)
        }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.transactions.collect { list ->
                    adapter.submitList(list)
                }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
