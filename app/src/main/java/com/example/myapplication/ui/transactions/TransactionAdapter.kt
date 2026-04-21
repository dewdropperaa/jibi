package com.example.myapplication.ui.transactions

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.myapplication.R
import com.example.myapplication.data.entities.Transaction
import com.example.myapplication.data.entities.TransactionType
import com.example.myapplication.databinding.ItemTransactionBinding

class TransactionAdapter(
    private val onEdit: (Transaction) -> Unit,
    private val onDelete: (Transaction) -> Unit
) : ListAdapter<Transaction, TransactionAdapter.ViewHolder>(DIFF) {

    companion object {
        private val DIFF = object : DiffUtil.ItemCallback<Transaction>() {
            override fun areItemsTheSame(a: Transaction, b: Transaction) = a.id == b.id
            override fun areContentsTheSame(a: Transaction, b: Transaction) = a == b
        }
    }

    inner class ViewHolder(val binding: ItemTransactionBinding) :
        RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemTransactionBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val tx = getItem(position)
        with(holder.binding) {
            tvTransactionCategory.text = tx.categoryId
            tvTransactionNote.text = tx.note ?: ""
            tvTransactionDate.text = tx.date

            if (tx.type == TransactionType.INCOME) {
                tvTransactionAmount.text = "+ ${String.format("%.2f", tx.amount)} DT"
                tvTransactionAmount.setTextColor(ContextCompat.getColor(root.context, R.color.md_income_green))
                tvCategoryIcon.text = "💰"
            } else {
                tvTransactionAmount.text = "- ${String.format("%.2f", tx.amount)} DT"
                tvTransactionAmount.setTextColor(ContextCompat.getColor(root.context, R.color.md_expense_red))
                tvCategoryIcon.text = "💸"
            }

            btnEdit.setOnClickListener { onEdit(tx) }
            btnDelete.setOnClickListener { onDelete(tx) }
        }
    }
}
