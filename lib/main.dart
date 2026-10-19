import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/ads_manager.dart';
import 'services/analytics_service.dart';
import 'services/analytics_toast.dart';
import 'services/audio_manager.dart';
import 'theme/app_theme.dart';
import 'views/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set portrait orientation & immersive sticky mode in parallel
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    ),
  ]);

  // Run app immediately so the native launcher splash screen dismisses instantly
  runApp(const WordTilesApp());

  // Initialize Firebase, Analytics, and Crashlytics asynchronously in background
  unawaited(AnalyticsService.initialize());
}

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class WordTilesApp extends StatefulWidget {
  const WordTilesApp({super.key});

  @override
  State<WordTilesApp> createState() => _WordTilesAppState();
}

class _WordTilesAppState extends State<WordTilesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      AudioManager.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      AudioManager.resumeBgm();
      AdsManager.handleAppResume();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: AnalyticsToast.navigatorKey,
          title: 'Wordnect: Connect Words',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          navigatorObservers: [routeObserver],
          home: const LoadingScreen(),
        );
      },
    );
  }
}


