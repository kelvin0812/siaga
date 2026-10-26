import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siaga_app/core/theme.dart';

/// WCAG contrast ratio between two colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  group('text on the dark surfaces is readable outdoors', () {
    const backgrounds = {'top': AppColors.bgTop, 'bottom': AppColors.bgBottom, 'card': AppColors.surface, 'raised card': AppColors.surfaceRaised};

    test('secondary text clears AAA (7:1), muted text clears AA (4.5:1), on every surface', () {
      for (final e in backgrounds.entries) {
        expect(_contrast(AppColors.textSecondary, e.value), greaterThanOrEqualTo(7), reason: 'secondary on ${e.key}');
        expect(_contrast(AppColors.textMuted, e.value), greaterThanOrEqualTo(4.5), reason: 'muted on ${e.key}');
        expect(_contrast(AppColors.textPrimary, e.value), greaterThanOrEqualTo(12), reason: 'primary on ${e.key}');
      }
    });

    test('and the hierarchy is kept: primary is brighter than secondary, which is brighter than muted', () {
      final onCard = AppColors.surface;
      expect(_contrast(AppColors.textPrimary, onCard), greaterThan(_contrast(AppColors.textSecondary, onCard)));
      expect(_contrast(AppColors.textSecondary, onCard), greaterThan(_contrast(AppColors.textMuted, onCard)));
    });
  });
}
