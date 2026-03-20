import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';

// ─────────────────────────────────
// DATA MODELS
// ─────────────────────────────────

enum PoolStatus { pending, settled }

class _LiabilityItem {
  final String title;
  final String provider;
  final double total;
  final double cleared;
  final int participants;
  final IconData icon;
  final Color color;

  const _LiabilityItem({
    required this.title,
    required this.provider,
    required this.total,
    required this.cleared,
    required this.participants,
    required this.icon,
    required this.color,
  });

  double get percent => total > 0 ? (cleared / total) * 100 : 0;
  double get outstanding => total - cleared;
  bool get isSettled => cleared >= total;
}

class _SettledCycle {
  final String title;
  final double amount;
  final String date;

  const _SettledCycle(this.title, this.amount, this.date);
}

class _LiquidityPool {
  final String id;
  final String name;
  final String emoji;
  final String address;
  final double totalPool;
  final double clearedPool;
  final PoolStatus status;
  final int members;
  final List<_LiabilityItem> liabilities;
  final List<_SettledCycle> settledCycles;

  const _LiquidityPool({
    required this.id,
    required this.name,
    required this.emoji,
    required this.address,
    required this.totalPool,
    required this.clearedPool,
    required this.status,
    required this.members,
    required this.liabilities,
    required this.settledCycles,
  });

  double get saturation => totalPool > 0 ? (clearedPool / totalPool) * 100 : 0;
  double get outstanding => totalPool - clearedPool;

  static List<_LiquidityPool> mockPools() {
    return [
      _LiquidityPool(
        id: 'p1',
        name: 'Unit 3-12, Block A',
        emoji: '🏠',
        address: 'Residensi Harmoni, Petaling Jaya',
        totalPool: 2250.50,
        clearedPool: 1600.50,
        status: PoolStatus.pending,
        members: 3,
        liabilities: [
          _LiabilityItem(
            title: 'Monthly Rent (Feb)',
            provider: 'Landlord',
            total: 1800.00,
            cleared: 1200.00,
            participants: 3,
            icon: LucideIcons.home,
            color: AppColors.purple500,
          ),
          _LiabilityItem(
            title: 'TNB Electricity',
            provider: 'Tenaga Nasional',
            total: 284.50,
            cleared: 234.50,
            participants: 3,
            icon: LucideIcons.zap,
            color: AppColors.amber500,
          ),
          _LiabilityItem(
            title: 'Air Selangor Water',
            provider: 'Air Selangor',
            total: 166.00,
            cleared: 166.00,
            participants: 3,
            icon: LucideIcons.droplets,
            color: AppColors.blue500,
          ),
        ],
        settledCycles: [
          _SettledCycle('January Rent', 1800.00, 'Jan 31'),
          _SettledCycle('TNB Electricity (Jan)', 247.30, 'Jan 25'),
          _SettledCycle('Unifi Internet (Jan)', 139.00, 'Jan 20'),
          _SettledCycle('Air Selangor (Jan)', 58.40, 'Jan 18'),
        ],
      ),
      _LiquidityPool(
        id: 'p2',
        name: 'Unit 2-08, Block B',
        emoji: '🏡',
        address: 'Residensi Harmoni, Petaling Jaya',
        totalPool: 450.50,
        clearedPool: 450.50,
        status: PoolStatus.settled,
        members: 2,
        liabilities: [],
        settledCycles: [
          _SettledCycle('February Rent', 1400.00, 'Feb 10'),
          _SettledCycle('TNB Electricity (Feb)', 198.50, 'Feb 8'),
          _SettledCycle('Unifi Internet (Feb)', 139.00, 'Feb 5'),
        ],
      ),
      _LiquidityPool(
        id: 'p3',
        name: 'Unit 4-15, Block C',
        emoji: '🏘️',
        address: 'Residensi Harmoni, Petaling Jaya',
        totalPool: 1250.00,
        clearedPool: 500.00,
        status: PoolStatus.pending,
        members: 4,
        liabilities: [
          _LiabilityItem(
            title: 'Monthly Rent (Feb)',
            provider: 'Landlord',
            total: 1100.00,
            cleared: 500.00,
            participants: 4,
            icon: LucideIcons.home,
            color: AppColors.purple500,
          ),
          _LiabilityItem(
            title: 'Unifi Internet',
            provider: 'TM Unifi',
            total: 150.00,
            cleared: 0.00,
            participants: 4,
            icon: LucideIcons.wifi,
            color: AppColors.cyan500,
          ),
        ],
        settledCycles: [
          _SettledCycle('January Rent', 1100.00, 'Jan 28'),
          _SettledCycle('Gas Petronas (Jan)', 52.00, 'Jan 22'),
        ],
      ),
    ];
  }
}

