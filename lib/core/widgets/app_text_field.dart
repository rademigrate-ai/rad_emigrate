import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.minLines,
    this.maxLines = 1,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
    this.textDirection,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? minLines;
  final int maxLines;
  final bool enabled;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextDirection? textDirection;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode();
  }

  void _attachFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focused = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _attachFocusNode();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.duration(context, AppMotion.fast);
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.curve(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.11),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        enabled: widget.enabled,
        onFieldSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        textDirection: widget.textDirection,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : null,
          suffixIcon: widget.suffixIcon,
        ),
      ),
    );
  }
}
