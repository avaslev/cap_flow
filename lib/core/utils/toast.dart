import 'dart:async';

import 'package:flutter/material.dart';

/// Лёгкий топ-тост вместо снекбара: плашка сверху под статус-баром,
/// не перехватывает касания (IgnorePointer) и не перекрывает нижнее меню.
/// Одновременно виден один тост — новый заменяет предыдущий.
class Toast {
  Toast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final ValueNotifier<int> _version = ValueNotifier<int>(0);

  static void show(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    _version.value++;

    final int version = _version.value;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => _ToastView(
        message: message,
        error: error,
        version: version,
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(milliseconds: 2500), dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final bool error;
  final int version;
  final VoidCallback onDismiss;

  const _ToastView({
    required this.message,
    required this.error,
    required this.version,
    required this.onDismiss,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mq = MediaQuery.of(context);
    // Плавающая пилюля над нижним меню (NavigationBar ~80).
    return Positioned(
      bottom: mq.padding.bottom + 84,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.6),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: widget.error
                      ? colorScheme.errorContainer
                      : colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.error
                            ? colorScheme.onErrorContainer
                            : colorScheme.onInverseSurface,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
