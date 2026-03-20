import '../../../domain/entities/bills/bill.dart';
  import '../../../domain/entities/bills/bill_enums.dart';
  import '../../../domain/entities/bills/receipt_item.dart';

  /// Mock bills data for rental and utility payments
  class MockBillsData {
    /// Get current user ID (replace with actual user ID from your auth system)
    static const String currentUserId = 'user1';
    static const String roommateId1 = 'user2';
    static const String roommateId2 = 'user3';

    /// Generate realistic mock bills
    static List<Bill> getMockBills() {
      final now = DateTime.now();
      return [
        // 1. RENT - Monthly (Due in 5 days)
        Bill(
          id: 'bill_rent_001',
          title: 'Monthly Rent - January 2026',
          location: 'Apartment 3A',
          totalAmount: 2400.00,
          createdAt: now.subtract(const Duration(days: 2)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 800.00,
            roommateId1: 800.00,
            roommateId2: 800.00,
          },
          paymentStatus: {
            currentUserId: true,  // You paid
            roommateId1: false,   // Roommate 1 hasn't paid
            roommateId2: true,    // Roommate 2 paid
          },
          items: [],
          category: BillCategory.rent,
          provider: 'LANDLORD',
          dueDate: now.add(const Duration(days: 5)),
          status: BillStatus.pending,
        ),

        // 2. ELECTRICITY - TNB (Overdue by 2 days)
        Bill(
          id: 'bill_elec_001',
          title: 'TNB Bill - December 2025',
          location: 'Apartment 3A',
          totalAmount: 284.50,
          createdAt: now.subtract(const Duration(days: 15)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 94.83,
            roommateId1: 94.83,
            roommateId2: 94.84,
          },
          paymentStatus: {
            currentUserId: false,  // You haven't paid - OVERDUE!
            roommateId1: true,
            roommateId2: true,
          },
          items: [],
          category: BillCategory.electricity,
          provider: 'TNB',
          dueDate: now.subtract(const Duration(days: 2)),
          status: BillStatus.pending,
        ),

        // 3. WATER - Air Selangor (Pending)
        Bill(
          id: 'bill_water_001',
          title: 'Water Bill - January 2026',
          location: 'Apartment 3A',
          totalAmount: 65.20,
          createdAt: now.subtract(const Duration(days: 5)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 21.73,
            roommateId1: 21.73,
            roommateId2: 21.74,
          },
          paymentStatus: {
            currentUserId: true,
            roommateId1: false,
            roommateId2: false,
          },
          items: [],
          category: BillCategory.water,
          provider: 'AIR SELANGOR',
          dueDate: now.add(const Duration(days: 10)),
          status: BillStatus.pending,
        ),

        // 4. INTERNET - Unifi (Settled - all paid)
        Bill(
          id: 'bill_internet_001',
          title: 'Unifi - January 2026',
          location: 'Apartment 3A',
          totalAmount: 139.00,
          createdAt: now.subtract(const Duration(days: 8)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 46.33,
            roommateId1: 46.33,
            roommateId2: 46.34,
          },
          paymentStatus: {
            currentUserId: true,
            roommateId1: true,
            roommateId2: true,
          },
          items: [],
          category: BillCategory.internet,
          provider: 'UNIFI',
          dueDate: now.add(const Duration(days: 15)),
          status: BillStatus.settled,
        ),

        // 5. GAS - Gas Petronas (Pending)
        Bill(
          id: 'bill_gas_001',
          title: 'Cooking Gas - January 2026',
          location: 'Apartment 3A',
          totalAmount: 52.00,
          createdAt: now.subtract(const Duration(days: 3)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 17.33,
            roommateId1: 17.33,
            roommateId2: 17.34,
          },
          paymentStatus: {
            currentUserId: false,
            roommateId1: true,
            roommateId2: false,
          },
          items: [],
          category: BillCategory.gas,
          provider: 'GAS PETRONAS',
          dueDate: now.add(const Duration(days: 20)),
          status: BillStatus.pending,
        ),

        // 6. ELECTRICITY - Previous Month (Settled)
        Bill(
          id: 'bill_elec_002',
          title: 'TNB Bill - November 2025',
          location: 'Apartment 3A',
          totalAmount: 312.80,
          createdAt: now.subtract(const Duration(days: 45)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 104.27,
            roommateId1: 104.27,
            roommateId2: 104.26,
          },
          paymentStatus: {
            currentUserId: true,
            roommateId1: true,
            roommateId2: true,
          },
          items: [],
          category: BillCategory.electricity,
          provider: 'TNB',
          dueDate: now.subtract(const Duration(days: 30)),
          status: BillStatus.settled,
        ),

        // 7. RENT - Previous Month (Settled)
        Bill(
          id: 'bill_rent_002',
          title: 'Monthly Rent - December 2025',
          location: 'Apartment 3A',
          totalAmount: 2400.00,
          createdAt: now.subtract(const Duration(days: 32)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 800.00,
            roommateId1: 800.00,
            roommateId2: 800.00,
          },
          paymentStatus: {
            currentUserId: true,
            roommateId1: true,
            roommateId2: true,
          },
          items: [],
          category: BillCategory.rent,
          provider: 'LANDLORD',
          dueDate: now.subtract(const Duration(days: 25)),
          status: BillStatus.settled,
        ),

        // 8. WATER - Previous Month (Settled)
        Bill(
          id: 'bill_water_002',
          title: 'Water Bill - December 2025',
          location: 'Apartment 3A',
          totalAmount: 58.90,
          createdAt: now.subtract(const Duration(days: 35)),
          participantIds: [currentUserId, roommateId1, roommateId2],
          participantShares: {
            currentUserId: 19.63,
            roommateId1: 19.63,
            roommateId2: 19.64,
          },
          paymentStatus: {
            currentUserId: true,
            roommateId1: true,
            roommateId2: true,
          },
          items: [],
          category: BillCategory.water,
          provider: 'AIR SELANGOR',
          dueDate: now.subtract(const Duration(days: 20)),
          status: BillStatus.settled,
        ),
      ];
    }
  }
