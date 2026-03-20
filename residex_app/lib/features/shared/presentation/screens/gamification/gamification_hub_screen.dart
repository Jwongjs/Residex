import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class _AgentSlide {
  final String id;
  final String name;
  final String role;
  final Color accentColor;
  final String description;
  final IconData mainIcon;
  final List<_StatItem> stats;
  final List<_Ability> abilities;
  _AgentSlide({
    required this.id,
    required this.name,
    required this.role,
    required this.accentColor,
    required this.description,
    required this.mainIcon,
    required this.stats,
    required this.abilities,
  });
}

class _StatItem {
  final String label;
  final String value;
  _StatItem(this.label, this.value);
}

class _Ability {
  final String name;
  final String desc;
  final IconData icon;
  _Ability(this.name, this.desc, this.icon);
}

class GamificationHubScreen extends StatefulWidget {
  const GamificationHubScreen({super.key});

  @override
  State<GamificationHubScreen> createState() => _GamificationHubScreenState();
}

class _GamificationHubScreenState extends State<GamificationHubScreen> {
  int _activeIndex = 0;
  bool _isChanging = false;

  final _agents = [
    _AgentSlide(
      id: 'profile',
      name: 'YOU',
      role: 'MASTER SPLITTER',
      accentColor: AppColors.indigo500,
      description: 'A legendary figure in the Malaysian splitting scene. Known for precise calculations and lightning-fast DuitNow confirmations.',
      mainIcon: Icons.person,
      stats: [_StatItem('TRUST SCORE', '850'), _StatItem('GLOBAL RANK', '#47')],
      abilities: [
        _Ability('Precision Split', 'Can calculate service tax up to 3 decimal places.', Icons.gps_fixed),
        _Ability('Social Magnet', 'Invites are 40% more likely to be accepted.', Icons.emoji_events),
      ],
    ),
    _AgentSlide(
      id: 'ironbank',
      name: 'IRON BANK',
      role: 'SENTINEL',
      accentColor: AppColors.amber500,
      description: 'Awarded to those with unwavering financial integrity. Never disputed a bill and maintains a massive Trust Score.',
      mainIcon: Icons.shield,
      stats: [_StatItem('TIER', 'GOLD'), _StatItem('RARITY', '12.5%')],
      abilities: [
        _Ability('Debt Immunity', 'Debts are highlighted in gold for better visibility.', Icons.shield),
        _Ability('Merchant Trust', 'Faster verification for high-value bills.', Icons.workspace_premium),
      ],
    ),
    _AgentSlide(
      id: 'speedy',
      name: 'SPEEDY SETTLER',
      role: 'DUELIST',
      accentColor: AppColors.slate400,
      description: 'The fastest hands in the West of Malaysia. Settle debts before the receipt ink is even dry. A DuitNow speedrun champion.',
      mainIcon: Icons.bolt,
      stats: [_StatItem('AVG SPEED', '< 1 HR'), _StatItem('RARITY', '18.5%')],
      abilities: [
        _Ability('Sonic Settle', 'Confirmation time reduced by 90% globally.', Icons.bolt),
        _Ability('Mamak Dash', 'Unlock special high-contrast themes for night bills.', Icons.gps_fixed),
      ],
    ),
  ];

  void _switchAgent(int idx) {
    if (idx == _activeIndex) return;
    setState(() => _isChanging = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _activeIndex = idx;
          _isChanging = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _agents[_activeIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic gradient glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [current.accentColor.withValues(alpha: 0.15), Colors.transparent],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(current),
                Expanded(child: _buildAgentContent(current)),
                _buildAbilitiesDrawer(current),
                _buildCharacterSelector(),
              ],
            ),
          ),

          // Background name text
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _isChanging ? 0 : 0.03,
                  child: Text(
                    current.name,
                    style: GoogleFonts.inter(fontSize: 120, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white),
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(_AgentSlide current) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.public, size: 20, color: current.accentColor),
              const SizedBox(width: 10),
              Text('CHECKPOINT // 2025',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 3, color: Colors.white)),
            ],
          ),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentContent(_AgentSlide current) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _isChanging ? 0 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        scale: _isChanging ? 0.95 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main graphic
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current.accentColor.withValues(alpha: 0.1),
                border: Border.all(color: current.accentColor.withValues(alpha: 0.3), width: 4),
                boxShadow: [BoxShadow(color: current.accentColor.withValues(alpha: 0.2), blurRadius: 50)],
              ),
              child: Icon(current.mainIcon, size: 80, color: current.accentColor),
            ),
            const SizedBox(height: 32),

            // Role label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(current.role,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2, color: current.accentColor)),
            ),
            const SizedBox(height: 12),

            // Name
            Text(current.name,
                style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: -2)),
            const SizedBox(height: 16),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(current.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilitiesDrawer(_AgentSlide current) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      offset: _isChanging ? const Offset(0, 1) : Offset.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.slate900.withValues(alpha: 0.4),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Column(
          children: [
            // Stats row
            Row(
              children: [
                ...current.stats.map((stat) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat.label,
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.slate500)),
                      const SizedBox(height: 4),
                      Text(stat.value,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                )),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.share, size: 20, color: current.accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Abilities grid
            Row(
              children: current.abilities.map((ability) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: ability == current.abilities.last ? 0 : 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(ability.icon, size: 18, color: current.accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ability.name,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(ability.desc,
                                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.slate500, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_agents.length, (i) {
          final agent = _agents[i];
          final isActive = i == _activeIndex;
          return GestureDetector(
            onTap: () => _switchAgent(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? agent.accentColor : Colors.white.withValues(alpha: 0.1),
                  width: 2,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: agent.accentColor.withValues(alpha: 0.4), blurRadius: 20)]
                    : null,
              ),
              child: Stack(
                children: [
                  Container(
                    color: AppColors.slate900,
                    child: Center(
                      child: isActive
                          ? Icon(agent.mainIcon, size: 24, color: agent.accentColor)
                          : Opacity(
                              opacity: 0.4,
                              child: Icon(agent.mainIcon, size: 24, color: Colors.white),
                            ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(height: 3, color: agent.accentColor),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
