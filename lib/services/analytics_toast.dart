import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_typography.dart';
import 'game_storage.dart';
import 'remote_config_service.dart';

/// Represents a single Analytics test toast event payload.
class AnalyticsToastItem {
  final String title;
  final String? details;
  final int count;
  final Color accentColor;
  final String icon;

  const AnalyticsToastItem({
    required this.title,
    this.details,
    required this.count,
    required this.accentColor,
    required this.icon,
  });
}

/// Global Toast overlay service that renders real-time HUD notifications
/// whenever Analytics events are dispatched to Firebase during Cheat / Test mode.
class AnalyticsToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _entry;
  static Timer? _dismissTimer;
  static int _counter = 0;
  static final ValueNotifier<AnalyticsToastItem?> activeToastNotifier =
      ValueNotifier<AnalyticsToastItem?>(null);

  /// Double Guard verification: Only active when Cheat Mode AND Firebase Test switch are ON.
  static bool get isEnabled =>
      RemoteConfigService.cheatEnabled && GameStorage.isFirebaseAnalyticsTestEnabled();

  /// Logs an event to the HUD Toast.
  static void showEvent(String name, [Map<String, Object>? parameters]) {
    if (!isEnabled) {
      dismiss();
      return;
    }

    _counter++;
    String? details;
    if (parameters != null && parameters.isNotEmpty) {
      final entries = parameters.entries.take(4).map((e) => '${e.key}: ${e.value}').join(', ');
      details = parameters.length > 4 ? '$entries...' : entries;
    }

    _present(AnalyticsToastItem(
      title: name,
      details: details,
      count: _counter,
      accentColor: const Color(0xFF38BDF8), // Cyan
      icon: '🔥',
    ));
  }

  /// Logs User Properties to the HUD Toast.
  static void showUserProperties(Map<String, Object?> properties) {
    if (!isEnabled) {
      dismiss();
      return;
    }

    _counter++;
    final entries = properties.entries.take(3).map((e) => '${e.key}: ${e.value}').join(', ');
    final details = properties.length > 3 ? '$entries...' : entries;

    _present(AnalyticsToastItem(
      title: 'user_properties',
      details: details.isNotEmpty ? details : null,
      count: _counter,
      accentColor: const Color(0xFFA78BFA), // Violet
      icon: '👤',
    ));
  }

  /// Logs an error to the HUD Toast.
  static void showError(String name, String error) {
    if (!isEnabled) {
      dismiss();
      return;
    }

    _counter++;
    _present(AnalyticsToastItem(
      title: 'ERROR: $name',
      details: error,
      count: _counter,
      accentColor: const Color(0xFFEF4444), // Red
      icon: '⚠️',
    ));
  }

  /// Presents the toast payload via the global OverlayEntry.
  static void _present(AnalyticsToastItem item) {
    activeToastNotifier.value = item;

    // Reset auto-dismiss timer
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 2500), () {
      dismiss();
    });

    // Ensure overlay entry is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay == null) return;

      if (_entry == null) {
        _entry = OverlayEntry(
          builder: (context) => const _AnalyticsToastOverlayWidget(),
        );
        overlay.insert(_entry!);
      } else {
        _entry?.markNeedsBuild();
      }
    });
  }

  /// Dismisses and cleans up the active HUD toast.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    activeToastNotifier.value = null;
    if (_entry != null) {
      _entry?.remove();
      _entry = null;
    }
  }

  /// Resets the sequential counter.
  static void resetCounter() {
    _counter = 0;
  }
}

/// The overlay widget rendering the active toast at the top of the viewport.
class _AnalyticsToastOverlayWidget extends StatelessWidget {
  const _AnalyticsToastOverlayWidget();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8.h,
      left: 16.w,
      right: 16.w,
      child: ValueListenableBuilder<AnalyticsToastItem?>(
        valueListenable: AnalyticsToast.activeToastNotifier,
        builder: (context, item, _) {
          if (item == null) return const SizedBox.shrink();

          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: AnalyticsToast.dismiss,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xF20F172A), // 95% dark slate glass
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: item.accentColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: Icon, Title, and Sequence Badge
                    Row(
                      children: [
                        Text(
                          item.icon,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            '[Firebase] ${item.title}',
                            style: AppTypography.font(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              color: item.accentColor,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: Colors.white24, width: 1.0),
                          ),
                          child: Text(
                            '#${item.count}',
                            style: AppTypography.font(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Details row: Parameters / values
                    if (item.details != null && item.details!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        item.details!,
                        style: AppTypography.font(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFCBD5E1),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
