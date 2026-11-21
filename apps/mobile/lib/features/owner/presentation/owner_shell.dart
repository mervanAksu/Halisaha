import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import 'owner_bookings_screen.dart';
import 'owner_hours_screen.dart';
import 'owner_pitches_screen.dart';
import 'owner_today_screen.dart';

/// Shell of the in-app owner panel (route `/owner`): Bugün, Rezervasyonlar, Sahalarım, Saatler.
/// Always light, whatever the system theme says (docs/DESIGN.md "İşletmeci modu"): owners use it
/// in daylight.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;
  late final ThemeData _theme = AppTheme.light();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            OwnerTodayScreen(),
            OwnerBookingsScreen(),
            OwnerPitchesScreen(),
            OwnerHoursScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_view_day_outlined),
              selectedIcon: Icon(Icons.calendar_view_day),
              label: S.today,
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: S.ownerTabBookings,
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined),
              selectedIcon: Icon(Icons.sports_soccer),
              label: S.ownerTabPitches,
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: S.ownerTabHours,
            ),
          ],
        ),
      ),
    );
  }
}
