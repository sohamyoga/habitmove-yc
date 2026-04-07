import 'package:flutter/material.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';

// ─── Offline Banner ───────────────────────────────────────────────────────────
// Drop this anywhere in a screen's Column to show a dismissible connectivity banner.

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineCacheService.instance.onlineNotifier,
      builder: (_, online, __) {
        if (online) return const SizedBox.shrink();
        return _Banner();
      },
    );
  }
}

class _Banner extends StatefulWidget {
  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this)..forward();
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _slide,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warm600,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You\'re offline — showing cached content',
              style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'DMSans'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('CACHED',
                style: TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w700, fontFamily: 'DMSans')),
          ),
        ],
      ),
    ),
  );
}

// ─── Connectivity indicator dot (for use in AppBar actions) ───────────────────

class ConnectivityDot extends StatelessWidget {
  const ConnectivityDot({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: OfflineCacheService.instance.onlineNotifier,
    builder: (_, online, __) => Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Tooltip(
        message: online ? 'Online' : 'Offline',
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? AppColors.success : AppColors.warm500,
          ),
        ),
      ),
    ),
  );
}
