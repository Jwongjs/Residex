import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

enum _FairFixStep { camera, analyzing, result }

class FairFixAuditorScreen extends StatefulWidget {
  const FairFixAuditorScreen({super.key});

  @override
  State<FairFixAuditorScreen> createState() => _FairFixAuditorScreenState();
}

class _FairFixAuditorScreenState extends State<FairFixAuditorScreen>
    with SingleTickerProviderStateMixin {
  _FairFixStep _step = _FairFixStep.camera;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _onCapture() {
    setState(() => _step = _FairFixStep.analyzing);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _step = _FairFixStep.result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
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
                    AppColors.cyan500.withValues(alpha: 0.15),
                    AppColors.deepSpace,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (_step != _FairFixStep.camera) _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          Text(
            'FAIRFIX AUDITOR',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _FairFixStep.camera:
        return _buildCameraView();
      case _FairFixStep.analyzing:
        return _buildAnalyzingView();
      case _FairFixStep.result:
        return _buildResultView();
    }
  }

  // ─────────────────────────────────
  // CAMERA VIEW
  // ─────────────────────────────────
  Widget _buildCameraView() {
    return Stack(
      children: [
        // Simulated camera background
        Container(color: const Color(0xFF0A0E1A)),

        // HUD overlay
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner brackets
                ..._buildCornerBrackets(),
                // Crosshair
                Center(
                  child: Icon(Icons.add, size: 32, color: AppColors.cyan500.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 16, left: 24, right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.red500.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.red500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.red500, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.red500)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Centered guidance text
        Positioned(
          left: 24, right: 24,
          top: MediaQuery.of(context).size.height * 0.35,
          child: Column(
            children: [
              Icon(Icons.document_scanner, size: 48, color: AppColors.cyan500.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'POINT AT DAMAGE',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.cyan400),
              ),
              const SizedBox(height: 4),
              Text(
                'Align the area within the frame',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),

        // Bottom capture button
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _onCapture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cyan500, width: 4),
                  boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)],
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.cyan500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 24.0;
    const color = AppColors.cyan500;
    return [
      Positioned(top: 0, left: 0, child: _corner(color, size, true, true)),
      Positioned(top: 0, right: 0, child: _corner(color, size, true, false)),
      Positioned(bottom: 0, left: 0, child: _corner(color, size, false, true)),
      Positioned(bottom: 0, right: 0, child: _corner(color, size, false, false)),
    ];
  }

  Widget _corner(Color color, double size, bool top, bool left) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CornerPainter(color, top, left)),
    );
  }

  // ─────────────────────────────────
  // ANALYZING VIEW
  // ─────────────────────────────────
  Widget _buildAnalyzingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scan frame
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                  ),
                ),
                // Grid overlay
                ...List.generate(3, (i) => Positioned(
                  left: 0, right: 0,
                  top: (i + 1) * 50.0,
                  child: Divider(color: AppColors.cyan500.withValues(alpha: 0.1), height: 0),
                )),
                ...List.generate(3, (i) => Positioned(
                  top: 0, bottom: 0,
                  left: (i + 1) * 50.0,
                  child: VerticalDivider(color: AppColors.cyan500.withValues(alpha: 0.1), width: 0),
                )),
                // Scan line
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return Positioned(
                      left: 0, right: 0,
                      top: _scanController.value * 200,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.cyan500.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.5), blurRadius: 10)],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'ANALYZING GEOMETRY',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calculating Material Costs...',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.slate800,
                valueColor: const AlwaysStoppedAnimation(AppColors.cyan500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────
  // RESULT VIEW
  // ─────────────────────────────────
  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Hero estimate card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.cyan500.withValues(alpha: 0.1),
                AppColors.blue600.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('RM ', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.cyan400)),
                    Text('450 - 600', style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'FAIRFIX VERIFIED',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.emerald400),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statChip('Confidence', '98%', AppColors.cyan400),
                    const SizedBox(width: 24),
                    _statChip('Savings', '~RM 250', AppColors.emerald400),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Damage Assessment
          _buildSection(
            title: 'DAMAGE ASSESSMENT',
            icon: Icons.warning_amber,
            iconColor: AppColors.cyan400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Issue Type', 'Water Intrusion / Wall Crack'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Severity: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate400)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.rose500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('HIGH', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.rose500)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.blue500.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.blue400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recommend immediate waterproofing. Market rate is RM 800+ for this type of repair.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.blue400, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Price Citations
          _buildSection(
            title: 'PRICE CITATIONS',
            icon: Icons.link,
            iconColor: AppColors.blue400,
            child: Column(
              children: [
                _citationRow('Kaodim.com', 'RM 400 - 550'),
                _citationRow('Recommend.my', 'RM 480 - 620'),
                _citationRow('Ace Hardware', 'RM 200 (DIY Materials)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _step = _FairFixStep.camera),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh, size: 16, color: AppColors.slate400),
                        const SizedBox(width: 8),
                        Text('RETAKE', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.slate400)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.cyan500, AppColors.blue600]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.2), blurRadius: 12)],
                  ),
                  child: Text('GET QUOTES', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.slate500)),
      ],
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Color iconColor, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
              ]),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate400)),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
      ],
    );
  }

  Widget _citationRow(String source, String price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.language, size: 16, color: AppColors.slate500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(price, style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, size: 14, color: AppColors.slate500),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;
  _CornerPainter(this.color, this.top, this.left);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
