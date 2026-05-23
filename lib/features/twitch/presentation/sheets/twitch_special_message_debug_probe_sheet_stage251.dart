import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showTwitchSpecialMessageDebugProbeSheetStage251({
  required BuildContext context,
  required Future<Map<String, dynamic>> Function() onRunProbe,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF18181B),
    barrierColor: Colors.black.withOpacity(0.62),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TwitchSpecialMessageDebugProbeSheetStage251(
      onRunProbe: onRunProbe,
    ),
  );
}

class _TwitchSpecialMessageDebugProbeSheetStage251 extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onRunProbe;

  const _TwitchSpecialMessageDebugProbeSheetStage251({
    required this.onRunProbe,
  });

  @override
  State<_TwitchSpecialMessageDebugProbeSheetStage251> createState() =>
      _TwitchSpecialMessageDebugProbeSheetStage251State();
}

class _TwitchSpecialMessageDebugProbeSheetStage251State
    extends State<_TwitchSpecialMessageDebugProbeSheetStage251> {
  bool _running = false;
  String? _jsonText;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
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
                      color: const Color(0xFF9146FF).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF9146FF).withOpacity(0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: Color(0xFFBF94FF),
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
                            color: Colors.white.withOpacity(0.58),
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
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
                    onPressed: _jsonText == null ? null : _copyJson,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_errorText != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.22)),
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
                    color: Colors.black.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '按 Run Probe 後會顯示 JSON。\n目前 hash 尚未補齊時，operations 會顯示 configured=false，snapshot.issues 會列出原因。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.54),
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
