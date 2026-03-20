import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../../../../core/theme/app_theme.dart';

/// Maintenance AI Screen - Predictive maintenance and issue tracking
class MaintenanceAIScreen extends ConsumerStatefulWidget {
  const MaintenanceAIScreen({super.key});

  @override
  ConsumerState<MaintenanceAIScreen> createState() => _MaintenanceAIScreenState();
}

class _MaintenanceAIScreenState extends ConsumerState<MaintenanceAIScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedTab = 0;

  final List<Map<String, dynamic>> _predictions = [
    {
      'title': 'HVAC System - Probable Failure',
      'property': 'Sunset Apartments #204',
      'severity': 'high',
      'probability': 87,
      'daysUntil': 14,
      'reason': 'Unusual noise patterns detected, temperature inconsistencies',
      'recommendation': 'Schedule inspection within 7 days to prevent system failure',
      'icon': Icons.ac_unit,
    },
    {
      'title': 'Water Heater Maintenance Due',
      'property': 'Downtown Loft #5B',
      'severity': 'medium',
      'probability': 72,
      'daysUntil': 30,
      'reason': 'Unit is 8 years old, approaching typical replacement cycle',
      'recommendation': 'Perform preventive maintenance check',
      'icon': Icons.water_drop,
    },
    {
      'title': 'Roof Leak Risk',
      'property': 'Riverside House',
      'severity': 'medium',
      'probability': 65,
      'daysUntil': 45,
      'reason': 'Recent heavy rainfall, age of roof materials',
      'recommendation': 'Inspect roof drainage and shingles',
      'icon': Icons.roofing,
    },
    {
      'title': 'Plumbing Pressure Drop',
      'property': 'Metro Plaza #12',
      'severity': 'low',
      'probability': 45,
      'daysUntil': 60,
      'reason': 'Minor pressure fluctuations detected over past month',
      'recommendation': 'Schedule routine plumbing inspection',
      'icon': Icons.plumbing,
    },
  ];

  final List<Map<String, dynamic>> _activeIssues = [
    {
      'title': 'Broken Window - Unit 301',
      'property': 'Sunset Apartments',
      'status': 'In Progress',
      'priority': 'High',
      'reported': '2 days ago',
      'assignedTo': 'ABC Glass Services',
    },
    {
      'title': 'Leaking Faucet',
      'property': 'Downtown Loft #5B',
      'status': 'Pending',
      'priority': 'Low',
      'reported': '5 days ago',
      'assignedTo': 'Not assigned',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.warning.withOpacity(0.3), AppColors.primaryBlue.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.engineering, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Maintenance AI', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHealthScore(),
          _buildTabBar(),
          Expanded(
            child: _selectedTab == 0 ? _buildPredictionsTab() : _buildActiveIssuesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScore() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryCyan.withOpacity(0.1),
            AppColors.primaryBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Animated Health Score Circle
          SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _HealthScorePainter(
                    score: 82,
                    pulseAnimation: _pulseController.value,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '82',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(color: AppColors.slate400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Health',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '4 predictions • 2 active issues',
                  style: TextStyle(color: AppColors.slate400, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildHealthBadge('AI Monitoring', AppColors.primaryCyan),
                    const SizedBox(width: 8),
                    _buildHealthBadge('Good', AppColors.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab('Predictions', 0, Icons.auto_graph),
          ),
          Expanded(
            child: _buildTab('Active Issues', 1, Icons.build),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppColors.primaryCyan.withOpacity(0.3), AppColors.primaryBlue.withOpacity(0.3)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryCyan : AppColors.slate400, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.slate400,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return _buildPredictionCard(prediction);
      },
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    Color severityColor;
    switch (prediction['severity']) {
      case 'high':
        severityColor = AppColors.error;
        break;
      case 'medium':
        severityColor = AppColors.warning;
        break;
      default:
        severityColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(prediction['icon'], color: severityColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction['title'],
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction['property'],
                      style: TextStyle(color: AppColors.slate400, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProbabilityBar(prediction['probability'], severityColor),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip('${prediction['probability']}% probability', severityColor),
              const SizedBox(width: 8),
              _buildInfoChip('${prediction['daysUntil']} days', AppColors.primaryCyan),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Reason: ${prediction['reason']}',
            style: TextStyle(color: AppColors.slate300, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primaryCyan, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prediction['recommendation'],
                    style: TextStyle(color: AppColors.primaryCyan, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maintenance ticket created!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: severityColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Schedule Maintenance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar(int probability, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Failure Probability', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
            Text('$probability%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: probability / 100,
            backgroundColor: AppColors.slate700,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildActiveIssuesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activeIssues.length,
      itemBuilder: (context, index) {
        final issue = _activeIssues[index];
        return _buildIssueCard(issue);
      },
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    Color priorityColor;
    switch (issue['priority']) {
      case 'High':
        priorityColor = AppColors.error;
        break;
      case 'Medium':
        priorityColor = AppColors.warning;
        break;
      default:
        priorityColor = AppColors.success;
    }

    Color statusColor;
    switch (issue['status']) {
      case 'In Progress':
        statusColor = AppColors.warning;
        break;
      case 'Completed':
        statusColor = AppColors.success;
        break;
      default:
        statusColor = AppColors.slate400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue['title'],
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: priorityColor),
                ),
                child: Text(
                  issue['priority'],
                  style: TextStyle(color: priorityColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue['property'],
            style: TextStyle(color: AppColors.slate400, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.slate400, size: 16),
              const SizedBox(width: 6),
              Text(
                'Reported ${issue['reported']}',
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.slate400, size: 16),
              const SizedBox(width: 6),
              Text(
                issue['assignedTo'],
                style: TextStyle(color: AppColors.slate300, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  issue['status'],
                  style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthScorePainter extends CustomPainter {
  final int score;
  final double pulseAnimation;

  _HealthScorePainter({required this.score, required this.pulseAnimation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = AppColors.slate700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius - 4, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.primaryCyan, AppColors.primaryBlue],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Pulse effect
    final pulsePaint = Paint()
      ..color = AppColors.primaryCyan.withOpacity(0.3 * (1 - pulseAnimation))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius + (10 * pulseAnimation), pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _HealthScorePainter oldDelegate) {
    return oldDelegate.pulseAnimation != pulseAnimation;
  }
}
