import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

enum _HubView { dashboard, report, tribunal }

class _HonorTier {
  final String label;
  final Color color;
  final IconData icon;
  final double iconSize;
  final String perk;

  const _HonorTier(this.label, this.color, this.icon, this.iconSize, this.perk);
}

const _honorTiers = <int, _HonorTier>{
  0: _HonorTier('DISHONORABLE', AppColors.rose500, Icons.dangerous, 40, 'Penalty: Double Deposit'),
  1: _HonorTier('AT RISK', AppColors.slate400, Icons.warning_amber, 40, 'No Premium Listings'),
  2: _HonorTier('NEUTRAL', Colors.white, Icons.shield, 40, 'Standard Access'),
  3: _HonorTier('TRUSTED', AppColors.blue400, Icons.shield, 40, '+10% Trust Factor'),
  4: _HonorTier('HONORABLE', AppColors.purple500, Icons.workspace_premium, 40, 'Priority Support'),
  5: _HonorTier('PARAGON', AppColors.amber500, Icons.workspace_premium, 48, 'Zero Deposit Unlock'),
};

class _ReportCategory {
  final String id;
  final String label;
  final String sub;
  final IconData icon;
  final Color color;

  const _ReportCategory(this.id, this.label, this.sub, this.icon, this.color);
}

const _reportCategories = [
  _ReportCategory('GRIEFING', 'Griefing', 'Property Damage', Icons.shield, AppColors.rose500),
  _ReportCategory('NUISANCE', 'Toxic / Noise', 'Disturbance', Icons.mic, AppColors.orange500),
  _ReportCategory('AFK', 'AFK / Leaver', 'Financial Ghosting', Icons.no_accounts, AppColors.slate500),
  _ReportCategory('CHEATING', 'Cheating', 'Lease Violation', Icons.wifi_off, AppColors.purple500),
];

class HarmonyHubScreen extends StatefulWidget {
  final int honorLevel;

  const HarmonyHubScreen({super.key, this.honorLevel = 2});

  @override
  State<HarmonyHubScreen> createState() => _HarmonyHubScreenState();
}

