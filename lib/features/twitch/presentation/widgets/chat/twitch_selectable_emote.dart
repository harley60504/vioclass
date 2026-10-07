import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// An inline image is one selectable token, whose clipboard value is its code.
/// The child never registers a second selection when an image falls back to text.
class TwitchSelectableEmote extends SingleChildRenderObjectWidget {
  final String text;

  TwitchSelectableEmote({super.key, required this.text, required Widget child})
    : super(child: SelectionContainer.disabled(child: child));

  @override
  RenderObject createRenderObject(BuildContext context) => _SelectableEmoteBox(
    text,
    DefaultSelectionStyle.of(context).selectionColor ?? const Color(0x665865f2),
  )..selectionRegistrar = SelectionContainer.maybeOf(context);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _SelectableEmoteBox)
      ..text = text
      ..selectionColor =
          DefaultSelectionStyle.of(context).selectionColor ??
          const Color(0x665865f2)
      ..selectionRegistrar = SelectionContainer.maybeOf(context);
  }
}

class _SelectableEmoteBox extends RenderProxyBox
    with Selectable, SelectionRegistrant {
  _SelectableEmoteBox(this._text, this._selectionColor);

  String _text;
  Color _selectionColor;
  set selectionColor(Color color) {
    if (_selectionColor == color) return;
    _selectionColor = color;
    markNeedsPaint();
  }

  int? _start;
  int? _end;
  LayerLink? _startHandle;
  LayerLink? _endHandle;
  SelectionRegistrar? _desiredRegistrar;
  bool _disposed = false;
  set selectionRegistrar(SelectionRegistrar? value) {
    _desiredRegistrar = value;
    registrar = attached ? value : null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    registrar = _desiredRegistrar;
  }

  @override
  void detach() {
    registrar = null;
    super.detach();
  }

  final _geometry = ValueNotifier<SelectionGeometry>(
    const SelectionGeometry(status: SelectionStatus.none, hasContent: true),
  );

  set text(String text) {
    if (_text == text) return;
    _text = text;
    _start = _end = null;
    _updateGeometry();
  }

  bool get _selected => _start != null && _end != null && _start != _end;

  @override
  SelectionGeometry get value => _geometry.value;
  @override
  int get contentLength => _text.length;
  @override
  List<Rect> get boundingBoxes => hasSize ? [Offset.zero & size] : [];
  @override
  void addListener(VoidCallback listener) => _geometry.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _geometry.removeListener(listener);
  @override
  SelectedContent? getSelectedContent() =>
      _selected ? SelectedContent(plainText: _text) : null;
  @override
  SelectedContentRange? getSelection() => _start != null && _end != null
      ? SelectedContentRange(
          startOffset: _start == 0 ? 0 : _text.length,
          endOffset: _end == 0 ? 0 : _text.length,
        )
      : null;

  void _updateGeometry() {
    if (!hasSize) return;
    final start = _start ?? _end;
    final end = _end ?? _start;
    SelectionPoint point(int edge, TextSelectionHandleType handle) =>
        SelectionPoint(
          localPosition: Offset(edge == 0 ? 0 : size.width, size.height),
          lineHeight: size.height,
          handleType: handle,
        );
    _geometry.value = SelectionGeometry(
      hasContent: _text.isNotEmpty,
      status: _selected
          ? SelectionStatus.uncollapsed
          : start != null
          ? SelectionStatus.collapsed
          : SelectionStatus.none,
      startSelectionPoint: start == null
          ? null
          : point(start, TextSelectionHandleType.left),
      endSelectionPoint: end == null
          ? null
          : point(end, TextSelectionHandleType.right),
      selectionRects: _selected ? [Offset.zero & size] : const [],
    );
    markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    _updateGeometry();
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (event is ClearSelectionEvent) {
      _start = _end = null;
    } else if (event is SelectAllSelectionEvent) {
      _start = 0;
      _end = 1;
    } else if (event is SelectWordSelectionEvent) {
      if ((Offset.zero & size).contains(globalToLocal(event.globalPosition))) {
        _start = 0;
        _end = 1;
        _updateGeometry();
        return SelectionResult.end;
      }
    } else if (event is SelectParagraphSelectionEvent) {
      if (event.absorb ||
          (Offset.zero & size).contains(globalToLocal(event.globalPosition))) {
        _start = 0;
        _end = 1;
        _updateGeometry();
        return event.absorb ? SelectionResult.next : SelectionResult.end;
      }
    } else if (event is GranularlyExtendSelectionEvent) {
      final initial = event.forward ? 0 : 1;
      _start ??= initial;
      _end ??= initial;
      final current = event.isEnd ? _end! : _start!;
      final target = event.forward ? 1 : 0;
      if (event.isEnd) {
        _end = target;
      } else {
        _start = target;
      }
      _updateGeometry();
      final crossToken =
          current == target ||
          (event.granularity != TextGranularity.character &&
              event.granularity != TextGranularity.word);
      return crossToken
          ? event.forward
                ? SelectionResult.next
                : SelectionResult.previous
          : SelectionResult.end;
    } else if (event is DirectionallyExtendSelectionEvent) {
      final backward =
          event.direction == SelectionExtendDirection.backward ||
          event.direction == SelectionExtendDirection.previousLine;
      _start ??= backward ? 1 : 0;
      _end ??= backward ? 1 : 0;
      final vertical =
          event.direction == SelectionExtendDirection.previousLine ||
          event.direction == SelectionExtendDirection.nextLine;
      final localX = globalToLocal(
        Offset(event.dx, localToGlobal(Offset.zero).dy),
      ).dx;
      final target = vertical
          ? backward
                ? 0
                : 1
          : localX < size.width / 2
          ? 0
          : 1;
      if (event.isEnd) {
        _end = target;
      } else {
        _start = target;
      }
      _updateGeometry();
      return vertical
          ? backward
                ? SelectionResult.previous
                : SelectionResult.next
          : SelectionResult.end;
    } else if (event is SelectionEdgeUpdateEvent) {
      final local = globalToLocal(event.globalPosition);
      final before = local.dy < 0 || (local.dy <= size.height && local.dx < 0);
      final after = local.dy > size.height || local.dx > size.width;
      final edge = before
          ? 0
          : after
          ? 1
          : event.type == SelectionEventType.startEdgeUpdate
          ? 0
          : 1;
      if (event.type == SelectionEventType.startEdgeUpdate) {
        _start = edge;
      } else {
        _end = edge;
      }
      _updateGeometry();
      return before
          ? SelectionResult.previous
          : after
          ? SelectionResult.next
          : SelectionResult.end;
    }
    _updateGeometry();
    return SelectionResult.none;
  }

  @override
  bool get alwaysNeedsCompositing => _startHandle != null || _endHandle != null;

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (_disposed) return;
    _startHandle = startHandle;
    _endHandle = endHandle;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_selected) {
      context.canvas.drawRect(offset & size, Paint()..color = _selectionColor);
    }
    void handle(LayerLink? link, SelectionPoint? point) {
      if (link != null && point != null) {
        context.pushLayer(
          LeaderLayer(link: link, offset: offset + point.localPosition),
          (_, _) {},
          Offset.zero,
        );
      }
    }

    handle(_startHandle, value.startSelectionPoint);
    handle(_endHandle, value.endSelectionPoint);
  }

  @override
  void dispose() {
    registrar = null;
    _disposed = true;
    _geometry.dispose();
    super.dispose();
  }
}