// ─────────────────────────────────
// SCREEN
// ─────────────────────────────────

enum _ViewMode { overview, detail }

class LiquidityScreen extends StatefulWidget {
  const LiquidityScreen({super.key});

  @override
  State<LiquidityScreen> createState() => _LiquidityScreenState();
}

class _LiquidityScreenState extends State<LiquidityScreen>
    with SingleTickerProviderStateMixin {
  _ViewMode _view = _ViewMode.overview;
  _LiquidityPool? _selectedPool;
  final List<_LiquidityPool> _pools = _LiquidityPool.mockPools();
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  double get _totalLiability => _pools.fold(0.0, (sum, p) => sum + p.totalPool);
  double get _totalCleared => _pools.fold(0.0, (sum, p) => sum + p.clearedPool);
  double get _overallSaturation => _totalLiability > 0 ? (_totalCleared / _totalLiability) * 100 : 0;
  int get _pendingCount => _pools.where((p) => p.status == PoolStatus.pending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000402),
      body: Stack(
        children: [
          // Ambient emerald glow
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                height: 550,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      AppColors.emerald500.withValues(
                        alpha: 0.10 + _glowController.value * 0.04,
                      ),
                      const Color(0xFF000402),
                    ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _view == _ViewMode.overview
                      ? _buildOverview()
                      : _buildDetail(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // HEADER
  // ─────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (_view == _ViewMode.detail) {
                setState(() {
                  _view = _ViewMode.overview;
                  _selectedPool = null;
                });
              } else {
                context.pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 20),
            ),
          ),
          Row(
            children: [
              Icon(LucideIcons.droplets, size: 14, color: AppColors.emerald500.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                _view == _ViewMode.overview ? 'LIQUIDITY POOLS' : 'LIQUIDITY NODE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  // OVERVIEW VIEW
  // ══════════════════════════════════
  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Hero stats
          _buildHeroStats(),
          const SizedBox(height: 28),

          // Section label
          Row(
            children: [
              Icon(LucideIcons.layers, size: 14, color: AppColors.emerald500),
              const SizedBox(width: 8),
              Text(
                'ACTIVE POOLS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.slate500,
                ),
              ),
              const Spacer(),
              Text(
                '${_pools.length} nodes',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pool cards
          ..._pools.map((pool) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildPoolCard(pool),
          )),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Column(
      children: [
        // Title
        Text(
          'SHARED NODES',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Group financial pools across your properties',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
        ),
        const SizedBox(height: 24),

        // Overall saturation hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.emerald500.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.06), blurRadius: 30),
            ],
          ),
          child: Column(
            children: [
              Icon(LucideIcons.trendingUp, size: 32, color: AppColors.emerald400),
              const SizedBox(height: 12),
              Text(
                '${_overallSaturation.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'OVERALL SATURATION',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.emerald500.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              // Saturation bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.slate900,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: FractionallySizedBox(
                    widthFactor: _overallSaturation / 100,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        boxShadow: [
                          BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.6), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick stats row
        Row(
          children: [
            Expanded(child: _buildMiniStat(
              'RM ${_totalLiability.toStringAsFixed(0)}',
              'TOTAL LIABILITY',
              AppColors.slate400,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildMiniStat(
              'RM ${_totalCleared.toStringAsFixed(0)}',
              'SECURED',
              AppColors.emerald500,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildMiniStat(
              '$_pendingCount',
              'PENDING',
              AppColors.amber500,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.slate500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // POOL CARD
  // ─────────────────────────────────
  Widget _buildPoolCard(_LiquidityPool pool) {
    final isPending = pool.status == PoolStatus.pending;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPool = pool;
          _view = _ViewMode.detail;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            // Top row: emoji/name + amount
            Row(
              children: [
                // Group emoji
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Center(
                    child: Text(pool.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pool.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPending ? AppColors.amber500 : AppColors.emerald400,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isPending ? AppColors.amber500 : AppColors.emerald400)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPending ? 'CLEARING POOL' : 'LIQUIDITY SECURED',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: 'RM ',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate500,
                          ),
                        ),
                        TextSpan(
                          text: pool.totalPool.toStringAsFixed(2),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ]),
                    ),
                    Text(
                      'TOTAL LIABILITY',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.emerald500.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Saturation bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'POOL SATURATION',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.slate500,
                            ),
                          ),
                          Text(
                            '${pool.saturation.toStringAsFixed(0)}%',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.slate800,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: FractionallySizedBox(
                            widthFactor: pool.saturation / 100,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.emerald500,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emerald500.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: const Icon(LucideIcons.arrowRight, size: 18, color: AppColors.slate500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════
  // DETAIL VIEW
  // ══════════════════════════════════
  Widget _buildDetail() {
    final pool = _selectedPool;
    if (pool == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node saturation hero
          _buildNodeHero(pool),
          const SizedBox(height: 28),

          // Pool info
          _buildPoolInfo(pool),
          const SizedBox(height: 24),

          // Outstanding liabilities
          if (pool.liabilities.isNotEmpty) ...[
            _buildLiabilitiesSection(pool),
            const SizedBox(height: 24),
          ],

          // Settled cycles
          if (pool.settledCycles.isNotEmpty) ...[
            _buildSettledSection(pool),
            const SizedBox(height: 24),
          ],

          // Actions
          _buildDetailActions(pool),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // NODE HERO
  // ─────────────────────────────────
  Widget _buildNodeHero(_LiquidityPool pool) {
    final themeColor = pool.status == PoolStatus.settled
        ? AppColors.emerald500
        : AppColors.cyan500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: themeColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: themeColor.withValues(alpha: 0.06), blurRadius: 40),
        ],
      ),
      child: Column(
        children: [
          Icon(LucideIcons.trendingUp, size: 36, color: themeColor.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Text(
            '${pool.saturation.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NODE SATURATION',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: themeColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: FractionallySizedBox(
                widthFactor: pool.saturation / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: themeColor,
                    boxShadow: [
                      BoxShadow(color: themeColor.withValues(alpha: 0.6), blurRadius: 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // POOL INFO
  // ─────────────────────────────────
  Widget _buildPoolInfo(_LiquidityPool pool) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: Text(pool.emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pool.name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pool.members} members  •  ${pool.address}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // OUTSTANDING LIABILITIES
  // ─────────────────────────────────
  Widget _buildLiabilitiesSection(_LiquidityPool pool) {
    final outstanding = pool.liabilities.where((l) => !l.isSettled).toList();
    if (outstanding.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.fileText, size: 14, color: AppColors.cyan500),
            const SizedBox(width: 8),
            Text(
              'OUTSTANDING LIABILITY POOL',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        ...outstanding.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildLiabilityCard(item),
        )),
      ],
    );
  }

  Widget _buildLiabilityCard(_LiabilityItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: item.color.withValues(alpha: 0.2)),
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${item.participants} Nodes Integrated',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${item.total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'RM ${item.cleared.toStringAsFixed(2)} Secured',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyan500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: FractionallySizedBox(
                widthFactor: item.percent / 100,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cyan500.withValues(alpha: 0.7),
                    boxShadow: [
                      BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.4), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // SETTLED CYCLES
  // ─────────────────────────────────
  Widget _buildSettledSection(_LiquidityPool pool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.checkCircle, size: 14, color: AppColors.emerald500),
            const SizedBox(width: 8),
            Text(
              'SETTLED CYCLES',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: pool.settledCycles.asMap().entries.map((entry) {
              final i = entry.key;
              final cycle = entry.value;
              final isLast = i == pool.settledCycles.length - 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.emerald500.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${cycle.title}  •  ${cycle.date}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'RM ${cycle.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────
  // DETAIL ACTIONS
  // ─────────────────────────────────
  Widget _buildDetailActions(_LiquidityPool pool) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/dashboard'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.wallet, size: 16, color: AppColors.emerald500),
                  const SizedBox(width: 8),
                  Text(
                    'VIEW BILLS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.emerald500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/rex-interface', extra: 'maintenance'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bot, size: 16, color: AppColors.cyan500),
                  const SizedBox(width: 8),
                  Text(
                    'ASK REX',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.cyan500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
