import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../theme/app_motion.dart';
import 'rad_ai_bird.dart';

/// Centered RAD AI Assistant bird for the bottom navigation bar.
///
/// Uses the owner-approved front-facing red bird asset with subtle idle float,
/// spring tap response, and restrained active illumination. Respects
/// reduced-motion system preferences.
class RadAiBirdNavIcon extends StatefulWidget {
  const RadAiBirdNavIcon({
    super.key,
    required this.selected,
    required this.label,
    required this.moreLabel,
    required this.onTap,
    required this.onLongPress,
    this.size = 111,
  });

  final bool selected;
  final String label;
  final String moreLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double size;

  @override
  State<RadAiBirdNavIcon> createState() => _RadAiBirdNavIconState();
}

class _RadAiBirdNavIconState extends State<RadAiBirdNavIcon>
    with TickerProviderStateMixin {
  bool _showFocus = false;

  late final AnimationController _floatController;
  late final AnimationController _tapController;
  late final Animation<double> _float;
  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _float = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.88,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.06,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_tapController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFloat();
  }

  @override
  void didUpdateWidget(covariant RadAiBirdNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _syncFloat();
    }
  }

  void _handleTap() {
    if (!AppMotion.reduceMotion(context)) {
      _tapController.forward(from: 0);
    }
    widget.onTap();
  }

  void _syncFloat() {
    if (!mounted) return;
    if (AppMotion.reduceMotion(context)) {
      _floatController.stop();
      _tapController.stop();
      _floatController.value = 0.5;
      _tapController.value = 0;
      return;
    }
    if (!_floatController.isAnimating) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    final selected = widget.selected;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      label: widget.label,
      button: true,
      selected: selected,
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.moreLabel): widget.onLongPress,
      },
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _OpenMoreIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleTap();
              return null;
            },
          ),
          _OpenMoreIntent: CallbackAction<_OpenMoreIntent>(
            onInvoke: (_) {
              widget.onLongPress();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _handleTap,
          onLongPress: widget.onLongPress,
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: 30,
                  child: AnimatedOpacity(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    opacity: selected ? 0.6 : 0.25,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(
                              alpha: dark ? 0.28 : 0.16,
                            ),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 26,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _floatController,
                      _tapController,
                    ]),
                    builder: (context, child) {
                      final dy = reduce ? 0.0 : _float.value;
                      final scale = reduce ? 1.0 : _tapScale.value;
                      return Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(
                          key: const ValueKey('rad-ai-bird-nav-scale'),
                          scale: scale,
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox.square(
                      dimension: 60,
                      child: ExcludeSemantics(
                        child: RadAiBird(
                          state: selected
                              ? RadAiBirdState.responding
                              : RadAiBirdState.idle,
                          semanticLabel: widget.label,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: SizedBox(
                    height: 18,
                    child: Center(
                      child: ExcludeSemantics(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? (dark
                                      ? const Color(0xFFFF7685)
                                      : AppColors.primaryRed)
                                : (dark
                                      ? const Color(0xFFCED3DC)
                                      : const Color(0xFF596575)),
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showFocus)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryRed,
                            width: 2,
                          ),
                        ),
                      ),
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

class _OpenMoreIntent extends Intent {
  const _OpenMoreIntent();
}
