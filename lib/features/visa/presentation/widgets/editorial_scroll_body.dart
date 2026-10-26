import 'package:flutter/material.dart';

/// Lazy long-form layout with measured anchor seeking. It never approximates
/// the final displayed destination: completion requires the real target key.
class EditorialBodyController {
  Future<void> Function(int)? _seek;
  Future<void> seekTo(int index) async {
    await _seek?.call(index);
  }
}

class EditorialScrollBody extends StatefulWidget {
  const EditorialScrollBody({
    super.key,
    required this.children,
    this.targetIndex,
    this.bodyController,
  });
  final List<Widget> children;
  final int? targetIndex;
  final EditorialBodyController? bodyController;
  @override
  State<EditorialScrollBody> createState() => _State();
}

class _State extends State<EditorialScrollBody> {
  final controller = ScrollController();
  final keys = <int, GlobalKey>{};
  @override
  void initState() {
    super.initState();
    widget.bodyController?._seek = seek;
    WidgetsBinding.instance.addPostFrameCallback((_) => seek());
  }

  @override
  void didUpdateWidget(covariant EditorialScrollBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bodyController != widget.bodyController) {
      oldWidget.bodyController?._seek = null;
      widget.bodyController?._seek = seek;
    }
    if (oldWidget.targetIndex != widget.targetIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => seek());
    }
  }

  Future<void> seek([int? requested]) async {
    final target = requested ?? widget.targetIndex;
    if (target == null || target < 0 || target >= widget.children.length) {
      return;
    }
    double low = 0;
    double? upper;
    for (
      var attempt = 0;
      attempt < 24 && mounted && controller.hasClients;
      attempt++
    ) {
      final targetContext = keys[target]?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(targetContext, alignment: 0.08);
        return;
      }
      final attached =
          keys.entries
              .where(
                (e) =>
                    e.value.currentContext?.findRenderObject()?.attached ??
                    false,
              )
              .map((e) => e.key)
              .toList()
            ..sort();
      final offset = controller.offset;
      if (attached.isNotEmpty) {
        if (target > attached.last) {
          low = offset;
          if (upper != null && upper <= low) upper = null;
        }
        if (target < attached.first) upper = offset;
      }
      final max = controller.position.maxScrollExtent;
      final next = upper == null
          ? (attempt == 0
                ? max * target / widget.children.length
                : (low + max) / 2)
          : (low + upper) / 2;
      controller.jumpTo(next.clamp(0, max));
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void dispose() {
    widget.bodyController?._seek = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    padding: const EdgeInsets.all(24),
    itemCount: widget.children.length,
    itemBuilder: (_, i) => KeyedSubtree(
      key: keys.putIfAbsent(i, () => GlobalKey()),
      child: widget.children[i],
    ),
  );
}
