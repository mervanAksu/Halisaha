import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_tokens.dart';

/// Five-slot bottom navigation: Favorilerim, Maçlarım, [raised round centre = Keşfet],
/// Destek, Profilim. Indices: 0 favorites, 1 matches, 2 home, 3 support, 4 profile.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 64;
  static const double _lift = 20;
  static const double _circle = 60;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tokens = context.tokens;
    return SizedBox(
      height: _barHeight + _lift + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.card,
                border: Border(top: BorderSide(color: tokens.border)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.favorite_border,
                      activeIcon: Icons.favorite,
                      label: S.navFavorites,
                      selected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.event_note_outlined,
                      activeIcon: Icons.event_note,
                      label: S.navMatches,
                      selected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            S.navDiscover,
                            style: _labelStyle(context, currentIndex == 2),
                          ),
                        ),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.support_agent_outlined,
                      activeIcon: Icons.support_agent,
                      label: S.navSupport,
                      selected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: S.navProfile,
                      selected: currentIndex == 4,
                      onTap: () => onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                button: true,
                selected: currentIndex == 2,
                label: S.navDiscover,
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: _circle,
                    height: _circle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.primary,
                      border: Border.all(color: tokens.accent, width: 4),
                      boxShadow: [BoxShadow(color: tokens.shadow, blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Icon(Icons.sports_soccer, color: tokens.onPrimary, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _labelStyle(BuildContext context, bool selected) {
  final tokens = context.tokens;
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: selected ? tokens.brand : tokens.textSecondary,
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? context.tokens.brand : context.tokens.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _labelStyle(context, selected)),
          ],
        ),
      ),
    );
  }
}
