import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/avatar_widget.dart';
import '../../../domain/entities/bills/breakdown_item.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/router/app_router.dart';
import 'dart:math';

class BranchingTree extends StatefulWidget {
    final String entityId;
    final String entityName;
    final String? entityEmoji;
    final int? entityColor;
    final List<BreakdownItem> items;
    final double totalAmount;
    final String direction; // 'IN', 'OUT', or 'GROUP'
    final bool isGroup;
    final AppUser? currentUser;
    final AppUser? entityUser;

    const BranchingTree({
      super.key,
      required this.entityId,
      required this.entityName,
      this.entityEmoji,
      this.entityColor,
      required this.items,
      required this.totalAmount,
      required this.direction,
      this.isGroup = false,
      this.currentUser,
      this.entityUser,
    });

    @override
    State<BranchingTree> createState() => _BranchingTreeState();
  }

class _BranchingTreeState extends State<BranchingTree>
      with TickerProviderStateMixin {
    late AnimationController _trunkController;
    late AnimationController _branchesController;
    late AnimationController _itemsController;
    late AnimationController _particleController;

    late Animation<double> _trunkAnimation;
    late List<Animation<double>> _branchAnimations;
    late List<Animation<double>> _itemAnimations;

    bool _showSimplified = false;
    final List<Particle> _particles = [];

    @override
    void initState() {
      super.initState();
      print('DEBUG: BranchingTree - isGroup: ${widget.isGroup}, entityUser: ${widget.entityUser?.name}, currentUser: ${widget.currentUser?.name}');
      _initializeAnimations();
      _startAnimationSequence();

      // Update particles continuously
      _particleController.addListener(() {
        final dt = 0.016; // Approx 60fps
        for (final particle in _particles) {
          particle.update(dt);
        }
      });
    }


    void _initializeAnimations() {
      // Trunk grows from top to center
      _trunkController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _trunkAnimation = CurvedAnimation(
        parent: _trunkController,
        curve: Curves.easeOut,
      );

      // Branches grow horizontally from trunk
      _branchesController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );

      // Create staggered animations for each branch
      _branchAnimations = List.generate(
        widget.items.length,
        (index) => CurvedAnimation(
          parent: _branchesController,
          curve: Interval(
            index / widget.items.length,
            1.0,
            curve: Curves.easeOut,
          ),
        ),
      );

      // Items fade in after branches
      _itemsController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );

      _itemAnimations = List.generate(
        widget.items.length,
        (index) => CurvedAnimation(
          parent: _itemsController,
          curve: Interval(
            index / widget.items.length,
            1.0,
            curve: Curves.easeOut,
          ),
        ),
      );

      _particleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400), // Match total animation time
      );

      // Generate particles
      _generateParticles();
    }

    void _generateParticles() {
      final random = Random();
      _particles.clear();

      // Create 50 particles that will flow along branches
      for (int i = 0; i < 50; i++) {
        _particles.add(Particle(
          progress: random.nextDouble(),
          speed: 0.3 + random.nextDouble() * 0.7,
          size: 1.5 + random.nextDouble() * 2.5,
          opacity: 0.3 + random.nextDouble() * 0.7,
          branchIndex: random.nextInt(widget.items.length.clamp(1, 10)),
        ));
      }
    }

    Future<void> _startAnimationSequence() async {
      // Start particles immediately with trunk animation
      _particleController.forward();

      await _trunkController.forward();
      await _branchesController.forward();
      await _itemsController.forward();
    }



    @override
    void dispose() {
      _trunkController.dispose();
      _branchesController.dispose();
      _itemsController.dispose();
      _particleController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          // Toggle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showSimplified = !_showSimplified),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.slate800.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showSimplified ? LucideIcons.gitBranch : LucideIcons.minus,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showSimplified ? 'Show Tree' : 'Simplify',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showSimplified
                ? _buildSimplifiedView()
                : _buildTreeView(),
          ),
        ],
      );
    }

    Widget _buildSimplifiedView() {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: GlassCard(
          borderRadius: BorderRadius.circular( 20),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Entity avatar/icon
              if (widget.isGroup)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Color(widget.entityColor ?? 0xFF06B6D4),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.entityEmoji ?? '👥',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                )
              else
                AvatarWidget.fromUser(
                  user: widget.entityUser!,
                  size: 50,
                ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.items.length} bill${widget.items.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Net amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.direction == 'OUT' ? 'You Owe' : 'Owes You',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${widget.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: widget.direction == 'OUT'
                          ? Colors.redAccent
                          : Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildTreeView() {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _trunkController,
            _branchesController,
            _itemsController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _TreePainter(
                trunkProgress: _trunkAnimation.value,
                branchProgresses: _branchAnimations.map((a) => a.value).toList(),
                itemCount: widget.items.length,
                direction: widget.direction,
                particles: _particles,
                particleAnimation: _particleController.value,
                items: widget.items, // needed for status-based coloring
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Center node (entity)
                    _buildCenterNode(),

                    const SizedBox(height: 40),

                    // Bill items
                    ...widget.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isLeft = index % 2 == 0;

                      return Opacity(
                        opacity: _itemAnimations[index].value,
                        child: Transform.translate(
                          offset: Offset(
                            isLeft ? -20 * (1 - _itemAnimations[index].value) : 20 * (1 - _itemAnimations[index].value),
                            0,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 84),
                            child: Row(
                              children: [
                                if (isLeft) ...[
                                  Expanded(child: _buildBillCard(item)),
                                  const SizedBox(width: 60),
                                  const Expanded(child: SizedBox()),
                                ] else ...[
                                  const Expanded(child: SizedBox()),
                                  const SizedBox(width: 60),
                                  Expanded(child: _buildBillCard(item)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Add bottom padding for safe area
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    Widget _buildCenterNode() {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.direction == 'GROUP'
                ? const Color(0xFF3B82F6) // Blue for group view
                : (widget.direction == 'OUT' ? Colors.redAccent : Colors.green),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.direction == 'GROUP'
                  ? const Color(0xFF3B82F6)
                  : (widget.direction == 'OUT' ? Colors.redAccent : Colors.green))
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: widget.isGroup
            ? Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Color(widget.entityColor ?? 0xFF06B6D4),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.entityEmoji ?? '👥',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              )
            : widget.entityUser != null
                  ? AvatarWidget.fromUser(
                      user: widget.entityUser!,
                      size: 70,
                    )
                  : widget.currentUser != null
                      ? AvatarWidget.fromUser(
                          user: widget.currentUser!,
                          size: 70,
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
      );
    }

    Widget _buildBillCard(BreakdownItem item) {
      return GestureDetector(
        onTap: () {
          // Navigate to bill details/summary page
          context.push(AppRoutes.billSummary, extra: item.bill.id);
        },
        child: GlassCard(
          borderRadius: BorderRadius.circular( 16),
          padding: const EdgeInsets.all(12),
          opacity: 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.bill.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.bill.location,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Status badge (matching dashboard style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.isPending
                      ? AppColors.orange.withValues(alpha: 0.2)
                      : AppColors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular( 6),
                ),
                child: Text(
                  item.isPending ? 'Pending' : 'Settled',
                  style: TextStyle(
                    color: item.isPending ? AppColors.orange : AppColors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Amount
              Text(
                'RM ${item.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

/// Custom painter for drawing the tree structure with particles
  class _TreePainter extends CustomPainter {
    final double trunkProgress;
    final List<double> branchProgresses;
    final int itemCount;
    final String direction;
    final List<Particle> particles;
    final double particleAnimation;
    final List<BreakdownItem> items;

    _TreePainter({
      required this.trunkProgress,
      required this.branchProgresses,
      required this.itemCount,
      required this.direction,
      required this.particles,
      required this.particleAnimation,
      required this.items,
    });

   @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final trunkEndY = 22.0;

    // Trunk color: Blue for group view, red/green for user owe
  final Color trunkColor = direction == 'GROUP'
      ? const Color(0xFF3B82F6) // Blue-500
      : (direction == 'OUT' ? Colors.redAccent : Colors.green);

    // Avatar position calculations (used throughout)
    final avatarCenterY = trunkEndY + 40;
    final avatarSize = 70.0;
    final avatarBorderWidth = 3.0;
    final avatarPadding = 4.0;
    final avatarRadius = (avatarSize / 2) + avatarBorderWidth + avatarPadding;
    final avatarBottomY = avatarCenterY + avatarRadius;


       // Paint setup
  final paint = Paint()
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square  // Changed from round to ensure connection
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

      // === MAIN TRUNK (Animated vertical line from avatar bottom) ===
  final trunkPath = Path();

  // Calculate total trunk height based on number of items
  final firstBranchY = avatarBottomY + 60; // Gap between avatar and first branch
  final totalTrunkHeight = itemCount > 0 ? (itemCount - 1) * 100 : 0;
  final finalTrunkY = firstBranchY + totalTrunkHeight;

  // Draw animated trunk from avatar bottom downward
  if (trunkProgress > 0 && itemCount > 0) {
    // Start at avatar edge minus small overlap for seamless connection
    final trunkStartY = avatarBottomY - 3; // 3px overlap with border
    trunkPath.moveTo(centerX, trunkStartY);

    // Trunk grows downward with animation
    final currentTrunkY = trunkStartY + ((finalTrunkY - trunkStartY) * trunkProgress);
    trunkPath.lineTo(centerX, currentTrunkY);
  }

  // Draw trunk with glow effect (only once)
  if (trunkProgress > 0) {
    canvas.drawPath(
      trunkPath,
      Paint()
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = trunkColor.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    paint.color = trunkColor.withValues(alpha: 0.9);
    canvas.drawPath(trunkPath, paint);
  }

 // === BRANCHES ===
  double currentY = avatarBottomY + 60; // Start from first branch position

      for (int i = 0; i < itemCount; i++) {
    final branchProgress = branchProgresses[i];

    if (branchProgress < 0.01) {
      currentY += 100;
      continue;
    }

    final isLeft = i % 2 == 0;
    final branchLength = (size.width / 2 - 80) * branchProgress;

    // Simple branch color rule:
    // - Blue for group view
    // - Red for "You Owe"
    // - Green for "Owed To You"
    final Color branchColor = direction == 'GROUP'
        ? const Color(0xFF3B82F6) // Blue-500
        : (direction == 'OUT' ? Colors.redAccent : Colors.green);

    // Glow effect
    canvas.drawLine(
      Offset(centerX, currentY),
      Offset(
        isLeft ? centerX - branchLength : centerX + branchLength,
        currentY,
      ),
      Paint()
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = branchColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Main branch line
    canvas.drawLine(
      Offset(centerX, currentY),
      Offset(
        isLeft ? centerX - branchLength : centerX + branchLength,
        currentY,
      ),
      Paint()
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = branchColor.withValues(alpha: 0.9),
    );

    currentY += 100;
  }

       // === PARTICLES (Only during animation) ===
  // Show particles only while animations are running
  final isAnimating = trunkProgress < 1.0 ||
                      branchProgresses.any((p) => p < 1.0);
  if (isAnimating) {
    _drawParticles(canvas, size, trunkColor, centerX, avatarBottomY);
  }
    }

    void _drawParticles(Canvas canvas, Size size, Color color, double centerX, double avatarBottomY) {
    for (final particle in particles) {
      if (particle.branchIndex >= itemCount) continue;

      final branchProgress = branchProgresses[particle.branchIndex];
      if (branchProgress < 0.3) continue; // Only show particles on visible branches

      final isLeft = particle.branchIndex % 2 == 0;
      final branchY = avatarBottomY + 60 + (particle.branchIndex * 100);
        final branchLength = (size.width / 2 - 80) * branchProgress;

        // Calculate particle position along branch
        final particleX = centerX + (isLeft ? -1 : 1) * (branchLength * particle.progress);
        final particleY = branchY;

        // Draw particle with glow
        final particlePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: particle.opacity * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 2);

        canvas.drawCircle(
          Offset(particleX, particleY),
          particle.size * 2,
          particlePaint,
        );

        canvas.drawCircle(
          Offset(particleX, particleY),
          particle.size,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: particle.opacity),
        );
      }
    }

    @override
    bool shouldRepaint(covariant _TreePainter oldDelegate) {
      return trunkProgress != oldDelegate.trunkProgress ||
          branchProgresses != oldDelegate.branchProgresses ||
          particleAnimation != oldDelegate.particleAnimation;
    }
  }

  class Particle {
    double progress;  // 0.0 to 1.0 along the branch
    final double speed;
    final double size;
    final double opacity;
    final int branchIndex;

    Particle({
      required this.progress,
      required this.speed,
      required this.size,
      required this.opacity,
      required this.branchIndex,
    });

    void update(double dt) {
      progress += speed * dt;
      if (progress > 1.0) progress = 0.0;  // Loop back
    }
  }
