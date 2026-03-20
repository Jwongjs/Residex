import 'dart:math' as math;
import 'package:flutter/material.dart';

  /// Represents a single particle with position, velocity, and visual properties
  class Particle {
    Offset position;
    Offset velocity;
    double size;
    Color color;
    double life; // 0.0 to 1.0
    double opacity;
    bool isActive;

    Particle({
      this.position = Offset.zero,
      this.velocity = Offset.zero,
      this.size = 2.0,
      this.color = Colors.white,
      this.life = 1.0,
      this.opacity = 1.0,
      this.isActive = false,
    });

    /// Reset particle to inactive state
    void reset() {
      position = Offset.zero;
      velocity = Offset.zero;
      size = 2.0;
      color = Colors.white;
      life = 1.0;
      opacity = 1.0;
      isActive = false;
    }

    /// Update particle physics
    void update(double deltaTime) {
      if (!isActive) return;

      // Update position based on velocity
      position = position + (velocity * deltaTime);

      // Decay life and opacity
      life -= deltaTime * 0.5; // Particles last ~2 seconds
      opacity = life.clamp(0.0, 1.0);

      // Deactivate when life expires
      if (life <= 0) {
        isActive = false;
      }
    }
  }

  /// Memory-efficient particle pool with object reuse
  class ParticlePool {
    static final Map<String, ParticlePool> _pools = {};
    final List<Particle> _particles = [];
    final int _maxParticles;
    final math.Random _random = math.Random();

    ParticlePool._(this._maxParticles) {
      // Pre-allocate particles
      for (int i = 0; i < _maxParticles; i++) {
        _particles.add(Particle());
      }
    }

    /// Get or create a named particle pool
    static ParticlePool get(String name, {int maxParticles = 50}) {
      return _pools.putIfAbsent(
        name,
        () => ParticlePool._(maxParticles),
      );
    }

    /// Acquire a particle from the pool
    Particle? acquire({
      required Offset position,
      required Offset velocity,
      required Color color,
      double size = 3.0,
    }) {
      // Find first inactive particle
      for (final particle in _particles) {
        if (!particle.isActive) {
          particle.position = position;
          particle.velocity = velocity;
          particle.color = color;
          particle.size = size;
          particle.life = 1.0;
          particle.opacity = 1.0;
          particle.isActive = true;
          return particle;
        }
      }

      // Pool exhausted
      return null;
    }

    /// Spawn multiple particles in a burst
    void spawnBurst({
      required Offset center,
      required Color color,
      int count = 10,
      double speed = 100.0,
      double sizeMin = 2.0,
      double sizeMax = 4.0,
    }) {
      for (int i = 0; i < count; i++) {
        final angle = _random.nextDouble() * math.pi * 2;
        final velocity = Offset(
          math.cos(angle) * speed,
          math.sin(angle) * speed,
        );
        final size = sizeMin + _random.nextDouble() * (sizeMax - sizeMin);

        acquire(
          position: center,
          velocity: velocity,
          color: color,
          size: size,
        );
      }
    }

    /// Update all active particles
    void updateAll(double deltaTime) {
      for (final particle in _particles) {
        if (particle.isActive) {
          particle.update(deltaTime);
        }
      }
    }

    /// Get list of currently active particles
    List<Particle> get activeParticles {
      return _particles.where((p) => p.isActive).toList();
    }

    /// Get count of active particles
    int get activeCount {
      return _particles.where((p) => p.isActive).length;
    }

    /// Release a specific particle back to the pool
    void release(Particle particle) {
      particle.reset();
    }

    /// Release all particles
    void releaseAll() {
      for (final particle in _particles) {
        particle.reset();
      }
    }

    /// Clear all named pools (call when all badges are disposed)
    static void clearAll() {
      for (final pool in _pools.values) {
        pool.releaseAll();
      }
      _pools.clear();
    }

    /// Get stats for debugging
    String get stats {
      return 'Active: $activeCount / $_maxParticles';
    }
  }

  /// Custom painter for rendering particles efficiently
  class ParticlePainter extends CustomPainter {
    final List<Particle> particles;
    final Paint _paint = Paint()..style = PaintingStyle.fill;

    ParticlePainter({required this.particles});

    @override
    void paint(Canvas canvas, Size size) {
      for (final particle in particles) {
        if (!particle.isActive) continue;

        _paint.color = particle.color.withValues(alpha:particle.opacity);
        canvas.drawCircle(
          particle.position,
          particle.size,
          _paint,
        );

        // Optional: Add glow effect for larger particles
        if (particle.size > 3.0) {
          _paint.color = particle.color.withValues(alpha:particle.opacity * 0.3);
          canvas.drawCircle(
            particle.position,
            particle.size * 1.5,
            _paint,
          );
        }
      }
    }

    @override 
    bool shouldRepaint(ParticlePainter oldDelegate) {
      // Always repaint when particles are active
      return particles.any((p) => p.isActive);
    }
  }