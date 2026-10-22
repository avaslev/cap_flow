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

  /// Показывает тост. Если задан [countdown] — в тосте появляется маленький
  /// круглый счётчик с обратным отсчётом до конца окна (в секундах), и тост
  /// исчезает вместе с ним. [bottomOffset] поднимает тост выше (например,
  /// над открытой нижней шторкой).
  static void show(
    BuildContext context,
    String message, {
    bool error = false,
    Duration? countdown,
    double bottomOffset = 0,
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
        countdown: countdown,
        bottomOffset: bottomOffset,
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    final Duration life = countdown != null
        ? countdown + const Duration(milliseconds: 300)
        : const Duration(milliseconds: 2500);
    _timer = Timer(life, dismiss);
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
  final Duration? countdown;
  final double bottomOffset;
  final VoidCallback onDismiss;

  const _ToastView({
    required this.message,
    required this.error,
    required this.version,
    required this.onDismiss,
    this.countdown,
    this.bottomOffset = 0,
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

  Timer? _tick;
  late int _remaining = widget.countdown?.inSeconds ?? 0;

  @override
  void initState() {
    super.initState();
    if (_remaining > 0) {
      _tick = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) {
          timer.cancel();
          widget.onDismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mq = MediaQuery.of(context);
    // Плавающая пилюля над нижним меню (NavigationBar ~80).
    return Positioned(
      bottom: mq.padding.bottom + 84 + widget.bottomOffset,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Flexible(
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
                          if (_remaining > 0) ...<Widget>[
                            const SizedBox(width: 10),
                            _CountdownBadge(
                              remaining: _remaining,
                              total: widget.countdown?.inSeconds ?? _remaining,
                              error: widget.error,
                            ),
                          ],
                        ],
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

/// Маленький круглый счётчик обратного отсчёта (кольцо + секунды).
class _CountdownBadge extends StatelessWidget {
  final int remaining;
  final int total;
  final bool error;

  const _CountdownBadge({
    required this.remaining,
    required this.total,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color accent = error
        ? colorScheme.onErrorContainer
        : colorScheme.onInverseSurface;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: total <= 0 ? 0 : remaining / total,
            strokeWidth: 2.5,
            backgroundColor: accent.withValues(alpha: 0.25),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          Text(
            '$remaining',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

