import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../providers/bills/bills_provider.dart';
import '../../../../shared/presentation/providers/users_provider.dart';
import '../../../domain/entities/bills/bill_enums.dart';

  class BillSummaryScreen extends ConsumerStatefulWidget {
    final String billId;
    const BillSummaryScreen({super.key, required this.billId});

    @override
    ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
  }

  class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
    Bill? _loadedBill;
    List<AppUser> _participants = [];
    Map<String, bool> _paymentStatus = {};
    int? _selectedSliceIndex;
    String _currentUserId = '';

    // Palette matching React reference
    static const List<Color> _sliceColors = [
      Color(0xFF22d3ee), // cyan  — current user slot
      Color(0xFFe879f9), // fuchsia
      Color(0xFFfbbf24), // amber
      Color(0xFF34d399), // emerald
      Color(0xFF60a5fa), // blue
    ];

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBill());
    }

    Future<void> _loadBill() async {
      try {
        final bills = ref.read(billsProvider).value ?? [];
        _loadedBill = bills.firstWhere(
          (b) => b.id == widget.billId,
          orElse: () => throw Exception('Bill not found'),
        );
        final users = await ref.read(usersProvider.future);
        final currentUser = await ref.read(currentUserProvider.future);
        setState(() {
          _currentUserId = currentUser.id;
          _participants = _loadedBill!.participantIds
              .map((id) => users.firstWhere((u) => u.id == id,
                  orElse: () => AppUser(
                        id: id,
                        name: 'Unknown',
                        avatarInitials: '??',
                        role: currentUser.role,
                      )))
              .toList();
          _paymentStatus = Map.from(_loadedBill!.paymentStatus);
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Bill not found')));
          context.pop();
        }
      }
    }

    // ---------------------------------------------------------------------------
    // Build
    // ---------------------------------------------------------------------------
    @override
    Widget build(BuildContext context) {
      if (_loadedBill == null || _participants.isEmpty) {
        return const Scaffold(
          backgroundColor: AppColors.deepSpace,
          body: Center(child: CircularProgressIndicator(color: AppColors.cyan500)),
        );
      }

      final bill = _loadedBill!;
      final currentUserShare = bill.participantShares[_currentUserId] ?? 0.0;
      final currentUserPaid = _paymentStatus[_currentUserId] ?? false;
      final sharePercent = bill.totalAmount > 0
          ? (currentUserShare / bill.totalAmount * 100).round()
          : 0;

      return Scaffold(
        backgroundColor: AppColors.deepSpace,
        body: Stack(
          children: [
            // Radial gradient background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 500,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [
                      AppColors.indigo500.withValues(alpha: 0.28),
                      AppColors.deepSpace,
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(bill),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAmountHero(bill),
                          _buildDonutChart(
                              bill, sharePercent, currentUserShare),
                          const SizedBox(height: 32),
                          _buildBreakdownSection(bill),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Pay CTA — only if current user hasn't paid
            if (!currentUserPaid && _currentUserId.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildPayButton(currentUserShare),
              ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Header
    // ---------------------------------------------------------------------------
    Widget _buildHeader(Bill bill) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            _CircleBtn(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '${bill.provider.isNotEmpty ? bill.provider : bill.category.label}'
                    ' • ${_fmt(bill.createdAt)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate400,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            _CircleBtn(
              icon: Icons.share_rounded,
              onTap: () {},
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Amount Hero
    // ---------------------------------------------------------------------------
    Widget _buildAmountHero(Bill bill) {
      final catColor = bill.category.color;
      final payStatus = _currentUserId.isNotEmpty
          ? bill.getPaymentStatusForUser(_currentUserId)
          : PaymentStatus.pending;

      return Column(
        children: [
          const SizedBox(height: 20),
          // Category icon box
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: catColor.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(bill.category.icon, color: catColor, size: 28),
          ),
          const SizedBox(height: 20),
          // Total amount
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'RM ',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate500,
                  ),
                ),
              ),
              Text(
                bill.totalAmount.toStringAsFixed(2),
                style: GoogleFonts.inter(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatusChip(
                label: payStatus.label,
                color: payStatus.color,
              ),
              if (bill.dueDate != null) ...[
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Due ${_fmt(bill.dueDate!)}',
                  color: AppColors.slate500,
                  subtle: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    // ---------------------------------------------------------------------------
    // Donut Chart
    // ---------------------------------------------------------------------------
    Widget _buildDonutChart(Bill bill, int sharePercent, double myShare) {
      final shares = _buildShareList(bill);

      return SizedBox(
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient glow blob
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo500.withValues(alpha: 0.18),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
            // Donut
            GestureDetector(
              onTapDown: (details) => _handleChartTap(details, shares),
              child: CustomPaint(
                size: const Size(270, 270),
                painter: _DonutPainter(
                  shares: shares,
                  totalAmount: bill.totalAmount,
                  selectedIndex: _selectedSliceIndex,
                ),
              ),
            ),
            // Center label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOUR SHARE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate500,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '$sharePercent',
                      style: GoogleFonts.inter(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: '%',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan500,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'RM ${myShare.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    void _handleChartTap(TapDownDetails details, List<Map<String, dynamic>> shares) {
      // Simple tap anywhere on chart cycles through slices
      setState(() {
        if (_selectedSliceIndex == null) {
          _selectedSliceIndex = 0;
        } else if (_selectedSliceIndex! < shares.length - 1) {
          _selectedSliceIndex = _selectedSliceIndex! + 1;
        } else {
          _selectedSliceIndex = null;
        }
      });
    }

    // ---------------------------------------------------------------------------
    // Breakdown
    // ---------------------------------------------------------------------------
    Widget _buildBreakdownSection(Bill bill) {
      final shares = _buildShareList(bill);

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BREAKDOWN',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate400,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${_participants.length} People',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...shares.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildParticipantCard(e.value, bill.totalAmount, e.key),
              )),
        ],
      );
    }

    Widget _buildParticipantCard(
        Map<String, dynamic> share, double total, int idx) {
      final user = share['user'] as AppUser;
      final amount = share['amount'] as double;
      final isPaid = share['paid'] as bool;
      final color = share['color'] as Color;
      final isMe = share['isMe'] as bool;
      final percent =
          total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';
      final isSelected = _selectedSliceIndex == idx;

      return GestureDetector(
        onTap: () => setState(
            () => _selectedSliceIndex = isSelected ? null : idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.slate800.withValues(alpha: 0.85)
                : const Color(0xFF0a0a12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 16)
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Avatar with colored ring + paid dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.slate800,
                      border: Border.all(color: color, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        user.avatarInitials,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isPaid)
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.deepSpace,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34d399),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isPaid ? AppColors.slate500 : Colors.white,
                              decoration: isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.slate600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.cyan500.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.cyan500
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'YOU',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cyan500,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isPaid
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 10,
                          color: isPaid
                              ? const Color(0xFF34d399)
                              : AppColors.blue500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPaid ? 'Paid via DuitNow' : 'Pending',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isPaid
                                ? const Color(0xFF34d399)
                                : AppColors.blue500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount + percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: 'RM ',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                      TextSpan(
                        text: amount.toStringAsFixed(2),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isPaid ? AppColors.slate500 : Colors.white,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$percent%',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Action buttons
    // ---------------------------------------------------------------------------
    Widget _buildActionButtons() {
      return Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.download_rounded,
              label: 'Statement',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading statement...')),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionBtn(
              icon: Icons.notifications_rounded,
              label: 'Remind All',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reminders sent to all members!')),
              ),
            ),
          ),
        ],
      );
    }

    // ---------------------------------------------------------------------------
    // Pay CTA
    // ---------------------------------------------------------------------------
    Widget _buildPayButton(double amount) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.deepSpace.withValues(alpha: 0),
              AppColors.deepSpace,
              AppColors.deepSpace,
            ],
          ),
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Paying RM ${amount.toStringAsFixed(2)} via DuitNow...')),
            );
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.credit_card_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Pay RM ${amount.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------
    List<Map<String, dynamic>> _buildShareList(Bill bill) {
      // Put current user first so they always get the cyan slice
      final sorted = [..._participants];
      final myIdx = sorted.indexWhere((u) => u.id == _currentUserId);
      if (myIdx > 0) {
        final me = sorted.removeAt(myIdx);
        sorted.insert(0, me);
      }

      return sorted.asMap().entries.map((e) {
        final user = e.value;
        return {
          'user': user,
          'amount': bill.participantShares[user.id] ?? 0.0,
          'paid': _paymentStatus[user.id] ?? false,
          'color': _sliceColors[e.key % _sliceColors.length],
          'isMe': user.id == _currentUserId,
        };
      }).toList();
    }

    String _fmt(DateTime d) {
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    }
  }

  // =============================================================================
  // Donut chart painter
  // =============================================================================
  class _DonutPainter extends CustomPainter {
    final List<Map<String, dynamic>> shares;
    final double totalAmount;
    final int? selectedIndex;

    const _DonutPainter({
      required this.shares,
      required this.totalAmount,
      required this.selectedIndex,
    });

    @override
    void paint(Canvas canvas, Size size) {
      if (totalAmount <= 0) return;

      final center = Offset(size.width / 2, size.height / 2);
      final outerR = size.width / 2 - 6;
      const strokeW = 42.0;
      final arcR = outerR - strokeW / 2; // center-line radius of arc
      const gap = 0.055; // radians between slices

      double angle = -pi / 2;

      for (int i = 0; i < shares.length; i++) {
        final amount = shares[i]['amount'] as double;
        if (amount <= 0) continue;

        final isPaid = shares[i]['paid'] as bool;
        final color = shares[i]['color'] as Color;
        final isSelected = selectedIndex == i;
        final isDimmed = selectedIndex != null && !isSelected;

        final sweep = (amount / totalAmount) * 2 * pi - gap;
        if (sweep <= 0) {
          angle += gap;
          continue;
        }

        final startA = angle + gap / 2;

        // Glow pass (drawn below main stroke)
        if (!isDimmed) {
          final glowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW + (isSelected ? 14 : 6)
            ..color =
                color.withValues(alpha: isSelected ? 0.28 : (isPaid ? 0.06 : 0.15))
            ..maskFilter = MaskFilter.blur(
                BlurStyle.normal, isSelected ? 14.0 : 6.0);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: arcR),
            startA,
            sweep,
            false,
            glowPaint,
          );
        }

        // Main arc
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = color
              .withValues(alpha: isDimmed ? 0.12 : (isPaid ? 0.38 : 1.0))
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcR),
          startA,
          sweep,
          false,
          paint,
        );

        angle += sweep + gap;
      }

      // Donut hole — paint a filled circle over the centre
      canvas.drawCircle(
        center,
        arcR - strokeW / 2 - 3,
        Paint()
          ..color = const Color(0xFF000212)
          ..style = PaintingStyle.fill,
      );
    }

    @override
    bool shouldRepaint(covariant _DonutPainter old) =>
        old.selectedIndex != selectedIndex || old.shares != shares;
  }

  // =============================================================================
  // Small reusable widgets
  // =============================================================================
  class _CircleBtn extends StatelessWidget {
    final IconData icon;
    final VoidCallback onTap;
    const _CircleBtn({required this.icon, required this.onTap});

    @override
    Widget build(BuildContext context) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: AppColors.slate300, size: 20),
          ),
        );
  }

  class _StatusChip extends StatelessWidget {
    final String label;
    final Color color;
    final bool subtle;
    const _StatusChip(
        {required this.label, required this.color, this.subtle = false});

    @override
    Widget build(BuildContext context) => Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: subtle
                ? Colors.white.withValues(alpha: 0.04)
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: subtle
                  ? Colors.white.withValues(alpha: 0.07)
                  : color.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: subtle ? AppColors.slate500 : color,
              letterSpacing: 0.8,
            ),
          ),
        );
  }

  class _ActionBtn extends StatelessWidget {
    final IconData icon;
    final String label;
    final VoidCallback onTap;
    const _ActionBtn(
        {required this.icon, required this.label, required this.onTap});

    @override
    Widget build(BuildContext context) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.slate800.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.slate300),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate300,
                  ),
                ),
              ],
            ),
          ),
        );
  }
