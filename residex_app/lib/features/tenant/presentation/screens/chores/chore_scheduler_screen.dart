import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class _ChoreTemplate {
  final String name;
  final String icon;
  final int points;
  final String freq;
  const _ChoreTemplate(this.name, this.icon, this.points, this.freq);
}

const _choreTemplates = [
  _ChoreTemplate('Take Out Trash', '\u{1F5D1}', 10, 'Every 3 days'),
  _ChoreTemplate('Sweep Common Areas', '\u{1F9F9}', 20, 'Weekly'),
  _ChoreTemplate('Wash Dishes', '\u{1F37D}', 15, 'Daily'),
  _ChoreTemplate('Clean Bathroom', '\u{1F9FD}', 30, 'Weekly'),
  _ChoreTemplate('Buy Supplies', '\u{1F6AE}', 20, 'Ad-hoc'),
  _ChoreTemplate('Laundry', '\u{1F9FA}', 15, 'Ad-hoc'),
  _ChoreTemplate('Water Plants', '\u{1FAB4}', 10, 'Weekly'),
  _ChoreTemplate('Vacuum', '\u{1F6AA}', 20, 'Weekly'),
  _ChoreTemplate('Mop', '\u{1F9E4}', 25, 'Weekly'),
  _ChoreTemplate('Organize Pantry', '\u{1F5C3}', 30, 'Monthly'),
];

enum ChoreStatus { pending, completed, disputed, failed }

class _Chore {
  final String id;
  final String name;
  final String icon;
  final int points;
  final String assignedTo;
  final String time;
  ChoreStatus status;
  final String dateKey;

  _Chore({
    required this.id,
    required this.name,
    required this.icon,
    required this.points,
    required this.assignedTo,
    required this.time,
    required this.status,
    required this.dateKey,
  });
}

class ChoreSchedulerScreen extends StatefulWidget {
  final bool isFullPage;

  const ChoreSchedulerScreen({super.key, this.isFullPage = true});

  @override
  State<ChoreSchedulerScreen> createState() => _ChoreSchedulerScreenState();
}

class _ChoreSchedulerScreenState extends State<ChoreSchedulerScreen> {
  late DateTime _currentDate;
  late DateTime _selectedDate;
  bool _showAddModal = false;
  _Chore? _showDisputeModal;
  bool _disputeEvidenceCaptured = false;

  // Creation state
  String _newChoreName = '';
  String _newChoreIcon = '';
  int _newChorePoints = 10;
  String _newChoreAssignee = '';
  String _newChoreTime = '09:00';

  // Mock tenants
  final _mockTenants = [
    {'id': 'u1', 'name': 'You', 'initials': 'YO', 'color': AppColors.indigo500},
    {'id': 'u2', 'name': 'Sarah', 'initials': 'ST', 'color': AppColors.pink500},
    {'id': 'u3', 'name': 'Raj', 'initials': 'RK', 'color': AppColors.emerald500},
  ];

