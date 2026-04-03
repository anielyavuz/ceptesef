import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Üstten kayan in-app bildirim banner'ı
/// Overlay kullanır — tüm ekranların üstünde gösterilir
class InAppNotificationBanner {
  InAppNotificationBanner._();

  static OverlayEntry? _currentEntry;
  static Timer? _autoHideTimer;

  /// Banner'ı göster
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Mevcut banner varsa kaldır
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => _BannerWidget(
        title: title,
        body: body,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
        duration: duration,
      ),
    );

    overlay.insert(_currentEntry!);

    _autoHideTimer = Timer(duration + const Duration(milliseconds: 500), () {
      dismiss();
    });
  }

  /// Banner'ı kaldır
  static void dismiss() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const _BannerWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    // Otomatik gizleme
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              _controller.reverse().then((_) => widget.onDismiss());
            }
          },
          child: Container(
            margin: EdgeInsets.only(
              top: topPadding + 8,
              left: 16,
              right: 16,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.charcoal.withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
