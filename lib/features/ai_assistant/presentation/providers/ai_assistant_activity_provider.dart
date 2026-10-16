import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AiAssistantActivity {
  const AiAssistantActivity({this.hasUnreadMessage = false, this.revision = 0});

  final bool hasUnreadMessage;
  final int revision;

  AiAssistantActivity copyWith({bool? hasUnreadMessage, int? revision}) {
    return AiAssistantActivity(
      hasUnreadMessage: hasUnreadMessage ?? this.hasUnreadMessage,
      revision: revision ?? this.revision,
    );
  }
}

class AiAssistantActivityNotifier extends StateNotifier<AiAssistantActivity> {
  AiAssistantActivityNotifier() : super(const AiAssistantActivity());

  void markNewMessage() {
    state = AiAssistantActivity(
      hasUnreadMessage: true,
      revision: state.revision + 1,
    );
  }

  void markRead() {
    if (!state.hasUnreadMessage) return;
    state = state.copyWith(hasUnreadMessage: false);
  }
}

final aiAssistantActivityProvider =
    StateNotifierProvider<AiAssistantActivityNotifier, AiAssistantActivity>(
      (ref) => AiAssistantActivityNotifier(),
    );
