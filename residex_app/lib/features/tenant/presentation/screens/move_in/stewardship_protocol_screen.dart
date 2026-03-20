import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';

  // ─── Lightweight models ──────────────────────────────────────────────────────

  class _Housemate {
    final String id;
    final String name;
    final String initials;
    final Color color;
    final int strikeCount; // nudges received in last 48h (mock)
    const _Housemate({
      required this.id,
      required this.name,
      required this.initials,
      required this.color,
      this.strikeCount = 0,
    });
  }

  class _NudgeCat {
    final String id;
    final String label;
    final String sub;
    final IconData icon;
    final Color color;
    const _NudgeCat(this.id, this.label, this.sub, this.icon, this.color);
  }

  // ─── Screen ──────────────────────────────────────────────────────────────────

  class StewardshipProtocolScreen extends StatefulWidget {
    const StewardshipProtocolScreen({super.key});

    @override
    State<StewardshipProtocolScreen> createState() =>
        _StewardshipProtocolScreenState();
  }

  class _StewardshipProtocolScreenState
      extends State<StewardshipProtocolScreen> {
    // 0=select roommate, 1=select category, 2=confirm,
    // 3=success OR tribunal, 4=vote result
    int _step = 0;
    _Housemate? _selectedRoommate;
    _NudgeCat? _selectedCategory;
    bool _tribunalInitiated = false;
    bool _agreedVote = false;

    // ── Mock housemates ─────────────────────────────────────────────────────────
    final List<_Housemate> _housemates = const [
      _Housemate(
        id: 'u2', name: 'Sarah Tan', initials: 'ST',
        color: Color(0xFF8B5CF6), strikeCount: 0,
      ),
      _Housemate(
        id: 'u3', name: 'Raj Kumar', initials: 'RK',
        color: Color(0xFFEF4444), strikeCount: 2, // next nudge triggers tribunal
      ),
      _Housemate(
        id: 'u4', name: 'David Wong', initials: 'DW',
        color: Color(0xFF10B981), strikeCount: 0,
      ),
    ];

    // Mock cooldowns: roommateId → categoryId → minutesRemaining
    final Map<String, Map<String, int>> _cooldowns = {
      'u3': {'noise': 50}, // Raj has a noise cooldown active
    };

    // Mock prior strike log (shown in tribunal screen)
    final List<Map<String, String>> _mockStrikeLog = const [
      {'cat': 'Noise', 'time': '2 days ago'},
      {'cat': 'Unwashed Dishes', 'time': '18 hours ago'},
    ];

    // ── Nudge categories ────────────────────────────────────────────────────────
    final List<_NudgeCat> _categories = const [
   _NudgeCat('noise',    'Noise',                    'TOO LOUD',  LucideIcons.volume2,    Color(0xFFF59E0B)),
   _NudgeCat('dishes',   'Unwashed Dishes',           'KITCHEN',   LucideIcons.utensils,   Color(0xFF3B82F6)),
   _NudgeCat('trash',    'Full Trash',                'HYGIENE',   LucideIcons.trash2,     Color(0xFF10B981)),
   _NudgeCat('toilet',   'Toilet Cleanliness',        'HYGIENE',   LucideIcons.sparkles,   Color(0xFF8B5CF6)),
   _NudgeCat('laundry',  'Misplaced Laundry',         'SHARED',    LucideIcons.shirt,      Color(0xFF06B6D4)),
   _NudgeCat('door',     'Front Door Unlocked',       'SECURITY',  LucideIcons.unlock,     Color(0xFFEF4444)),
   _NudgeCat('borrow',   'Borrowing Without Asking',  'RESPECT',   LucideIcons.package2,   Color(0xFFF97316)),
   _NudgeCat('guest',    'Unannounced Guests',        'RULES',     LucideIcons.users,      Color(0xFFEC4899)),
 ];

    // ── Helpers ─────────────────────────────────────────────────────────────────
    bool _hasCooldown(_Housemate h, _NudgeCat c) =>
        (_cooldowns[h.id]?[c.id] ?? 0) > 0;

    int _cooldownMins(_Housemate h, _NudgeCat c) =>
        _cooldowns[h.id]?[c.id] ?? 0;

    bool get _willTriggerTribunal =>
        (_selectedRoommate?.strikeCount ?? 0) >= 2;

 String _nudgeMessage(_NudgeCat c) {
    switch (c.id) {
     case 'noise':   return 'Could we keep the noise level down a little?';
     case 'dishes':  return 'Could we clean up the dishes in the kitchen?';
     case 'trash':   return 'The trash bin is full — could we empty it today?';
     case 'toilet':  return 'Could we keep the toilet clean after use?';
     case 'laundry': return 'Could we move laundry back to the right place?';
     case 'door':    return 'A reminder to lock the front door when leaving — let\'s keep the house secure!';
     case 'borrow':  return 'Could we check in before borrowing shared items? Thanks for being considerate!';
     case 'guest':   return 'A heads-up would help — could we give notice before having overnight guests?';
     default:        return 'Could we be a bit more considerate?';
   }
 }

    static const _indigo = AppColors.indigo500;
    static const _green = Color(0xFF10B981);

    // ── BUILD ───────────────────────────────────────────────────────────────────
    @override
    Widget build(BuildContext context) {
      final glowColor = (_step >= 3 && _tribunalInitiated) ? AppColors.rose500 : _indigo;
      return Scaffold(
        backgroundColor: const Color(0xFF02040A),
        body: Stack(
          children: [
            Container(
              height: 500,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [glowColor.withValues(alpha: 0.08), const Color(0xFF02040A)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildStep(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── HEADER ──────────────────────────────────────────────────────────────────
    Widget _buildHeader() {
      String tag; Color tagColor;
      if (_step == 0)      { tag = 'Residex';      tagColor = _indigo; }
      else if (_step == 1) { tag = 'PHASE 1';   tagColor = _indigo; }
      else if (_step == 2) { tag = 'REVIEW';    tagColor = _indigo; }
      else if (_step == 3 && _tribunalInitiated) { tag = 'TRIBUNAL'; tagColor = AppColors.rose500; }
      else if (_step == 3) { tag = 'SENT';      tagColor = _green; }
      else                 { tag = 'VERDICT';   tagColor = _agreedVote ? AppColors.rose500 : _green; }

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                if (_step == 0 || _step >= 3) context.pop();
                else setState(() => _step--);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle,
                ),
                child: Icon(_step == 0 ? Icons.close : Icons.arrow_back,
                    color: AppColors.slate400, size: 20),
              ),
            ),
            if (_step < 3)
              Row(
                children: List.generate(3, (i) => Container(
                  width: i == _step ? 24 : 8,
                  height: 4,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: i <= _step ? _indigo : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
              )
            else
              const SizedBox(width: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tagColor.withValues(alpha: 0.3)),
              ),
              child: Text(tag, style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w900,
                color: tagColor, letterSpacing: 1.5,
              )),
            ),
          ],
        ),
      );
    }

    Widget _buildStep() {
      switch (_step) {
        case 0: return _buildSelectRoommate();
        case 1: return _buildSelectCategory();
        case 2: return _buildConfirm();
        case 3: return _tribunalInitiated ? _buildTribunal() : _buildSuccess();
        case 4: return _buildVoteResult();
        default: return const SizedBox();
      }
    }

    // ── STEP 0: SELECT ROOMMATE ─────────────────────────────────────────────────
    Widget _buildSelectRoommate() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('WHO TO NUDGE?', style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, color: Colors.white,
          )),
          const SizedBox(height: 4),
          Text('Select a housemate to send an anonymous Residex nudge',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(height: 20),
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _indigo.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shield, size: 14, color: _indigo),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'All nudges are anonymous. Custom messages are disabled to prevent abuse.',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _indigo, height: 1.5,
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._housemates.map(_buildRoommateCard),
          const SizedBox(height: 100),
        ],
      );
    }

    Widget _buildRoommateCard(_Housemate h) {
      return GestureDetector(
        onTap: () => setState(() { _selectedRoommate = h; _step = 1; }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: h.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: h.color.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(child: Text(h.initials, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w900, color: h.color,
                ))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name, style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                    )),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('48h strikes: ', style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.slate500,
                        )),
                        ...List.generate(3, (i) => Container(
                          width: 10, height: 10,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < h.strikeCount
                                ? AppColors.rose500
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        )),
                        Text('${h.strikeCount}/3', style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: h.strikeCount >= 2 ? AppColors.rose500 : AppColors.slate500,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: AppColors.slate600),
            ],
          ),
        ),
      );
    }

    // ── STEP 1: SELECT CATEGORY ─────────────────────────────────────────────────
    Widget _buildSelectCategory() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Roommate chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedRoommate!.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _selectedRoommate!.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _selectedRoommate!.color.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(
                    _selectedRoommate!.initials[0],
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: _selectedRoommate!.color,
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text('Nudging ${_selectedRoommate!.name}',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _selectedRoommate!.color,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text("WHAT'S THE ISSUE?", style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, color: Colors.white,
          )),
          const SizedBox(height: 4),
          Text('Custom text is disabled to keep nudges neutral and non-confrontational',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: _categories.map((cat) {
              final hasCd = _hasCooldown(_selectedRoommate!, cat);
              final mins  = _cooldownMins(_selectedRoommate!, cat);
              return GestureDetector(
                onTap: () {
                  if (hasCd) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'Nudge already sent. Please allow time for your housemate to respond. You can nudge again in $mins minutes.',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: _indigo,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                    return;
                  }
                  setState(() { _selectedCategory = cat; _step = 2; });
                },
                child: Opacity(
                  opacity: hasCd ? 0.45 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.slate900.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: hasCd ? 0.04 : 0.08)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cat.color.withValues(alpha: 0.25)),
                          ),
                          child: Icon(cat.icon, size: 22, color: cat.color),
                        ),
                        const SizedBox(height: 10),
                        Text(cat.label, style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
                        ), textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        Text(
                          hasCd ? '${mins}m cooldown' : cat.sub,
                          style: GoogleFonts.inter(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            letterSpacing: hasCd ? 0.5 : 1.2,
                            color: hasCd ? _indigo : AppColors.slate500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 100),
        ],
      );
    }

    // ── STEP 2: CONFIRM ─────────────────────────────────────────────────────────
    Widget _buildConfirm() {
      final cat      = _selectedCategory!;
      final roommate = _selectedRoommate!;
      final nextStrike = roommate.strikeCount + 1;
      final isTribunal = _willTriggerTribunal;
      final accentColor = isTribunal ? AppColors.rose500 : _indigo;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('NUDGE PREVIEW', style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, color: Colors.white,
          )),
          const SizedBox(height: 4),
          Text('This is what ${roommate.name} will receive anonymously',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
          const SizedBox(height: 28),
          // Notification preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _indigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.bell, size: 18, color: _indigo),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Residex House Nudge', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                        Text('Anonymous · Just now', style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.slate500,
                        )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Hey! The house is requesting a quick favor: ${_nudgeMessage(cat)} Thanks for keeping the Sync Score green! 🙏',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Anonymous badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.eyeOff, size: 13, color: AppColors.slate400),
                const SizedBox(width: 8),
                Text('Your identity is fully hidden', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate400,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Strike counter / tribunal warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isTribunal ? LucideIcons.alertTriangle : LucideIcons.activity,
                      size: 14, color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      isTribunal
                          ? '3RD STRIKE — TRIBUNAL WILL BE INITIATED'
                          : 'STRIKE $nextStrike / 3  IN THE LAST 48H',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        letterSpacing: 1, color: accentColor,
                      ),
                    )),
                  ],
                ),
                if (isTribunal) ...[
                  const SizedBox(height: 8),
                  Text(
                    "This nudge won't reach ${roommate.name}. Instead, uninvolved housemates will vote on a behavioral penalty.",
                    style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.rose500.withValues(alpha: 0.8), height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          // CTA
          GestureDetector(
            onTap: () => setState(() {
              _tribunalInitiated = isTribunal;
              _step = 3;
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor, accentColor.withValues(alpha: 0.85),
                ]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                  color: accentColor.withValues(alpha: 0.3), blurRadius: 20,
                )],
              ),
              child: Text(
                isTribunal ? 'INITIATE TRIBUNAL' : 'SEND NUDGE',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  letterSpacing: 2, color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      );
    }

    // ── STEP 3a: SUCCESS ─────────────────────────────────────────────────────────
    Widget _buildSuccess() {
      final cat = _selectedCategory!;
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _green.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.2), blurRadius: 30)],
                ),
                child: const Icon(Icons.check, size: 40, color: _green),
              ),
              const SizedBox(height: 24),
              Text('NUDGE SENT', style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic, color: Colors.white,
              )),
              const SizedBox(height: 8),
              Text(
                '${_selectedRoommate!.name} will receive an anonymous notification',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
              ),
              const SizedBox(height: 24),
              Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _infoRow(LucideIcons.clock,  'Cooldown',    '1 hour for ${cat.label}'),
                    const SizedBox(height: 12),
                    _infoRow(LucideIcons.eyeOff, 'Identity',    'Hidden from recipient'),
                    const SizedBox(height: 12),
                    _infoRow(LucideIcons.activity, 'Strike count',
                        '${_selectedRoommate!.strikeCount + 1}/3 this 48h window'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _backButton(),
            ],
          ),
        ),
      );
    }

    // ── STEP 3b: TRIBUNAL ────────────────────────────────────────────────────────
    Widget _buildTribunal() {
      final strikeLog = [
        ..._mockStrikeLog,
        {'cat': _selectedCategory!.label, 'time': 'Just now'},
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.rose500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose500.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: AppColors.rose500.withValues(alpha: 0.25), blurRadius: 30)],
              ),
              child: const Icon(Icons.gavel, size: 32, color: AppColors.rose500),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text('TRIBUNAL INITIATED', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic, color: Colors.white,
          ))),
          const SizedBox(height: 8),
          Center(child: Text(
            '${_selectedRoommate!.name} has received 3 behavioral nudges in 48 hours',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
          )),
          const SizedBox(height: 28),
          Text('48-HOUR NUDGE LOG', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w900,
            letterSpacing: 2, color: AppColors.slate500,
          )),
          const SizedBox(height: 12),
          ...strikeLog.asMap().entries.map((e) =>
              _strikeEntry(e.key + 1, e.value['cat']!, e.value['time']!)),
          const SizedBox(height: 28),
          // Jury vote card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.rose500.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.rose500.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.users, size: 14, color: AppColors.rose500),
                    const SizedBox(width: 8),
                    Text('JURY VOTE', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      letterSpacing: 2, color: AppColors.rose500,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Rex Alert: ${_selectedRoommate!.name} has received 3 behavioral nudges in 48 hours (${strikeLog.map((e) => e['cat']).join(', ')}). Residex has auto-escalated this to a Tribunal Vote. Do you agree this behavior warrants a penalty?",
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Majority AGREE → ${_selectedRoommate!.name} loses -15 Harmony Points',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.slate400, height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() { _agreedVote = true; _step = 4; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.rose500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.rose500.withValues(alpha: 0.4)),
                        ),
                        child: Text('AGREE', textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              letterSpacing: 1.5, color: AppColors.rose500,
                            )),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() { _agreedVote = false; _step = 4; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text('DISMISS', textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              letterSpacing: 1.5, color: AppColors.slate400,
                            )),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      );
    }

    Widget _strikeEntry(int num, String cat, String time) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.slate900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.rose500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text('$num', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.rose500,
              ))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(cat, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
            ))),
            Text(time, style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500)),
          ],
        ),
      );
    }

    // ── STEP 4: VOTE RESULT ──────────────────────────────────────────────────────
    Widget _buildVoteResult() {
      final color = _agreedVote ? AppColors.rose500 : _green;
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  _agreedVote ? Icons.gavel : Icons.check,
                  size: 36, color: color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _agreedVote ? 'VOTE CAST: AGREE' : 'VOTE CAST: DISMISS',
                style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic, color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (_agreedVote) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose500.withValues(alpha: 0.3)),
                  ),
                  child: Text('-15 HARMONY POINTS APPLIED', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w900,
                    color: AppColors.rose500, letterSpacing: 1,
                  )),
                ),
                const SizedBox(height: 12),
                SizedBox(width: 280, child: Text(
                  "This penalty is reflected on ${_selectedRoommate!.name}'s Residex Tenant Resume and affects future rental prospects.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, height: 1.6),
                )),
              ] else
                SizedBox(width: 280, child: Text(
                  'Your vote to dismiss has been recorded. No penalty will be applied at this time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, height: 1.6),
                )),
              const SizedBox(height: 32),
              _backButton(),
            ],
          ),
        ),
      );
    }

    // ── Shared widgets ───────────────────────────────────────────────────────────
    Widget _backButton() => GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text('BACK TO SUPPORT', style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w900,
          letterSpacing: 2, color: Colors.white,
        )),
      ),
    );

    Widget _infoRow(IconData icon, String title, String value) {
      return Row(
        children: [
          Icon(icon, size: 14, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.slate400,
          ))),
          Text(value, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: _green,
          )),
        ],
      );
    }
  }
