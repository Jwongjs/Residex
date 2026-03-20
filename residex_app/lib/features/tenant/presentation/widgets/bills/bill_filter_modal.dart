import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/bills/bill_enums.dart';

enum PaymentStatusFilter { all, unpaid, pending, settled }

class BillFilterModal extends StatefulWidget {
  final BillCategory? selectedCategory;
  final PaymentStatusFilter selectedPaymentStatus;
  final Function(BillCategory?) onCategoryChanged;
  final Function(PaymentStatusFilter) onPaymentStatusChanged;

  const BillFilterModal({
    super.key,
    required this.selectedCategory,
    required this.selectedPaymentStatus,
    required this.onCategoryChanged,
    required this.onPaymentStatusChanged,
  });

  @override
  State<BillFilterModal> createState() => _BillFilterModalState();
}

class _BillFilterModalState extends State<BillFilterModal> {
  late BillCategory? _selectedCategory;
  late PaymentStatusFilter _selectedPaymentStatus;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedPaymentStatus = widget.selectedPaymentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppColors.primaryCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'FILTER VIEW',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _selectedPaymentStatus = PaymentStatusFilter.all;
                    });
                  },
                  child: Text(
                    'RESET',
                    style: TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Status Section
                  Text(
                    'PAYMENT STATUS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentStatusGrid(),

                  const SizedBox(height: 32),

                  // Bill Category Section
                  Text(
                    'BILL CATEGORY',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Apply Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onCategoryChanged(_selectedCategory);
                  widget.onPaymentStatusChanged(_selectedPaymentStatus);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'APPLY FILTERS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildPaymentStatusChip(PaymentStatusFilter.all, Icons.check_circle, 'ALL'),
        _buildPaymentStatusChip(PaymentStatusFilter.unpaid, Icons.cancel, 'UNPAID'),
        _buildPaymentStatusChip(PaymentStatusFilter.pending, Icons.schedule, 'PENDING'),
        _buildPaymentStatusChip(PaymentStatusFilter.settled, Icons.check_circle_outline, 'SETTLED'),
      ],
    );
  }

  Widget _buildPaymentStatusChip(PaymentStatusFilter status, IconData icon, String label) {
    final isSelected = _selectedPaymentStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentStatus = status),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.slate700
              : AppColors.slate900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryCyan
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryCyan : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryCyan : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildCategoryChip(null, Icons.filter_list, 'ALL TYPES'),
        ...BillCategory.values.map((category) {
          return _buildCategoryChip(category, category.icon, category.label.toUpperCase());
        }),
      ],
    );
  }

  Widget _buildCategoryChip(BillCategory? category, IconData icon, String label) {
    final isSelected = _selectedCategory == category;
    final color = category?.color ?? AppColors.primaryCyan;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.slate700
              : AppColors.slate900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
