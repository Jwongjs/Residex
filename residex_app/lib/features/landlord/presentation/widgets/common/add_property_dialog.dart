import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/entities/unit.dart';
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import '../../../../shared/presentation/providers/auth_providers.dart';
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

  /// 'upload' | 'manual' | null. Null means unanswered, which behaves as
  /// 'upload' everywhere downstream — so an existing property, or a landlord
  /// who skips the question, sees exactly today's behaviour.
  String? _loanInputMethod;

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
      _loanInputMethod = property.loanInputMethod;
    } else {
      _selectedStructureType = _structureForType(_selectedType);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _purchasePriceController.dispose();
    _currentValueController.dispose();
    _ownershipShareController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) {
      _showError('User not authenticated');
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

      final controller = ref.read(propertyControllerProvider);
      final existing = widget.property;

      if (existing != null) {
        // Edit mode: preserve id/landlordId/createdAt/photos, update the rest.
        // Unit count/rent are not editable here — see UnitsScreen.
        //
        // Built directly rather than via existing.copyWith(...): copyWith
        // coalesces every field with `?? this.field`, so passing null to
        // clear loanInputMethod would silently keep the old value instead.
        // Constructing the Property explicitly is the only way this branch
        // can actually write null for that field.
        //
        // effectiveHasMortgage mirrors copyWith's `?? existing.field`
        // coalescing for hasMortgage itself: a "Not sure" tap sets
        // _hasMortgage to null, which falls back to the existing value —
        // same as structureType and trackFromYear below (pre-existing,
        // out of scope here). loanInputMethod MUST be derived from this
        // same *effective* value, not from the raw _hasMortgage field:
        // gating on the raw field let "Not sure" write hasMortgage: true
        // (coalesced back to the existing value) but loanInputMethod: null
        // (not coalesced) in the very same save, orphaning a manual-entry
        // property's booked figures from every UI surface while they kept
        // feeding the engine. See the fix report for the loan-entry-method
        // workstream, final review item 1.
        final effectiveHasMortgage = _hasMortgage ?? existing.hasMortgage;
        final updatedProperty = Property(
          id: existing.id,
          landlordId: existing.landlordId,
          name: _nameController.text.trim(),
          address: address,
          type: _selectedType,
          purchasePrice: double.parse(_purchasePriceController.text),
          currentValue: double.parse(_currentValueController.text),
          ownershipShare: ownershipShare,
          structureType: _selectedStructureType ?? existing.structureType,
          hasMortgage: effectiveHasMortgage,
          trackFromYear: _trackFromYear ?? existing.trackFromYear,
          utilitiesPaidBy: existing.utilitiesPaidBy,
          loanInputCadence: existing.loanInputCadence,
          loanInputMethod: effectiveHasMortgage == true ? _loanInputMethod : null,
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
          photos: [],
          createdAt: DateTime.now(),
          structureType: _selectedStructureType,
          hasMortgage: _hasMortgage,
          trackFromYear: _trackFromYear,
          loanInputCadence: null,
          loanInputMethod: _hasMortgage == true ? _loanInputMethod : null,
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
                      if (_hasMortgage == true) ...[
                        const SizedBox(height: 16),
                        _buildLoanMethodSelector(),
                      ],
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
            AppChoiceChip(
              label: 'Not sure',
              selected: _hasMortgage == null,
              onSelected: (_) => setState(() => _hasMortgage = null),
            ),
          ],
        ),
      ],
    );
  }

  /// Two equally-weighted options, each saying what it does and what the
  /// landlord gets back. Deliberately not a button plus a text link: these
  /// are different paths with different downstream behaviour, and rendering
  /// one as an afterthought is what made the old three surfaces unreadable.
  Widget _buildLoanMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How will loan figures arrive?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        // IntrinsicHeight so CrossAxisAlignment.stretch has a finite height to
        // stretch to — the Column above sits in an unbounded-height
        // SingleChildScrollView, and a bare Row.stretch there throws.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _loanMethodCard(
                  value: 'upload',
                  icon: Icons.description_outlined,
                  title: 'Upload statements',
                  blurb: 'We read the interest and principal out of your bank statement.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _loanMethodCard(
                  value: 'manual',
                  icon: Icons.edit_outlined,
                  title: 'Enter figures myself',
                  blurb: 'Type the interest and principal for each period yourself.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loanMethodCard({
    required String value,
    required IconData icon,
    required String title,
    required String blurb,
  }) {
    final selected = _loanInputMethod == value;
    return InkWell(
      key: Key('loan-method-$value'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _loanInputMethod = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.registry.withOpacity(0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.registry : AppColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zero-size selection probe: the stable keys above/on Container
            // stay put across taps (nothing remounts), and tests read
            // selection state by looking for this key instead of relying on
            // Container's identity changing.
            if (selected) SizedBox.shrink(key: Key('loan-method-$value-selected')),
            Icon(icon,
                size: 20,
                color: selected ? AppColors.registry : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(title,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected ? AppColors.registry : AppColors.textPrimary,
                )),
            const SizedBox(height: 4),
            Text(blurb,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
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
