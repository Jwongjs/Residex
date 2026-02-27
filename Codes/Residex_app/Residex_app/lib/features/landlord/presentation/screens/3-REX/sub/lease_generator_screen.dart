// lib/features/landlord/presentation/screens/3-REX/sub/lease_generator_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/property_providers.dart';
import '../../../../../../core/theme/app_theme.dart';

class LeaseGeneratorScreen extends ConsumerStatefulWidget {
  const LeaseGeneratorScreen({super.key});

  @override
  ConsumerState<LeaseGeneratorScreen> createState() => _LeaseGeneratorScreenState();
}

class _LeaseGeneratorScreenState extends ConsumerState<LeaseGeneratorScreen> {
  String? _selectedPropertyId;
  String? _selectedTenantId;
  
  // Form controllers
  final _tenantNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _leaseDurationController = TextEditingController(text: '12');
  final _startDateController = TextEditingController();
  
  // Special terms
  bool _petsAllowed = false;
  double _petDeposit = 0;
  bool _parkingIncluded = false;

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _leaseDurationController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Fetch properties from Firestore (via provider)
    final propertiesAsync = ref.watch(propertiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lease Generator'),
        subtitle: const Text('AI-Powered Contract Drafting'),
      ),
      body: propertiesAsync.when(
        data: (properties) => _buildForm(properties),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading properties: $error'),
        ),
      ),
    );
  }

  Widget _buildForm(List<Property> properties) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== STEP 1A: SELECT PROPERTY ==========
          _buildSectionHeader('1. Select Property'),
          const SizedBox(height: 12),
          
          DropdownButtonFormField<String>(
            value: _selectedPropertyId,
            decoration: InputDecoration(
              labelText: 'Property',
              hintText: 'Choose a property',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: properties.map((property) {
              return DropdownMenuItem(
                value: property.id,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.name),
                    Text(
                      property.address.street,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (propertyId) {
              setState(() {
                _selectedPropertyId = propertyId;
              });
            },
          ),

          const SizedBox(height: 24),

          // ========== DISPLAY AUTO-RETRIEVED DATA ==========
          if (_selectedPropertyId != null) ...[
            _buildPropertyDataCard(
              properties.firstWhere((p) => p.id == _selectedPropertyId),
            ),
            
            const SizedBox(height: 24),

            // ========== STEP 1B: SELECT/ENTER TENANT ==========
            _buildSectionHeader('2. Tenant Information'),
            const SizedBox(height: 12),
            
            // Option A: Select existing tenant (from Firestore)
            // Option B: Manual entry
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'existing', label: Text('Existing Tenant')),
                ButtonSegment(value: 'new', label: Text('New Tenant')),
              ],
              selected: {'new'},
              onSelectionChanged: (selected) {
                // Handle tenant selection
              },
            ),

            const SizedBox(height: 16),

            // Manual tenant input
            TextField(
              controller: _tenantNameController,
              decoration: InputDecoration(
                labelText: 'Tenant Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _tenantPhoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+60123456789',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========== STEP 1C: LEASE TERMS ==========
            _buildSectionHeader('3. Lease Terms'),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _leaseDurationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (months)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      hintText: '01 Mar 2026',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        _startDateController.text = 
                          '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ========== STEP 1D: SPECIAL TERMS ==========
            _buildSectionHeader('4. Special Terms'),
            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Pets Allowed'),
              value: _petsAllowed,
              onChanged: (value) {
                setState(() {
                  _petsAllowed = value;
                  if (!value) _petDeposit = 0;
                });
              },
            ),

            if (_petsAllowed) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Pet Deposit (RM)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _petDeposit = double.tryParse(value) ?? 0;
                  },
                ),
              ),
            ],

            SwitchListTile(
              title: const Text('Parking Included'),
              value: _parkingIncluded,
              onChanged: (value) {
                setState(() => _parkingIncluded = value);
              },
            ),

            const SizedBox(height: 32),

            // ========== GENERATE BUTTON ==========
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _selectedPropertyId != null &&
                           _tenantNameController.text.isNotEmpty
                    ? _generateContract
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Contract'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.headlineMedium.copyWith(
        color: AppColors.primaryCyan,
      ),
    );
  }

  Widget _buildPropertyDataCard(Property property) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'Auto-Retrieved Data',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Monthly Rent', 'RM ${property.monthlyRent.toStringAsFixed(0)}'),
          _buildInfoRow('Security Deposit', 'RM ${(property.monthlyRent * 3).toStringAsFixed(0)}'),
          _buildInfoRow('Property Type', property.type.toString().split('.').last.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _generateContract() async {
    // ✅ THIS is where we call the backend (Step 2: Draft Generation)
    // Collect all form data
    final property = ref.read(propertiesProvider).value!
        .firstWhere((p) => p.id == _selectedPropertyId);

    final requestData = {
      'landlord_id': property.landlordId,
      'property_id': _selectedPropertyId,
      'tenant_data': {
        'full_name': _tenantNameController.text,
        'phone': _tenantPhoneController.text,
      },
      'lease_terms': {
        'monthly_rent': property.monthlyRent,
        'security_deposit': property.monthlyRent * 3,
        'lease_duration': int.parse(_leaseDurationController.text),
        'start_date': _startDateController.text,
      },
      'special_terms': {
        'pets_allowed': _petsAllowed,
        'pet_deposit': _petDeposit,
        'parking_included': _parkingIncluded,
      },
    };

    print('📤 Sending to backend: $requestData');

    // TODO: Call backend API (POST /api/rex/lease/draft)
    // Navigate to preview screen when done
  }
}