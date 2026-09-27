import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/app_state.dart';
import 'core/fcm_service.dart';
import 'core/h3_service.dart';
import 'core/locale_provider.dart';
import 'core/location_service.dart';
import 'core/offline_cache.dart';
import 'core/theme.dart';
import 'demo/demo_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/evacuate_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_screen.dart';
import 'screens/risk_screen.dart';
import 'screens/settings_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No Firebase project is configured yet (no google-services.json /
  // GoogleService-Info.plist) — degrade to no-push rather than crash on
  // startup, same resilience philosophy as the backend's NullFCMClient
  // (Section 2: must degrade visibly, not crash, when something is
  // unplugged).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp failed, continuing without push: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient();
  final h3Service = H3Service();
  final fcmService = FcmService();
  await fcmService.init();

  final locationService = LocationService(
    h3Service: h3Service,
    fcmService: fcmService,
    prefs: prefs,
    apiClient: apiClient,
  );

  final appState = AppState(
    api: apiClient,
    cache: OfflineCache(prefs),
    locationService: locationService,
  );
  final demoController = DemoController(appState: appState);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => LocaleProvider(prefs)),
        Provider.value(value: demoController),
        Provider.value(value: fcmService),
      ],
      child: SiagaApp(fcmService: fcmService),
    ),
  );
}

class SiagaApp extends StatefulWidget {
  final FcmService fcmService;
  const SiagaApp({super.key, required this.fcmService});

  @override
  State<SiagaApp> createState() => _SiagaAppState();
}

class _SiagaAppState extends State<SiagaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
    widget.fcmService.onForegroundAlert.listen(_handleAlert);
    widget.fcmService.onNotificationOpened.listen(_handleAlert);
  }

  Future<void> _startup() async {
    final appState = context.read<AppState>();
    // Independent concerns, run concurrently: location permission gates
    // the cell-subscription/EVACUATE-routing feature only. If a user
    // denies location (or the permission prompt just never resolves —
    // e.g. no one present to click it), the live map and node list must
    // still load. These were previously sequential awaits, which meant
    // a stuck location prompt silently blocked all data on the map/risk
    // screens too.
    unawaited(appState.locationService.requestPermissionAndStart());
    await appState.refresh();
  }

  void _handleAlert(AlertMessage alert) {
    if (alert.state != 'EVACUATE') return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EvacuateScreen(
          messageEn: alert.messageEn,
          messageMs: alert.messageMs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeOverride = context.watch<LocaleProvider>().overrideLocale;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SIAGA',
      debugShowCheckedModeBanner: false,
      locale: localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: SiagaTheme.dark(),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  static const _screens = [MapScreen(), RiskScreen(), ReportScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const _Brand()),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: l10n.navMap),
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield),
            label: l10n.navMyRisk,
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: const Icon(Icons.campaign),
            label: l10n.navReport,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}

/// Header brand mark — a glowing shield glyph plus the wordmark, replacing
/// the plain AppBar title. Small, but it's the one element visible on
/// every screen, so it's where "this is a tech product, not a government
/// PDF portal" gets established first.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF6D5DF6)]),
            boxShadow: appGlow(AppColors.accent, alpha: 0.45, blur: 16),
          ),
          child: const Icon(Icons.shield_moon_outlined, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Text(
          'SIAGA',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: 0.5, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// A rounded, floating frosted-glass dock rather than a bar flush with the
/// screen edge — heavier blur than the standard GlassCard (this sits over
/// whatever's scrolling behind it, so it needs to stay legible against
/// anything from map tiles to hazard-red banners) plus a glowing dot that
/// slides beneath the active tab.
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segment = constraints.maxWidth / destinations.length;
                  // Positioned/AnimatedPositioned must be a DIRECT child of
                  // Stack — nesting it one level down through this same
                  // LayoutBuilder (needed to read the bar's own width) is
                  // an easy trap that throws "Incorrect use of
                  // ParentDataWidget" on every frame and, worse, breaks hit
                  // testing for every sibling in the Stack, silently
                  // eating every tap on the nav bar.
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: segment * selectedIndex + segment / 2 - 12,
                        bottom: 9,
                        child: Container(
                          width: 24,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: appGlow(AppColors.accent, alpha: 0.7, blur: 10),
                          ),
                        ),
                      ),
                      NavigationBarTheme(
                        data: Theme.of(context).navigationBarTheme.copyWith(
                              height: 68,
                              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                            ),
                        child: NavigationBar(
                          backgroundColor: Colors.transparent,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: onDestinationSelected,
                          destinations: destinations,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
