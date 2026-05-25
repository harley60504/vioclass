import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/twitch_ui_tokens.dart';

Future<void> showTwitchSpecialMessageDebugProbeSheetStage251({
  required BuildContext context,
  required Future<Map<String, dynamic>> Function() onRunProbe,
  Future<Map<String, dynamic>> Function({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
    bool useAndroidClient,
  })?
  onRunCustomPersistedOperation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TwitchUiColors.sheet.background,
    barrierColor: TwitchUiColors.sheet.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TwitchSpecialMessageDebugProbeSheetStage251(
      onRunProbe: onRunProbe,
      onRunCustomPersistedOperation: onRunCustomPersistedOperation,
    ),
  );
}

class _TwitchSpecialMessageDebugProbeSheetStage251 extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onRunProbe;
  final Future<Map<String, dynamic>> Function({
    required String operationName,
    required String sha256Hash,
    required Map<String, dynamic> variables,
    bool useAndroidClient,
  })?
  onRunCustomPersistedOperation;

  const _TwitchSpecialMessageDebugProbeSheetStage251({
    required this.onRunProbe,
    this.onRunCustomPersistedOperation,
  });

  @override
  State<_TwitchSpecialMessageDebugProbeSheetStage251> createState() =>
      _TwitchSpecialMessageDebugProbeSheetStage251State();
}

class _TwitchSpecialMessageDebugProbeSheetStage251State
    extends State<_TwitchSpecialMessageDebugProbeSheetStage251> {
  final TextEditingController _operationController = TextEditingController();
  final TextEditingController _hashController = TextEditingController();
  final TextEditingController _variablesController = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(<String, dynamic>{}),
  );

  bool _running = false;
  bool _useAndroidClient = false;
  String? _jsonText;
  String? _errorText;

  @override
  void dispose() {
    _operationController.dispose();
    _hashController.dispose();
    _variablesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TwitchUiColors.sheet.handle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TwitchUiColors.sheet.backplate.fillActive,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: TwitchUiColors.sheet.backplate.border,
                      ),
                    ),
                    child: Icon(
                      Icons.science_rounded,
                      color: TwitchUiColors.sheet.backplate.foreground,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Special Messages Probe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '測 Watch Streak / Resub / Chat Identity 後端狀態',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _running ? null : _runProbe,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_running ? 'Running...' : 'Run Probe'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _running || widget.onRunCustomPersistedOperation == null
                        ? null
                        : _runCustomPersistedOperation,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Run Custom'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: TwitchUiColors.sheet.cardBorder),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _jsonText == null ? null : _copyJson,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: TwitchUiColors.sheet.cardBorder),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCustomOperationInputs(),
              const SizedBox(height: 10),
              if (_errorText != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFFFB4AB),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: TwitchUiColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TwitchUiColors.sheet.cardBorder),
                  ),
                  child: _jsonText == null
                      ? _buildEmptyState()
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _jsonText!,
                              style: const TextStyle(
                                color: Color(0xFFE6E1E5),
                                fontSize: 11.5,
                                height: 1.35,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomOperationInputs() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TwitchUiColors.sheet.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TwitchUiColors.sheet.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.tune_rounded,
                color: TwitchUiColors.primarySoft,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Custom Persisted Query',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            value: _useAndroidClient,
            onChanged: (value) {
              setState(() => _useAndroidClient = value ?? false);
            },
            title: Text(
              'Use Android/Drops client',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: TwitchUiColors.primary,
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildTextField(
                  controller: _operationController,
                  label: 'operationName',
                  hint: '例如 GetViewerSpecialMessage',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  controller: _hashController,
                  label: 'sha256Hash',
                  hint: '貼 persisted query hash',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _variablesController,
            label: 'variables JSON',
            hint: '{"channelLogin":"..."}',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontSize: 11,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.28),
          fontSize: 11,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: TwitchUiColors.sheet.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: TwitchUiColors.sheet.cardBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: TwitchUiColors.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '按 Run Probe 後會顯示 JSON。\n也可以貼 operationName / sha256Hash / variables 後按 Run Custom 直接測 persisted query。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _runProbe() async {
    setState(() {
      _running = true;
      _errorText = null;
    });

    try {
      final result = await widget.onRunProbe();
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _jsonText = encoder.convert(result);
      });
    } catch (error) {
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _runCustomPersistedOperation() async {
    final run = widget.onRunCustomPersistedOperation;
    if (run == null) return;

    final operationName = _operationController.text.trim();
    final hash = _hashController.text.trim();
    final variablesText = _variablesController.text.trim();
    if (operationName.isEmpty || hash.isEmpty) {
      setState(() => _errorText = 'operationName 和 sha256Hash 都要填。');
      return;
    }

    Map<String, dynamic> variables;
    try {
      final decoded = variablesText.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(variablesText);
      if (decoded is! Map) {
        setState(() => _errorText = 'variables JSON 必須是 object。');
        return;
      }
      variables = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (error) {
      setState(() => _errorText = 'variables JSON 解析失敗：$error');
      return;
    }

    setState(() {
      _running = true;
      _errorText = null;
    });

    try {
      final result = await run(
        operationName: operationName,
        sha256Hash: hash,
        variables: variables,
        useAndroidClient: _useAndroidClient,
      );
      const encoder = JsonEncoder.withIndent('  ');
      setState(() {
        _jsonText = encoder.convert(result);
      });
    } catch (error) {
      setState(() {
        _errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _copyJson() async {
    final text = _jsonText;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製 Special Messages Probe JSON')),
    );
  }
}