  late List<_Chore> _allChores;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _selectedDate = DateTime.now();
    final todayKey = _dateToKey(DateTime.now());
    _allChores = [
      _Chore(id: '1', name: 'Kitchen Duty', icon: '\u{1F37D}', points: 15, assignedTo: 'u1', time: '09:00 AM', status: ChoreStatus.completed, dateKey: todayKey),
      _Chore(id: '2', name: 'Trash Disposal', icon: '\u{1F5D1}', points: 10, assignedTo: 'u3', time: '08:00 PM', status: ChoreStatus.pending, dateKey: todayKey),
      _Chore(id: '3', name: 'Mop Floors', icon: '\u{1F9E4}', points: 25, assignedTo: 'u2', time: '10:00 AM', status: ChoreStatus.disputed, dateKey: todayKey),
    ];
  }

  String _dateToKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_Chore> get _filteredChores => _allChores.where((c) => c.dateKey == _dateToKey(_selectedDate)).toList();

  void _toggleChoreStatus(String id) {
    setState(() {
      final chore = _allChores.firstWhere((c) => c.id == id);
      if (chore.status == ChoreStatus.pending) {
        chore.status = ChoreStatus.completed;
      } else if (chore.status == ChoreStatus.completed) {
        chore.status = ChoreStatus.pending;
      }
    });
  }

  void _createChore() {
    if (_newChoreName.isEmpty || _newChoreAssignee.isEmpty) return;
    setState(() {
      _allChores.add(_Chore(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _newChoreName,
        icon: _newChoreIcon.isEmpty ? '\u{1F4CC}' : _newChoreIcon,
        points: _newChorePoints,
        assignedTo: _newChoreAssignee,
        time: _newChoreTime,
        status: ChoreStatus.pending,
        dateKey: _dateToKey(_selectedDate),
      ));
      _showAddModal = false;
      _newChoreName = '';
      _newChoreIcon = '';
      _newChorePoints = 10;
      _newChoreAssignee = '';
      _newChoreTime = '09:00';
    });
  }

  void _submitDispute() {
    if (_showDisputeModal == null || !_disputeEvidenceCaptured) return;
    setState(() {
      final chore = _allChores.firstWhere((c) => c.id == _showDisputeModal!.id);
      chore.status = ChoreStatus.disputed;
      _showDisputeModal = null;
      _disputeEvidenceCaptured = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020205),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: 0, left: 0, right: 0, height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.purple500.withValues(alpha: 0.2),
                    const Color(0xFF020205),
                  ],
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildCalendar(),
                        const SizedBox(height: 24),
                        _buildTasksHeader(),
                        const SizedBox(height: 12),
                        _buildChoreList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Modals
          if (_showAddModal) _buildAddModal(),
          if (_showDisputeModal != null) _buildDisputeModal(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, size: 20, color: AppColors.slate400),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHARED CALENDAR',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'SCHEDULE OF OPERATIONS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.purple500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showAddModal = true),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purple500,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.purple500.withValues(alpha: 0.2), blurRadius: 12)],
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final firstDay = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Month nav
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${months[month - 1]} ',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        TextSpan(
                          text: '$year',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.purple500),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _calNavButton(Icons.chevron_left, () {
                        setState(() => _currentDate = DateTime(year, month - 1, 1));
                      }),
                      const SizedBox(width: 8),
                      _calNavButton(Icons.chevron_right, () {
                        setState(() => _currentDate = DateTime(year, month + 1, 1));
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Day headers
              Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              // Calendar grid
              ...List.generate(6, (week) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: List.generate(7, (day) {
                      final index = week * 7 + day;
                      final dayNum = index - firstDay + 1;
                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 44));
                      }
                      final date = DateTime(year, month, dayNum);
                      final isSelected = _dateToKey(date) == _dateToKey(_selectedDate);
                      final hasChores = _allChores.any((c) => c.dateKey == _dateToKey(date));

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 44,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.purple500
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? Border.all(color: AppColors.purple500.withValues(alpha: 0.7))
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppColors.purple500.withValues(alpha: 0.3), blurRadius: 12)]
                                  : null,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? Colors.white : AppColors.slate400,
                                  ),
                                ),
                                if (hasChores && !isSelected)
                                  Positioned(
                                    bottom: 6,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.purple500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, size: 18, color: AppColors.slate400),
      ),
    );
  }

  Widget _buildTasksHeader() {
    final dayMonth = '${_selectedDate.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_selectedDate.month - 1]}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'TASKS FOR $dayMonth'.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  Widget _buildChoreList() {
    final chores = _filteredChores;
    if (chores.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            'NO TASKS SCHEDULED',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppColors.slate500,
            ),
          ),
        ),
      );
    }

    return Column(
      children: chores.map((chore) => _buildChoreItem(chore)).toList(),
    );
  }

  Widget _buildChoreItem(_Chore chore) {
    final tenant = _mockTenants.firstWhere(
      (t) => t['id'] == chore.assignedTo,
      orElse: () => {'id': '', 'name': 'You', 'initials': 'YO', 'color': AppColors.slate700},
    );

    Color bgColor, borderColor, iconBg, iconColor, barColor;
    switch (chore.status) {
      case ChoreStatus.completed:
        bgColor = AppColors.emerald500.withValues(alpha: 0.05);
        borderColor = AppColors.emerald500.withValues(alpha: 0.2);
        iconBg = AppColors.emerald500.withValues(alpha: 0.2);
        iconColor = AppColors.emerald400;
        barColor = AppColors.emerald500;
        break;
      case ChoreStatus.disputed:
        bgColor = AppColors.orange500.withValues(alpha: 0.05);
        borderColor = AppColors.orange500.withValues(alpha: 0.3);
        iconBg = AppColors.orange500.withValues(alpha: 0.2);
        iconColor = AppColors.orange500;
        barColor = AppColors.orange500;
        break;
      case ChoreStatus.failed:
        bgColor = AppColors.red500.withValues(alpha: 0.05);
        borderColor = AppColors.red500.withValues(alpha: 0.3);
        iconBg = AppColors.red500.withValues(alpha: 0.2);
        iconColor = AppColors.red500;
        barColor = AppColors.red500;
        break;
      default:
        bgColor = AppColors.slate800.withValues(alpha: 0.4);
        borderColor = Colors.white.withValues(alpha: 0.05);
        iconBg = AppColors.slate700.withValues(alpha: 0.5);
        iconColor = AppColors.slate500;
        barColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              // Status bar
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 4, color: barColor),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Toggle button
                    GestureDetector(
                      onTap: (chore.status == ChoreStatus.disputed || chore.status == ChoreStatus.failed)
                          ? null
                          : () => _toggleChoreStatus(chore.id),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          chore.status == ChoreStatus.completed
                              ? Icons.check_circle
                              : chore.status == ChoreStatus.disputed
                                  ? Icons.help
                                  : chore.status == ChoreStatus.failed
                                      ? Icons.close
                                      : Icons.radio_button_unchecked,
                          size: 24,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${chore.icon} ${chore.name}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: chore.status == ChoreStatus.completed
                                  ? AppColors.slate500
                                  : Colors.white,
                              decoration: chore.status == ChoreStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 10, color: AppColors.purple500),
                              const SizedBox(width: 4),
                              Text(
                                chore.time,
                                style: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.slate400),
                              ),
                              if (chore.status == ChoreStatus.disputed) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange500.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '2H LEFT TO FIX',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.orange500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Dispute button (only if completed)
                    if (chore.status == ChoreStatus.completed)
                      GestureDetector(
                        onTap: () => setState(() => _showDisputeModal = chore),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.slate800,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: const Icon(Icons.warning_amber, size: 14, color: AppColors.slate500),
                        ),
                      ),

                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tenant['color'] as Color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate900, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                      child: Center(
                        child: Text(
                          tenant['initials'] as String,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // ADD CHORE MODAL
  // ─────────────────────────────────
  Widget _buildAddModal() {
    return GestureDetector(
      onTap: () => setState(() => _showAddModal = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.95),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.purple500.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30)],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SCHEDULE TASK',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showAddModal = false),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 20, color: AppColors.slate400),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Templates grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _choreTemplates.length,
                        itemBuilder: (context, i) {
                          final t = _choreTemplates[i];
                          final isSelected = _newChoreName == t.name;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _newChoreName = t.name;
                              _newChoreIcon = t.icon;
                              _newChorePoints = t.points;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.purple500.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.purple500
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(t.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          t.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isSelected ? Colors.white : AppColors.slate500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${t.points} HP',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.purple500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Assignee dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _newChoreAssignee.isEmpty ? null : _newChoreAssignee,
                            hint: Text('ASSIGN TO', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF0F172A),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                            items: _mockTenants.map((t) {
                              return DropdownMenuItem(
                                value: t['id'] as String,
                                child: Text((t['name'] as String).toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _newChoreAssignee = val ?? ''),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create button
                      GestureDetector(
                        onTap: _createChore,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.blue600, AppColors.purple500],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: AppColors.purple500.withValues(alpha: 0.3), blurRadius: 20)],
                          ),
                          child: Text(
                            'CREATE TASK',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────
  // DISPUTE MODAL
  // ─────────────────────────────────
  Widget _buildDisputeModal() {
    return GestureDetector(
      onTap: () => setState(() {
        _showDisputeModal = null;
        _disputeEvidenceCaptured = false;
      }),
      child: Container(
        color: Colors.black.withValues(alpha: 0.95),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.orange500.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.orange500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.orange500.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.shield, size: 32, color: AppColors.orange500),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DISPUTE TASK',
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
                        children: [
                          const TextSpan(text: 'You are flagging '),
                          TextSpan(
                            text: '"${_showDisputeModal!.name}"',
                            style: const TextStyle(color: AppColors.orange500, fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' as incomplete. Evidence is mandatory.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Evidence capture
                    GestureDetector(
                      onTap: () => setState(() => _disputeEvidenceCaptured = true),
                      child: Container(
                        height: 128,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _disputeEvidenceCaptured
                                ? AppColors.emerald500.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: _disputeEvidenceCaptured
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 32, color: AppColors.emerald400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'EVIDENCE SECURED',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.emerald400),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt, size: 24, color: AppColors.slate500),
                                    const SizedBox(height: 8),
                                    Text(
                                      'CAPTURE PROOF',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.slate600),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _showDisputeModal = null;
                              _disputeEvidenceCaptured = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.slate800,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'CANCEL',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.slate400),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _disputeEvidenceCaptured ? _submitDispute : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _disputeEvidenceCaptured
                                    ? AppColors.orange500
                                    : AppColors.orange500.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _disputeEvidenceCaptured
                                    ? [BoxShadow(color: AppColors.orange500.withValues(alpha: 0.2), blurRadius: 12)]
                                    : null,
                              ),
                              child: Text(
                                'SUBMIT REPORT',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
