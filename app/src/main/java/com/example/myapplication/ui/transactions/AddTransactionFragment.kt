package com.jibi.ui.transactions

import android.app.DatePickerDialog
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import com.jibi.MasroufiApplication
import com.jibi.R
import com.jibi.data.entities.Category
import com.jibi.data.entities.Transaction
import com.jibi.data.entities.TransactionType
import com.jibi.databinding.FragmentAddTransactionBinding
import com.google.android.material.snackbar.Snackbar
import kotlinx.coroutines.launch
import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.UUID

class AddTransactionFragment : Fragment() {

    private var _binding: FragmentAddTransactionBinding? = null
    private val binding get() = _binding!!

    private val viewModel: TransactionsViewModel by viewModels {
        val app = requireActivity().application as MasroufiApplication
        TransactionsViewModelFactory(app.database.transactionDao(), app.database.categoryDao())
    }

    private var photoUri: Uri? = null
    private var photoPath: String? = null
    private var editingTransactionId: String? = null
    private var categoriesList: List<Category> = emptyList()

    private val takePicture = registerForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) {
            binding.tvPhotoStatus.visibility = View.VISIBLE
            binding.tvPhotoStatus.text = getString(R.string.photo_attachee)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentAddTransactionBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        editingTransactionId = arguments?.getString("transactionId")

        // Set today's date by default
        binding.etDate.setText(LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd")))

        // Date picker
        binding.etDate.setOnClickListener { showDatePicker() }
        binding.tilDate.setEndIconOnClickListener { showDatePicker() }

        // Type toggle – default to EXPENSE
        binding.toggleTransactionType.check(R.id.btnExpense)

        // Camera
        binding.btnCamera.setOnClickListener { launchCamera() }

        // Observe categories
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.categories.collect { cats ->
                categoriesList = cats
                val names = cats.map { it.name }
                val adapter = ArrayAdapter(requireContext(), android.R.layout.simple_dropdown_item_1line, names)
                binding.actvCategorie.setAdapter(adapter)
            }
        }

        // Pre-fill if editing
        if (editingTransactionId != null) {
            viewLifecycleOwner.lifecycleScope.launch {
                val tx = viewModel.getById(editingTransactionId!!)
                if (tx != null) prefillForm(tx)
            }
        }

        binding.btnSave.setOnClickListener { saveTransaction() }
    }

    private fun showDatePicker() {
        val cal = Calendar.getInstance()
        DatePickerDialog(requireContext(), { _, y, m, d ->
            binding.etDate.setText(String.format("%04d-%02d-%02d", y, m + 1, d))
        }, cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH)).show()
    }

    private fun launchCamera() {
        val dir = File(requireContext().cacheDir, "photos").apply { mkdirs() }
        val file = File(dir, "receipt_${System.currentTimeMillis()}.jpg")
        photoPath = file.absolutePath
        photoUri = FileProvider.getUriForFile(
            requireContext(),
            "${requireContext().packageName}.provider",
            file
        )
        takePicture.launch(photoUri)
    }

    private fun prefillForm(tx: Transaction) {
        binding.etMontant.setText(tx.amount.toString())
        binding.etDate.setText(tx.date)
        binding.etDescription.setText(tx.note ?: "")
        val catName = categoriesList.find { it.id == tx.categoryId }?.name ?: tx.categoryId
        binding.actvCategorie.setText(catName, false)
        if (tx.type == TransactionType.INCOME) binding.toggleTransactionType.check(R.id.btnIncome)
        else binding.toggleTransactionType.check(R.id.btnExpense)
        if (tx.receiptPhotoPath != null) {
            photoPath = tx.receiptPhotoPath
            binding.tvPhotoStatus.visibility = View.VISIBLE
            binding.tvPhotoStatus.text = getString(R.string.photo_attachee)
        }
    }

    private fun saveTransaction() {
        val amountStr = binding.etMontant.text?.toString()?.trim()
        val date = binding.etDate.text?.toString()?.trim()
        val catName = binding.actvCategorie.text?.toString()?.trim()
        val note = binding.etDescription.text?.toString()?.trim()

        if (amountStr.isNullOrEmpty()) {
            binding.tilMontant.error = "Montant requis"; return
        }
        if (date.isNullOrEmpty()) {
            binding.tilDate.error = "Date requise"; return
        }
        if (catName.isNullOrEmpty()) {
            binding.tilCategorie.error = "Catégorie requise"; return
        }

        binding.tilMontant.error = null
        binding.tilDate.error = null
        binding.tilCategorie.error = null

        val amount = amountStr.toDoubleOrNull() ?: run {
            binding.tilMontant.error = "Montant invalide"; return
        }
        val type = if (binding.toggleTransactionType.checkedButtonId == R.id.btnIncome)
            TransactionType.INCOME else TransactionType.EXPENSE

        // Find or create category
        val category = categoriesList.find { it.name.equals(catName, ignoreCase = true) }
            ?: Category(id = UUID.randomUUID().toString(), name = catName, icon = "📋", color = "#7C4DFF")

        viewLifecycleOwner.lifecycleScope.launch {
            if (category.id !in categoriesList.map { it.id }) {
                viewModel.insertCategory(category)
            }
            val transaction = Transaction(
                id = editingTransactionId ?: UUID.randomUUID().toString(),
                amount = amount,
                categoryId = category.id,
                date = date,
                note = note?.ifEmpty { null },
                type = type,
                receiptPhotoPath = photoPath
            )
            if (editingTransactionId != null) viewModel.update(transaction)
            else viewModel.insert(transaction)

            Snackbar.make(binding.root, "Transaction enregistrée ✓", Snackbar.LENGTH_SHORT).show()
            findNavController().navigateUp()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
