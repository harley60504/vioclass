import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../settings/twitch_chat_keyboard_controller.dart';
import '../../../../models/chat/twitch_chat_moderation_shortcut.dart';

/// Local message focus only: never a global handler or a moderation write.
class TwitchChatMessageKeyboardAccess extends StatefulWidget {
  final Widget child;
  final VoidCallback onOpenContext;
  final VoidCallback? onOpenUser;
  final FocusNode? focusNode;
  final VoidCallback? onOlder;
  final VoidCallback? onNewer;
  final VoidCallback? onClearFocus;
  final ValueChanged<TwitchChatModerationShortcut>? onModerationShortcut;
  final Map<TwitchChatKeyboardCommand, String?> bindings;
  const TwitchChatMessageKeyboardAccess({
    super.key,
    required this.child,
    required this.onOpenContext,
    this.onOpenUser,
    this.focusNode,
    this.onOlder,
    this.onNewer,
    this.onClearFocus,
    this.onModerationShortcut,
    this.bindings = TwitchChatKeyboardController.defaults,
  });

  @override
  State<TwitchChatMessageKeyboardAccess> createState() =>
      _KeyboardAccessState();
}

class _KeyboardAccessState extends State<TwitchChatMessageKeyboardAccess> {
  final _ownedFocus = FocusNode(debugLabel: 'chat message keyboard access');
  FocusNode get _focus => widget.focusNode ?? _ownedFocus;
  bool _focused = false;

  @override
  void dispose() {
    _ownedFocus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    // Editing/selection descendants keep their native input and shortcuts.
    if (!node.hasPrimaryFocus || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed &&
        widget.onModerationShortcut != null) {
      final key = event.logicalKey;
      final action = key == LogicalKeyboardKey.keyB
          ? (keyboard.isShiftPressed
                ? TwitchChatModerationShortcut.unban
                : TwitchChatModerationShortcut.ban)
          : keyboard.isShiftPressed
          ? null
          : key == LogicalKeyboardKey.keyD
          ? TwitchChatModerationShortcut.delete
          : key == LogicalKeyboardKey.keyT
          ? TwitchChatModerationShortcut.timeout
          : key == LogicalKeyboardKey.keyW
          ? TwitchChatModerationShortcut.warn
          : null;
      if (action != null) {
        widget.onModerationShortcut!(action);
        return KeyEventResult.handled;
      }
    }
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    bool matches(TwitchChatKeyboardCommand command) =>
        event.logicalKey ==
        TwitchChatKeyboardController.keys[widget.bindings[command]];
    if (matches(TwitchChatKeyboardCommand.clear)) {
      node.unfocus();
      widget.onClearFocus?.call();
    } else if (matches(TwitchChatKeyboardCommand.older) &&
        widget.onOlder != null) {
      widget.onOlder!();
    } else if (matches(TwitchChatKeyboardCommand.newer) &&
        widget.onNewer != null) {
      widget.onNewer!();
    } else if (matches(TwitchChatKeyboardCommand.context)) {
      widget.onOpenContext();
    } else if (matches(TwitchChatKeyboardCommand.user) &&
        widget.onOpenUser != null) {
      widget.onOpenUser!();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onKeyEvent: _key,
    onFocusChange: (_) => setState(() => _focused = _focus.hasPrimaryFocus),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: _focused
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      child: widget.child,
    ),
  );
}
