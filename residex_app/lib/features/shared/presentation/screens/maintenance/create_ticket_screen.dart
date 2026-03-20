import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';
import 'maintenance_list_screen.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  int _step = 0; // 0=category, 1=details, 2=success
  TicketCategory? _selectedCategory;
  TicketUrgency _selectedUrgency = TicketUrgency.medium;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  int _mockPhotoCount = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 500,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  AppColors.indigo500.withValues(alpha: 0.10),
                  const Color(0xFF02040A),
                ],
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
                    child: _buildStepContent(),
                  ),
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
              if (_step > 0 && _step < 2) {
                setState(() => _step--);
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
              child: Icon(
                _step == 0 ? Icons.close : Icons.arrow_back,
                color: AppColors.slate400,
                size: 20,
              ),
            ),
          ),
          // Step indicator
          Row(
            children: List.generate(3, (i) {
              final isActive = i <= _step;
              return Container(
                width: i == _step ? 24 : 8,
                height: 4,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.indigo500
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildSuccessStep();
      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────────
  // STEP 1: CATEGORY SELECTION
  // ─────────────────────────────────
  Widget _buildCategoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'WHAT BROKE?',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the category that best describes the issue',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
        ),
        const SizedBox(height: 28),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: TicketCategory.values.map((cat) {
            final meta = categoryMeta[cat]!;
            final isSelected = _selectedCategory == cat;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  _step = 1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? meta.color.withValues(alpha: 0.1)
                      : AppColors.slate900.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected
                        ? meta.color.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: meta.color.withValues(alpha: 0.1), blurRadius: 20)]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: meta.color.withValues(alpha: 0.25)),
                        boxShadow: [BoxShadow(color: meta.color.withValues(alpha: 0.15), blurRadius: 12)],
                      ),
                      child: Icon(meta.icon, size: 22, color: meta.color),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      meta.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.sub,
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
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // ─────────────────────────────────
  // STEP 2: DETAILS
  // ─────────────────────────────────
  Widget _buildDetailsStep() {
    final meta = categoryMeta[_selectedCategory]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Selected category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: meta.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: meta.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meta.icon, size: 16, color: meta.color),
              const SizedBox(width: 8),
              Text(
                meta.label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: meta.color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'DESCRIBE IT',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Be specific — this helps your landlord respond faster',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400),
        ),
        const SizedBox(height: 24),

        // Title field
        Text(
          'ISSUE TITLE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _titleController,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. AC making loud buzzing sound',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.slate500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Description field
        Text(
          'DETAILS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _descController,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'When did it start? How severe is it? Any safety concerns?',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.slate500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Urgency selector
        Text(
          'PRIORITY LEVEL',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: TicketUrgency.values.reversed.map((u) {
            final isSelected = _selectedUrgency == u;
            final color = urgencyColor(u);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedUrgency = u),
                child: Container(
                  margin: EdgeInsets.only(right: u != TicketUrgency.low ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        urgencyLabel(u),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: isSelected ? color : AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        urgencySla(u),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isSelected ? color.withValues(alpha: 0.7) : AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Photo upload area
        Text(
          'EVIDENCE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.slate500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Photos help landlords assess the issue faster',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate500),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _mockPhotoCount++),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: _mockPhotoCount == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.blue500.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, size: 22, color: AppColors.blue400),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TAP TO ADD PHOTOS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ...List.generate(_mockPhotoCount.clamp(0, 3), (i) {
                          return Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.slate800,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Icon(LucideIcons.image, size: 24, color: AppColors.slate500),
                          );
                        }),
                        if (_mockPhotoCount < 5)
                          GestureDetector(
                            onTap: () => setState(() => _mockPhotoCount++),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: const Icon(LucideIcons.plus, size: 20, color: AppColors.slate500),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 32),

        // Submit button
        GestureDetector(
          onTap: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please add a title for your issue', style: GoogleFonts.inter()),
                  backgroundColor: AppColors.red500,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }
            setState(() => _step = 2);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.indigo500, AppColors.indigo500.withValues(alpha: 0.85)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.indigo500.withValues(alpha: 0.3), blurRadius: 20),
              ],
            ),
            child: Text(
              'SUBMIT TICKET',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
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

  // ─────────────────────────────────
  // STEP 3: SUCCESS
  // ─────────────────────────────────
  Widget _buildSuccessStep() {
    final now = DateTime.now();
    final ticketId = 'K-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(now.millisecond % 100).toString().padLeft(3, '0')}';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.15), blurRadius: 30),
                ],
              ),
              child: const Icon(Icons.check, size: 40, color: AppColors.emerald400),
            ),
            const SizedBox(height: 24),

            Text(
              'TICKET FILED',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Ticket ID
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                ticketId,
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo500,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: 280,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400, height: 1.6),
                  children: [
                    const TextSpan(text: 'Your landlord has been notified. Expected response within '),
                    TextSpan(
                      text: urgencySla(_selectedUrgency),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: urgencyColor(_selectedUrgency)),
                    ),
                    const TextSpan(text: '. Rex will auto-escalate if no response is received.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Info cards
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
                  _buildInfoRow(LucideIcons.clock, 'Auto-reminders', 'Every 24 hours'),
                  const SizedBox(height: 12),
                  _buildInfoRow(LucideIcons.shield, 'Auto-escalation', 'If SLA missed'),
                  const SizedBox(height: 12),
                  _buildInfoRow(LucideIcons.fileText, 'Timeline preserved', 'Legal evidence'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            GestureDetector(
              onTap: () => context.pop(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  'VIEW ALL TICKETS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
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

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.slate500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate400)),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.indigo500),
        ),
      ],
    );
  }
}
