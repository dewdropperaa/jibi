package com.jibi.ui.recurring

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.jibi.data.entities.RecurringExpense
import com.jibi.databinding.ItemRecurringBinding

class RecurringAdapter(
    private val onDelete: (RecurringExpense) -> Unit,
) : ListAdapter<RecurringExpense, RecurringAdapter.ViewHolder>(DIFF) {
    companion object {
        private val DIFF =
            object : DiffUtil.ItemCallback<RecurringExpense>() {
                override fun areItemsTheSame(
                    a: RecurringExpense,
                    b: RecurringExpense,
                ) = a.id == b.id

                override fun areContentsTheSame(
                    a: RecurringExpense,
                    b: RecurringExpense,
                ) = a == b
            }
    }

    inner class ViewHolder(val binding: ItemRecurringBinding) :
        RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(
        parent: ViewGroup,
        viewType: Int,
    ): ViewHolder {
        val binding = ItemRecurringBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(
        holder: ViewHolder,
        position: Int,
    ) {
        val exp = getItem(position)
        with(holder.binding) {
            tvRecurringName.text = exp.name
            tvRecurringDay.text = "Chaque ${exp.dayOfMonth} du mois • ${exp.categoryId}"
            tvRecurringAmount.text = "- ${String.format("%.2f", exp.amount)} DT"
            btnDeleteRecurring.setOnClickListener { onDelete(exp) }
        }
    }
}
