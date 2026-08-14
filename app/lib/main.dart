import 'dart:async';

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
      locale: localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
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
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map), label: l10n.navMap),
          NavigationDestination(icon: const Icon(Icons.warning), label: l10n.navMyRisk),
          NavigationDestination(icon: const Icon(Icons.report), label: l10n.navReport),
          NavigationDestination(icon: const Icon(Icons.settings), label: l10n.navSettings),
        ],
      ),
    );
  }
}