class _HarmonyHubScreenState extends State<HarmonyHubScreen>
    with SingleTickerProviderStateMixin {
  _HubView _view = _HubView.dashboard;
  int _reportStep = 0;
  String? _selectedCategory;
  bool _hasActiveCase = true;
  late AnimationController _spinController;

  _HonorTier get _tier => _honorTiers[widget.honorLevel] ?? _honorTiers[2]!;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Dynamic background
          Container(
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  _tier.color.withValues(alpha: 0.15),
                  const Color(0xFF02040A),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildViewContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (_view != _HubView.dashboard) {
                setState(() {
                  _view = _HubView.dashboard;
                  _reportStep = 0;
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
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.slate500),
              const SizedBox(width: 8),
              Text(
                'STEWARDSHIP PROTOCOL',
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

  Widget _buildViewContent() {
    switch (_view) {
      case _HubView.dashboard:
        return _buildDashboard();
      case _HubView.report:
        return _buildReportFlow();
      case _HubView.tribunal:
        return _buildTribunal();
    }
  }

  // ─────────────────────────────────
  // DASHBOARD VIEW
  // ─────────────────────────────────
  Widget _buildDashboard() {
    return Column(
      children: [
        // Shield hero
        _buildShield(),

        // Progress bar
        _buildProgressBar(),
        const SizedBox(height: 32),

        // Action grid
        Row(
          children: [
            Expanded(child: _buildActionCard(
              icon: Icons.gavel,
              iconColor: AppColors.amber500,
              iconBg: AppColors.amber500.withValues(alpha: 0.1),
              iconBorder: AppColors.amber500.withValues(alpha: 0.2),
              title: 'The Tribunal',
              subtitle: 'REVIEW CASES',
              hoverBorder: AppColors.amber500.withValues(alpha: 0.5),
              onTap: () => setState(() => _view = _HubView.tribunal),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildActionCard(
              icon: Icons.warning_amber,
              iconColor: AppColors.rose500,
              iconBg: AppColors.rose500.withValues(alpha: 0.1),
              iconBorder: AppColors.rose500.withValues(alpha: 0.2),
              title: 'File Report',
              subtitle: 'LOG VIOLATION',
              hoverBorder: AppColors.rose500.withValues(alpha: 0.5),
              onTap: () => setState(() => _view = _HubView.report),
            )),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildShield() {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated rings
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _spinController.value * 2 * pi,
                child: Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_spinController.value * 2 * pi * 0.66,
                child: Container(
                  width: 256,
                  height: 256,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
              );
            },
          ),

          // Core glow
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _tier.color.withValues(alpha: 0.3),
                  blurRadius: 60,
                ),
              ],
            ),
          ),

          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _tier.icon,
                size: _tier.iconSize,
                color: _tier.color,
                shadows: [
                  Shadow(color: _tier.color.withValues(alpha: 0.5), blurRadius: 15),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'LEVEL ${widget.honorLevel}',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _tier.color),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _tier.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: _tier.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL ${widget.honorLevel}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.slate500,
              ),
            ),
            Text(
              'LEVEL ${(widget.honorLevel + 1).clamp(0, 5)}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.slate900,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              widthFactor: 0.65,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: _tier.color,
                  boxShadow: [
                    BoxShadow(
                      color: _tier.color.withValues(alpha: 0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w500),
            children: [
              const TextSpan(text: '3 Weeks Clean Streak  •  '),
              TextSpan(text: _tier.perk, style: TextStyle(color: _tier.color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
    required String title,
    required String subtitle,
    required Color hoverBorder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 144,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBorder),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // REPORT FLOW
  // ─────────────────────────────────
  Widget _buildReportFlow() {
    if (_reportStep == 0) return _buildReportCategories();
    if (_reportStep == 1) return _buildEvidenceUpload();
    return _buildReportSuccess();
  }

  Widget _buildReportCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _view = _HubView.dashboard),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 14, color: AppColors.slate500),
              const SizedBox(width: 4),
              Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'SELECT VIOLATION',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: _reportCategories.map((cat) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat.id;
                  _reportStep = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.slate900.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: cat.color.withValues(alpha: 0.3), blurRadius: 12)],
                      ),
                      child: Icon(cat.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cat.label,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      cat.sub.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400, height: 1.5),
              children: [
                TextSpan(text: 'Warning: ', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                const TextSpan(text: 'False reporting reduces your Trust Factor. Low Trust Factor reports are automatically discarded by Rex.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildEvidenceUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _reportStep = 0),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 14, color: AppColors.slate500),
              const SizedBox(width: 4),
              Text('Back', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'EVIDENCE REQUIRED',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rex AI Verification Protocol Active',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
        ),
        const SizedBox(height: 24),

        // Upload area
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.blue500.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedCategory == 'NUISANCE' ? Icons.mic : Icons.camera_alt,
                      size: 32,
                      color: AppColors.blue400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedCategory == 'NUISANCE' ? 'RECORD AUDIO SAMPLE' : 'CAPTURE PHOTO',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Submit button
        GestureDetector(
          onTap: () => setState(() => _reportStep = 2),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.red500,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.red500.withValues(alpha: 0.2), blurRadius: 20),
              ],
            ),
            child: Text(
              'SUBMIT TO TRIBUNAL',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildReportSuccess() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.check, size: 40, color: AppColors.emerald400),
            ),
            const SizedBox(height: 24),
            Text(
              'REPORT FILED',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 250,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, height: 1.5),
                  children: [
                    const TextSpan(text: 'Your report has been verified by Rex and sent to the '),
                    TextSpan(text: 'Overwatch Tribunal', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.blue400)),
                    const TextSpan(text: ' for peer review.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => setState(() {
                _view = _HubView.dashboard;
                _reportStep = 0;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'RETURN TO HUB',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // TRIBUNAL VIEW
  // ─────────────────────────────────
  Widget _buildTribunal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _view = _HubView.dashboard),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, size: 14, color: AppColors.slate500),
              const SizedBox(width: 4),
              Text('Back', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.balance, size: 24, color: AppColors.amber500),
                const SizedBox(width: 8),
                Text(
                  'OVERWATCH',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _hasActiveCase ? '1 PENDING CASE' : 'ALL CLEAR',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.amber500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (_hasActiveCase)
          _buildCaseCard()
        else
          _buildEmptyTribunal(),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildCaseCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.amber500.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.amber500.withValues(alpha: 0.05), blurRadius: 30),
        ],
      ),
      child: Column(
        children: [
          // Evidence Review tape
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber500,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                boxShadow: [BoxShadow(color: AppColors.amber500.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: Text(
                'EVIDENCE REVIEW',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Case info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OFFENSE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.slate500)),
                        Text('NUISANCE', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TIME', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.slate500)),
                        Text('2 hours ago', style: GoogleFonts.robotoMono(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Evidence viewer
                Container(
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic, size: 20, color: AppColors.slate400),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TAP TO INSPECT',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Verdict buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _hasActiveCase = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.emerald500,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.3), blurRadius: 12)],
                          ),
                          child: Text(
                            'INNOCENT',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _hasActiveCase = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.rose500,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.rose500.withValues(alpha: 0.3), blurRadius: 12)],
                          ),
                          child: Text(
                            'GUILTY',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate500),
                    children: [
                      const TextSpan(text: 'Accurate verdicts increase your '),
                      TextSpan(text: 'Trust Factor', style: TextStyle(color: AppColors.blue400)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTribunal() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 48, color: AppColors.slate500),
            const SizedBox(height: 16),
            Text('All Clear', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text('No pending cases in your queue.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }
}
