import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/unit.dart';

/// Category vocabulary shared between the Documind chat screen (which labels
/// categories in its checkpoint replies) and the Documents tab (whose folder
/// tiles use the same labels/icons/colors). Moved here in Stage E so neither
/// screen has to duplicate it.

String getCategoryLabel(String category) {
  final labels = {
    'lease': 'Tenancy Agreements',
    'insurance': 'Insurance Policies',
    'loan': 'Loans & Financing',
    'tax': 'Property Taxes',
    'upkeep': 'Upkeep & Repairs',
    'maintenance': 'Maintenance Fees',
    'rental_invoice': 'Rent records',
    'expenses': 'Expenses',
    'other': 'Other Documents',
  };
  return labels[category] ?? category.toUpperCase();
}

Icon getCategoryIcon(String category) {
  final iconMap = {
    'lease': Icons.description_outlined,
    'insurance': Icons.security_outlined,
    'loan': Icons.account_balance_outlined,
    'tax': Icons.account_balance_wallet_outlined,
    'upkeep': Icons.build_outlined,
    'maintenance': Icons.apartment_outlined,
    'rental_invoice': Icons.receipt_long_outlined,
    'expenses': Icons.account_balance_wallet_outlined,
    'other': Icons.folder_outlined,
  };

  return Icon(iconMap[category] ?? Icons.folder_outlined);
}

Color getCategoryColor(String category) {
  final colorMap = {
    'lease': AppColors.catLease,
    'insurance': AppColors.catInsurance,
    'loan': AppColors.catLoan,
    'tax': AppColors.catTax,
    'upkeep': AppColors.catUpkeep,
    'maintenance': AppColors.catMaintenance,
    'rental_invoice': AppColors.catInvoice,
    'expenses': AppColors.catMaintenance,
    'other': AppColors.catOther,
  };
  return colorMap[category] ?? AppColors.catOther;
}

/// Folder the Documents tab files a stored category under. Documents keep
/// their granular backend category (no migration); only the presentation
/// collapses money-out paperwork into one Expenses folder.
String displayCategoryFor(String category) {
  switch (category) {
    case 'lease':
      return 'lease';
    case 'rental_invoice':
    case 'receipt':
      return 'rental_invoice';
    default:
      return 'expenses';
  }
}

/// The backend ingests PDFs plus JPG/PNG photos (Gemini transcription), so
/// the picker accepts exactly those extensions (DOCX is future work).
const Set<String> allowedUploadExtensions = {'.pdf', '.jpg', '.jpeg', '.png'};

bool isAllowedUploadFilename(String filename) {
  final lower = filename.toLowerCase();
  return allowedUploadExtensions.any(lower.endsWith);
}

/// Option order for the upload unit-picker dialog. A null entry is the
/// "Whole property" option. Leases lead with units (a lease almost always
/// belongs to one unit) and demote "Whole property" to last; every other
/// category keeps "Whole property" first.
List<Unit?> uploadUnitDialogOptions({
  required String category,
  required List<Unit> units,
}) {
  if (category == 'lease') {
    return [...units, null];
  }
  return [null, ...units];
}
