import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../models/chat/twitch_whisper_emote_catalog.dart';

/// Maps keyboard character movement between raw emote codes and image slots.
/// Pointer selection and platform copy remain in Flutter's selection system.
class TwitchWhisperSelection extends StatefulWidget {
  final List<TwitchWhisperTextPart> parts;
  final InlineSpan span;
  const TwitchWhisperSelection({
    super.key,
    required this.parts,
    required this.span,
  });

  @override
  State<TwitchWhisperSelection> createState() => _WhisperSelectionState();
}

class _WhisperSelectionState extends State<TwitchWhisperSelection> {
  final _paragraphKey = GlobalKey();
  late final _WhisperSelectionDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _delegate = _WhisperSelectionDelegate(widget.parts, _paragraphKey);
  }

  @override
  void didUpdateWidget(TwitchWhisperSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _delegate.updateParts(widget.parts);
  }

  @override
  Widget build(BuildContext context) => SelectionContainer(
    delegate: _delegate,
    child: Text.rich(widget.span, key: _paragraphKey),
  );

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }
}

class _WhisperSelectionDelegate extends StaticSelectionContainerDelegate {
  List<TwitchWhisperTextPart> parts;
  final GlobalKey paragraphKey;
  String raw;
  _WhisperSelectionDelegate(this.parts, this.paragraphKey)
    : raw = parts.map((part) => part.text).join();

  @override
  int get contentLength => raw.length;

  void updateParts(List<TwitchWhisperTextPart> next) {
    var changed = parts.length != next.length;
    for (var index = 0; !changed && index < parts.length; index++) {
      changed =
          parts[index].text != next[index].text ||
          parts[index].emote?.id != next[index].emote?.id;
    }
    if (changed) dispatchSelectionEvent(const ClearSelectionEvent());
    parts = next;
    raw = next.map((part) => part.text).join();
  }

  RenderParagraph? _paragraph() {
    RenderParagraph? result;
    void visit(RenderObject object) {
      if (result != null) return;
      if (object is RenderParagraph) {
        result = object;
      } else {
        object.visitChildren(visit);
      }
    }

    final object = paragraphKey.currentContext?.findRenderObject();
    if (object != null) visit(object);
    return result;
  }

  int _step(int offset, bool forward) {
    var start = 0;
    for (final part in parts) {
      final end = start + part.text.length;
      if (part.emote != null &&
          (forward
              ? offset >= start && offset < end
              : offset > start && offset <= end)) {
        return forward ? end : start;
      }
      start = end;
    }
    final boundary = CharacterBoundary(raw);
    return forward
        ? boundary.getTrailingTextBoundaryAt(offset) ?? raw.length
        : boundary.getLeadingTextBoundaryAt(offset - 1) ?? 0;
  }

  int _visualOffset(int offset) {
    var original = 0;
    var visual = 0;
    for (final part in parts) {
      final end = original + part.text.length;
      if (offset <= end) {
        return visual +
            (part.emote == null
                ? offset - original
                : offset == original
                ? 0
                : 1);
      }
      original = end;
      visual += part.emote == null ? part.text.length : 1;
    }
    return visual;
  }

  Offset? _tokenEdge(int target, RenderParagraph paragraph) {
    var original = 0;
    var visual = 0;
    for (final part in parts) {
      final end = original + part.text.length;
      if (part.emote != null && (target == original || target == end)) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: visual, extentOffset: visual + 1),
        );
        if (boxes.isNotEmpty) {
          final box = boxes.first;
          final left =
              (target == original) == (box.direction == TextDirection.ltr);
          return Offset(
            left
                ? box.left + (target == original ? -.01 : .01)
                : box.right + (target == original ? .01 : -.01),
            (box.top + box.bottom) / 2,
          );
        }
      }
      original = end;
      visual += part.emote == null ? part.text.length : 1;
    }
    return null;
  }

  @override
  SelectionResult handleGranularlyExtendSelection(
    GranularlyExtendSelectionEvent event,
  ) {
    final range = getSelection();
    final paragraph = _paragraph();
    if (event.granularity != TextGranularity.character ||
        range == null ||
        paragraph == null) {
      return super.handleGranularlyExtendSelection(event);
    }
    final current = event.isEnd ? range.endOffset : range.startOffset;
    final target = _step(current.clamp(0, raw.length), event.forward);
    if (target == current) {
      return event.forward ? SelectionResult.next : SelectionResult.previous;
    }
    final visual = _visualOffset(target);
    final position = TextPosition(offset: visual);
    final caret = paragraph.getOffsetForCaret(position, Rect.zero);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: visual > 0 ? visual - 1 : 0,
        extentOffset: visual > 0 ? visual : 1,
      ),
    );
    final height = boxes.isEmpty ? 14.0 : boxes.first.bottom - boxes.first.top;
    final global = paragraph.localToGlobal(
      _tokenEdge(target, paragraph) ?? caret + Offset(0, height / 2),
    );
    return super.handleSelectionEdgeUpdate(
      event.isEnd
          ? SelectionEdgeUpdateEvent.forEnd(globalPosition: global)
          : SelectionEdgeUpdateEvent.forStart(globalPosition: global),
    );
  }
}
