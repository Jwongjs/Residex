import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import '../../../../shared/presentation/providers/auth_providers.dart';
import '../../../domain/share_basis.dart';
import 'app_choice_chip.dart';
import 'registration_document_steps_sheet.dart';

/// Add/Edit property dialog.
///
/// Dual-mode: when [property] is null this dialog creates a new property.
/// When [property] is non-null, all fields are pre-filled from it and
/// submitting saves changes via the update path instead of create.
class AddPropertyDialog extends ConsumerStatefulWidget {
  final Property? property;

  const AddPropertyDialog({super.key, this.property});

  @override
  ConsumerState<AddPropertyDialog> createState() => _AddPropertyDialogState();
}

class _AddPropertyDialogState extends ConsumerState<AddPropertyDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _ownershipShareController = TextEditingController(text: '100');
  final _totalUnitsController = TextEditingController();
  
  PropertyType _selectedType = PropertyType.apartment;
  bool _isLoading = false;

  PropertyStructureType? _selectedStructureType;
  bool? _hasMortgage;
  int? _trackFromYear;
  String _shareBasisDefault = shareBasisFull;
  Map<String, String> _shareBasisExceptions = {};
  bool _showBasisExceptions = false;

  /// House/apartment/condo imply their structure; commercial varies too much
  /// to guess, so it stays null and [_buildStructureTypeSelector] asks.
  static PropertyStructureType? _structureForType(PropertyType type) {
    switch (type) {
      case PropertyType.house:
        return PropertyStructureType.landed;
      case PropertyType.apartment:
      case PropertyType.condo:
        return PropertyStructureType.strata;
      case PropertyType.commercial:
        return null;
    }
  }

  bool get _isEditMode => widget.property != null;

  @override
  void initState() {
    super.initState();
    final property = widget.property;
    if (property != null) {
      _nameController.text = property.name;
      _streetController.text = property.address.street;
      _cityController.text = property.address.city;
      _stateController.text = property.address.state;
      _zipCodeController.text = property.address.zipCode;
      _purchasePriceController.text = property.purchasePrice.toString();
      _currentValueController.text = property.currentValue.toString();
      _ownershipShareController.text =
          (property.ownershipShare * 100).toStringAsFixed(0);
      _selectedType = property.type;
      _selectedStructureType = property.structureType;
      _hasMortgage = property.hasMortgage;
      _trackFromYear = property.trackFromYear;
      _shareBasisDefault = property.shareBasisDefault;
      _shareBasisExceptions = Map<String, String>.from(property.shareBasisExceptions);
      _showBasisExceptions = _shareBasisExceptions.isNotEmpty;
    } else {
      _selectedStructureType = _structureForType(_selectedType);
    }
    // The question appears and disappears as the landlord types a share, so
    // the form has to rebuild on every keystroke in that one field.
    _ownershipShareController.addListener(_onShareChanged);
  }

  void _onShareChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _purchasePriceController.dispose();
    _currentValueController.dispose();
    _ownershipShareController.removeListener(_onShareChanged);
    _ownershipShareController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  /// "No" means *never had a mortgage* — it retroactively stops expecting loan
  /// figures for every historical year. A landlord who has simply finished
  /// paying wants settlement instead, which keeps history intact. Naming the
  /// right tool here is what stops them reaching for the destructive one.
  ///
  /// Returns true when the save may proceed.
  Future<bool> _confirmRemovingLoanTracking(Property existing) async {
    if (!(existing.hasMortgage == true && _hasMortgage == false)) return true;

    // Every year, not just this one. The removal is retroactive, so scoping
    // the guard to the current year let it wave through exactly the case that
    // loses the most: a property whose loan history sits in earlier years and
    // has nothing booked yet this year — the normal state of any property in
    // January, or any property whose mortgage predates this year.
    final entries =
        await ref.read(allManualLoanEntriesProvider(existing.id).future);
    if (entries.isEmpty) return true;

    final booked = entries.fold<double>(
      0,
      (total, e) =>
          total +
          ((e['interest_paid'] as num?)?.toDouble() ?? 0) +
          ((e['principal_paid'] as num?)?.toDouble() ?? 0),
    );

    // Naming the years is what makes the warning act on the landlord: "RM
    // 90,074.52 of 2025 loan figures" is checkable against what they remember
    // filing, where a bare amount is just a number.
    final years = entries
        .map((e) => e['year'] as int?)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    final scope = years.isEmpty
        ? ''
        : years.length == 1
            ? '${years.first} '
            : '${years.first}–${years.last} ';

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Remove loan tracking for this property?',
            style: AppTextStyles.titleMedium),
        content: Text(
          'This property has ${formatRM(booked)} of ${scope}loan '
          "figures recorded. They'll stay in your finance totals but will no "
          'longer be visible or editable.\n\n'
          'If your mortgage is fully repaid, mark it settled instead so your '
          'past years stay accurate.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove tracking'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      // Restore the stored answer so the form never sits contradicting what
      // is saved.
      if (mounted) setState(() => _hasMortgage = true);
      return false;
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    final existing = widget.property;
    if (existing != null && !await _confirmRemovingLoanTracking(existing)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final address = PropertyAddress(
        street: _streetController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipCodeController.text.trim(),
        country: 'USA', // Default to USA
      );

      final ownershipShare =
          double.parse(_ownershipShareController.text) / 100.0;

      // Only the categories that actually differ are stored (spec §2), and a
      // property where no share applies keeps the defaults rather than
      // recording an answer nobody was asked for. `_readUnits`, not
      // `_watchUnits`: watching outside build throws.
      final unitsAsync = _readUnits();
      final String basisDefault;
      final Map<String, String> basisExceptions;
      if (existing != null &&
          unitsAsync.value == null &&
          !_shareAppliesFor(unitsAsync)) {
        // The units stream has not delivered its first event yet — still
        // loading, or an errored subscription — AND the property's own share
        // alone (with no unit data) does not already trigger the question.
        // That combination is the only case where the question genuinely
        // could not have been shown or answered, so we cannot tell whether a
        // unit override applies and this save carries the existing answer
        // through unchanged rather than guessing "no" and discarding it.
        //
        // When the property's own share already makes the question
        // answerable (propertyShare < 1.0), `_shareAppliesFor` is true even
        // with no unit data, so this branch must NOT preserve — the landlord
        // could have just tapped a fresh answer, and preserving here would
        // silently discard it instead.
        basisDefault = existing.shareBasisDefault;
        basisExceptions = existing.shareBasisExceptions;
      } else {
        final basisApplies = _shareAppliesFor(unitsAsync);
        basisDefault = basisApplies ? _shareBasisDefault : shareBasisFull;
        basisExceptions = basisApplies
            ? {
                for (final entry in _shareBasisExceptions.entries)
                  if (entry.value != basisDefault) entry.key: entry.value,
              }
            : const <String, String>{};
      }

      final controller = ref.read(propertyControllerProvider);

      if (existing != null) {
        // Edit mode: preserve id/landlordId/createdAt/photos, update the rest.
        // Unit count/rent are not editable here — see UnitsScreen.
        //
        // Built directly rather than via existing.copyWith(...): copyWith
        // coalesces every field with `?? this.field`, so it cannot clear a
        // nullable field back to null. Constructing the Property explicitly
        // here is what lets structureType/hasMortgage/trackFromYear below be
        // written raw from state, including null.
        final updatedProperty = Property(
          id: existing.id,
          landlordId: existing.landlordId,
          name: _nameController.text.trim(),
          address: address,
          type: _selectedType,
          purchasePrice: double.parse(_purchasePriceController.text),
          currentValue: double.parse(_currentValueController.text),
          ownershipShare: ownershipShare,
          // Written raw from state, not coalesced with `?? existing.field`:
          // initState seeds all three from the existing property, so the state
          // variable *is* the landlord's current answer, and coalescing could
          // only ever undo a deliberate "Not sure".
          structureType: _selectedStructureType,
          hasMortgage: _hasMortgage,
          trackFromYear: _trackFromYear,
          utilitiesPaidBy: existing.utilitiesPaidBy,
          shareBasisDefault: basisDefault,
          shareBasisExceptions: basisExceptions,
          loanInputCadence: existing.loanInputCadence,
          nextSetupStep: existing.nextSetupStep,
          foldersEnabled: existing.foldersEnabled,
          folderNames: existing.folderNames,
          folderMoves: existing.folderMoves,
          photos: existing.photos,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        );
        await controller.updateProperty(updatedProperty);
      } else {
        final property = Property(
          id: '', // Will be generated by Firestore
          landlordId: user.uid,
          name: _nameController.text.trim(),
          address: address,
          type: _selectedType,
          purchasePrice: double.parse(_purchasePriceController.text),
          currentValue: double.parse(_currentValueController.text),
          ownershipShare: ownershipShare,
          shareBasisDefault: basisDefault,
          shareBasisExceptions: basisExceptions,
          photos: [],
          createdAt: DateTime.now(),
          structureType: _selectedStructureType,
          hasMortgage: _hasMortgage,
          trackFromYear: _trackFromYear,
          loanInputCadence: null,
          nextSetupStep: 2,
        );
        final propertyId = await controller.createProperty(property);

        final unitCount = int.parse(_totalUnitsController.text);
        final unitController = ref.read(unitControllerProvider);
        for (var i = 1; i <= unitCount; i++) {
          await unitController.createUnit(Unit(
            id: '',
            propertyId: propertyId,
            label: 'Unit $i',
            monthlyRent: 0,
            isOccupied: false,
            createdAt: DateTime.now(),
          ));
        }

        if (mounted) {
          // Steps 2-3 of guided registration (spec §6): skippable, resumable.
          await showRegistrationDocumentSteps(
            context,
            property: property.copyWith(id: propertyId),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Property updated successfully'
                : 'Property added successfully'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError(_isEditMode
          ? 'Failed to update property: $e'
          : 'Failed to add property: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.registry,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditMode ? Icons.edit_outlined : Icons.business,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'Edit property' : 'Add New Property',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Property Name',
                        hint: 'e.g., Sunset Apartments',
                        icon: Icons.apartment,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Property Type Dropdown
                      _buildDropdown(),
                      const SizedBox(height: 20),

                      Text(
                        'Address',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _streetController,
                        label: 'Street Address',
                        hint: '123 Main St',
                        icon: Icons.location_on,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'New York',
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: 'State',
                              hint: 'NY',
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _zipCodeController,
                              label: 'Zip Code',
                              hint: '10001',
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Financial Details',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _purchasePriceController,
                              label: 'Purchase Price',
                              hint: '500000',
                              keyboardType: TextInputType.number,
                              validator: _validateNumber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _currentValueController,
                              label: 'Current Value',
                              hint: '550000',
                              keyboardType: TextInputType.number,
                              validator: _validateNumber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ownershipShareController,
                        label: 'My share of this property (%)',
                        hint: '100 if solely owned',
                        keyboardType: TextInputType.number,
                        validator: _validateSharePercent,
                      ),
                      if (_shareAppliesFor(_watchUnits())) ...[
                        const SizedBox(height: 16),
                        _buildShareBasisQuestion(),
                      ],
                      const SizedBox(height: 20),

                      Text(
                        'Unit Information',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isEditMode)
                        _buildTextField(
                          controller: _totalUnitsController,
                          label: 'Number of Units',
                          hint: '10',
                          keyboardType: TextInputType.number,
                          validator: _validatePositiveInt,
                        ),
                      if (_isEditMode) ...[
                        Text(
                          'Manage individual units from the property card.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Property profile',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quick facts — tailors which expenses the app ever asks you for.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedType == PropertyType.commercial) ...[
                        _buildStructureTypeSelector(),
                        const SizedBox(height: 16),
                      ],
                      _buildMortgageSelector(),
                      const SizedBox(height: 16),
                      _buildYearPicker(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(color: AppColors.hairline),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.registry,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(_isEditMode ? 'Save changes' : 'Add Property'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.registry),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.registry, size: 20) : null,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.registry, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<PropertyType>(
      value: _selectedType,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
            _selectedStructureType = _structureForType(value);
          });
        }
      },
      decoration: InputDecoration(
        labelText: 'Property Type',
        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        prefixIcon: const Icon(Icons.category, color: AppColors.registry),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.registry, width: 2),
        ),
      ),
      dropdownColor: AppColors.card,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      items: PropertyType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type.displayName),
        );
      }).toList(),
    );
  }

  Widget _buildStructureTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Is this commercial property landed or strata?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'Landed',
              selected: _selectedStructureType == PropertyStructureType.landed,
              onSelected: (_) => setState(() => _selectedStructureType = PropertyStructureType.landed),
            ),
            AppChoiceChip(
              label: 'Strata',
              selected: _selectedStructureType == PropertyStructureType.strata,
              onSelected: (_) => setState(() => _selectedStructureType = PropertyStructureType.strata),
            ),
            AppChoiceChip(
              label: 'Not sure',
              selected: _selectedStructureType == null,
              onSelected: (_) => setState(() => _selectedStructureType = null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMortgageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Do you have a mortgage on this property?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        // Yes/No only. A property owner is not unsure whether they have a
        // mortgage; the third chip existed because null was the initial state,
        // and a property that has never answered simply shows neither chip
        // selected. structureType and trackFromYear keep their "Not sure" —
        // title type and tracking start are real unknowns.
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'Yes',
              selected: _hasMortgage == true,
              onSelected: (_) => setState(() => _hasMortgage = true),
            ),
            AppChoiceChip(
              label: 'No',
              selected: _hasMortgage == false,
              onSelected: (_) => setState(() => _hasMortgage = false),
            ),
          ],
        ),
      ],
    );
  }

  /// The typed share, not the stored one: the landlord may be lowering it
  /// right now, and the question has to appear as they do it.
  double get _typedPropertyShare {
    final typed = double.tryParse(_ownershipShareController.text);
    return typed == null ? 1.0 : typed / 100.0;
  }

  /// The units whose overrides the §3a predicate has to consider.
  ///
  /// Split into a watch and a read on purpose: `ref.watch` is only legal
  /// during build, and `_handleSubmit` needs the same answer from outside it.
  /// At registration no units exist yet, so the predicate reduces to the
  /// property's own share.
  AsyncValue<List<Unit>> _watchUnits() {
    final property = widget.property;
    if (property == null) return AsyncValue<List<Unit>>.data(const []);
    return ref.watch(unitsForPropertyStreamProvider(property.id));
  }

  AsyncValue<List<Unit>> _readUnits() {
    final property = widget.property;
    if (property == null) return AsyncValue<List<Unit>>.data(const []);
    return ref.read(unitsForPropertyStreamProvider(property.id));
  }

  bool _shareAppliesFor(AsyncValue<List<Unit>> unitsAsync) => shareApplies(
        propertyShare: _typedPropertyShare,
        unitShares: (unitsAsync.value ?? const <Unit>[])
            .map((u) => u.ownershipShare),
      );

  Widget _buildShareBasisQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do your documents arrive?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          'Bills for a co-owned property come either way. This decides whether '
          'we apply your share to them, or take them as already yours.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'At the full property amount',
              selected: _shareBasisDefault == shareBasisFull,
              onSelected: (_) => _setShareBasisDefault(shareBasisFull),
            ),
            AppChoiceChip(
              label: 'Already split to my share',
              selected: _shareBasisDefault == shareBasisMine,
              onSelected: (_) => _setShareBasisDefault(shareBasisMine),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_showBasisExceptions)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showBasisExceptions = true),
              child: Text('Any exceptions?',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.registry)),
            ),
          )
        else ...[
          Text('Tap any category that arrives the other way.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in shareBasisCategories.entries)
                AppChoiceChip(
                  label: entry.value,
                  selected: _shareBasisExceptions.containsKey(entry.key),
                  onSelected: (_) => _toggleBasisException(entry.key),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// An exception means "this category differs from the default", so moving
  /// the default has to move every exception with it — otherwise each one
  /// silently becomes a duplicate of the default and stops meaning anything.
  void _setShareBasisDefault(String basis) {
    setState(() {
      _shareBasisDefault = basis;
      final flipped = oppositeShareBasis(basis);
      _shareBasisExceptions = {
        for (final key in _shareBasisExceptions.keys) key: flipped,
      };
    });
  }

  void _toggleBasisException(String category) {
    setState(() {
      if (_shareBasisExceptions.containsKey(category)) {
        _shareBasisExceptions.remove(category);
      } else {
        _shareBasisExceptions[category] = oppositeShareBasis(_shareBasisDefault);
      }
    });
  }

  /// Styled like [_buildTextField] but opens a bottom sheet of years instead
  /// of a keyboard, so landlords never have to hand-type a year.
  Widget _buildYearPicker() {
    final currentYear = DateTime.now().year;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickTrackFromYear,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Track expenses from year (optional)',
          labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          floatingLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.registry),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.registry, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Text(
          _trackFromYear?.toString() ?? 'Not sure — defaults to $currentYear',
          style: AppTextStyles.bodyMedium.copyWith(
            color: _trackFromYear == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickTrackFromYear() async {
    final currentYear = DateTime.now().year;
    const notSure = -1; // sentinel: distinguishes an explicit "not sure" tap from a dismissed sheet
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Track expenses from year', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Leave on "Not sure" to default to $currentYear.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: Text('Not sure (default)', style: AppTextStyles.bodyLarge),
                      trailing: _trackFromYear == null
                          ? const Icon(Icons.check, color: AppColors.registry)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(notSure),
                    ),
                    for (var year = currentYear; year >= 2000; year--)
                      ListTile(
                        title: Text('$year', style: AppTextStyles.bodyLarge),
                        trailing: _trackFromYear == year
                            ? const Icon(Icons.check, color: AppColors.registry)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(year),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _trackFromYear = picked == notSure ? null : picked);
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Must be a number';
    if (double.parse(value) < 0) return 'Must be positive';
    return null;
  }

  String? _validatePositiveInt(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final number = int.tryParse(value);
    if (number == null) return 'Must be a whole number';
    if (number <= 0) return 'Must be greater than 0';
    return null;
  }

  String? _validateSharePercent(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final number = double.tryParse(value);
    if (number == null) return 'Must be a number';
    if (number <= 0 || number > 100) return 'Between 1 and 100';
    return null;
  }
}
