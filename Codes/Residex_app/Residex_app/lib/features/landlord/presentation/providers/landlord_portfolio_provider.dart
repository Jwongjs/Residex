import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ⚠️ DEPRECATED - This file is now replaced by property_providers.dart
/// 
/// Migration Guide:
/// 1. Import: import 'property_providers.dart';
/// 2. Replace portfolioPropertiesProvider → propertiesStreamProvider (for real-time) or propertiesProvider (for one-time fetch)
/// 3. Replace portfolioStatsProvider → portfolioStatsProvider (same name, but real data)
/// 4. Use Property entity from domain layer instead of local Property class
/// 
/// Old mock data structure is replaced with Clean Architecture:
/// - Domain: entities/property.dart (PropertyAddress, PropertyType)
/// - Data: models/property_model.dart + datasources + repositories
/// - Presentation: property_providers.dart (Riverpod providers)
///
/// ============================================================
/// RE-EXPORT NEW PROVIDERS FOR BACKWARD COMPATIBILITY
/// ============================================================

export 'property_providers.dart';

// Mock data removed - use real Firestore data via property_providers.dart