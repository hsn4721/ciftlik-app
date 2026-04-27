import 'package:flutter/material.dart';

enum ModulePattern { milk, herd, health, finance, feed, calf, staff, equipment, subsidies }

// İçerik alanı arka planı — AppBar ve BottomNav arasındaki boşluğa yerleşir
class ModuleBackground extends StatelessWidget {
  final ModulePattern pattern;
  const ModuleBackground({super.key, required this.pattern});

  @override
  Widget build(BuildContext context) {
    final color = _colors[pattern]!;
    final bgColor = _bgColors[pattern]!;
    final icon = _icons[pattern]!;

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
        children: [
          // Hafif temalı gradient zemin
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgColor, const Color(0xFFF5F5F5)],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // Büyük filigran ikon — sağ üst
          Positioned(
            right: -30,
            top: 20,
            child: Icon(icon, size: 230, color: color.withValues(alpha: 0.055)),
          ),
          // İkinci küçük ikon — sol alt
          Positioned(
            left: -25,
            bottom: 80,
            child: Icon(icon, size: 140, color: color.withValues(alpha: 0.035)),
          ),
        ],
        ),
      ),
    );
  }
}

const Map<ModulePattern, Color> _colors = {
  ModulePattern.milk:      Color(0xFF1565C0),
  ModulePattern.herd:      Color(0xFF1B5E20),
  ModulePattern.health:    Color(0xFFC62828),
  ModulePattern.finance:   Color(0xFFE65100),
  ModulePattern.feed:      Color(0xFF33691E),
  ModulePattern.calf:      Color(0xFF4A148C),
  ModulePattern.staff:     Color(0xFF006064),
  ModulePattern.equipment: Color(0xFF37474F),
  ModulePattern.subsidies: Color(0xFFBF360C),
};

const Map<ModulePattern, Color> _bgColors = {
  ModulePattern.milk:      Color(0xFFE3F0FF),
  ModulePattern.herd:      Color(0xFFE8F5E9),
  ModulePattern.health:    Color(0xFFFCE8E6),
  ModulePattern.finance:   Color(0xFFFFF3E0),
  ModulePattern.feed:      Color(0xFFF1F8E9),
  ModulePattern.calf:      Color(0xFFF3E5F5),
  ModulePattern.staff:     Color(0xFFE0F7FA),
  ModulePattern.equipment: Color(0xFFECEFF1),
  ModulePattern.subsidies: Color(0xFFFBE9E7),
};

const Map<ModulePattern, IconData> _icons = {
  ModulePattern.milk:      Icons.water_drop,
  ModulePattern.herd:      Icons.pets,
  ModulePattern.health:    Icons.favorite,
  ModulePattern.finance:   Icons.bar_chart,
  ModulePattern.feed:      Icons.grass,
  ModulePattern.calf:      Icons.child_friendly,
  ModulePattern.staff:     Icons.people,
  ModulePattern.equipment: Icons.build,
  ModulePattern.subsidies: Icons.account_balance,
};
