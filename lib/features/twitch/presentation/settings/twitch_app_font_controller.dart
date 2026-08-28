import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TwitchAppFontKind { vioClass, system, custom }

class TwitchAppFontChoice {
  final TwitchAppFontKind kind;
  final String label;
  final String? family;

  const TwitchAppFontChoice({
    required this.kind,
    required this.label,
    this.family,
  });

  String get id {
    return switch (kind) {
      TwitchAppFontKind.vioClass => 'vioClass',
      TwitchAppFontKind.system => 'system',
      TwitchAppFontKind.custom => 'custom:$family',
    };
  }
}

class TwitchAppFontController extends ChangeNotifier {
  static const String _selectedFontKey = 'twitch_app_font_selected_v1';
  static const String _customFontFamiliesKey =
      'twitch_app_font_custom_families_v1';
  static const String _customFontLabelsKey = 'twitch_app_font_custom_labels_v1';
  static const String _customFontPathsKey = 'twitch_app_font_custom_paths_v1';
  static const String _builtinFamily = 'VioClassText';

  static const TwitchAppFontChoice vioClass = TwitchAppFontChoice(
    kind: TwitchAppFontKind.vioClass,
    label: 'VioClass 字體',
    family: _builtinFamily,
  );

  static const TwitchAppFontChoice system = TwitchAppFontChoice(
    kind: TwitchAppFontKind.system,
    label: '系統字體',
  );

  static const List<String> fontFallback = <String>[
    'Noto Sans CJK TC',
    'Noto Sans TC',
    'Microsoft JhengHei UI',
    'Microsoft JhengHei',
    'PingFang TC',
    'Heiti TC',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  final Map<String, _CustomFontRecord> _customFonts =
      <String, _CustomFontRecord>{};
  final Set<String> _loadedCustomFonts = <String>{};

  String _selectedId = vioClass.id;
  bool _loaded = false;
  bool _picking = false;

  bool get loaded => _loaded;
  bool get picking => _picking;
  String get selectedId => _selectedId;

  String? get fontFamily {
    final choice = selectedChoice;
    if (choice.kind == TwitchAppFontKind.system) return null;
    return choice.family;
  }

  TwitchAppFontChoice get selectedChoice {
    if (_selectedId == system.id) return system;
    if (_selectedId.startsWith('custom:')) {
      final family = _selectedId.substring('custom:'.length);
      final record = _customFonts[family];
      if (record != null) {
        return TwitchAppFontChoice(
          kind: TwitchAppFontKind.custom,
          label: record.label,
          family: family,
        );
      }
    }
    return vioClass;
  }

  List<TwitchAppFontChoice> get choices {
    return <TwitchAppFontChoice>[
      vioClass,
      system,
      for (final entry in _customFonts.entries)
        TwitchAppFontChoice(
          kind: TwitchAppFontKind.custom,
          label: entry.value.label,
          family: entry.key,
        ),
    ];
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _customFonts
      ..clear()
      ..addAll(_readCustomFonts(prefs));
    _selectedId = prefs.getString(_selectedFontKey) ?? vioClass.id;
    if (!_isKnownId(_selectedId)) {
      _selectedId = vioClass.id;
    }
    await _loadSelectedCustomFont();
    _loaded = true;
    notifyListeners();
  }

  Future<void> select(TwitchAppFontChoice choice) async {
    if (choice.id == _selectedId) return;
    if (choice.kind == TwitchAppFontKind.custom) {
      await _loadCustomFont(choice.family);
    }
    _selectedId = choice.id;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFontKey, _selectedId);
  }

  Future<void> pickAndSelectFont() async {
    if (_picking) return;
    _picking = true;
    notifyListeners();

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['ttf', 'otf'],
      );
      final sourcePath = file?.path;
      if (file == null || sourcePath == null || sourcePath.trim().isEmpty) {
        return;
      }

      final source = File(sourcePath);
      if (!await source.exists()) return;

      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}fonts',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extension = _extension(file.name);
      final stem = _stem(file.name);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final family = 'VioClassCustomFont$stamp';
      final target = File(
        '${dir.path}${Platform.pathSeparator}$family$extension',
      );
      await source.copy(target.path);

      final record = _CustomFontRecord(
        label: stem.isEmpty ? file.name : stem,
        path: target.path,
      );
      _customFonts[family] = record;
      await _loadCustomFont(family);
      _selectedId = 'custom:$family';
      notifyListeners();
      await _save();
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  Future<void> removeCustomFont(String family) async {
    final record = _customFonts.remove(family);
    if (record == null) return;
    if (_selectedId == 'custom:$family') {
      _selectedId = vioClass.id;
    }
    try {
      final file = File(record.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    notifyListeners();
    await _save();
  }

  Map<String, _CustomFontRecord> _readCustomFonts(SharedPreferences prefs) {
    final families = prefs.getStringList(_customFontFamiliesKey) ??
        const <String>[];
    final labels =
        prefs.getStringList(_customFontLabelsKey) ?? const <String>[];
    final paths = prefs.getStringList(_customFontPathsKey) ?? const <String>[];
    final records = <String, _CustomFontRecord>{};
    for (var i = 0; i < families.length; i++) {
      if (i >= labels.length || i >= paths.length) break;
      final family = families[i].trim();
      final path = paths[i].trim();
      if (family.isEmpty || path.isEmpty) continue;
      records[family] = _CustomFontRecord(
        label: labels[i].trim().isEmpty ? family : labels[i].trim(),
        path: path,
      );
    }
    return records;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFontKey, _selectedId);
    await prefs.setStringList(_customFontFamiliesKey, _customFonts.keys.toList());
    await prefs.setStringList(
      _customFontLabelsKey,
      _customFonts.values.map((font) => font.label).toList(growable: false),
    );
    await prefs.setStringList(
      _customFontPathsKey,
      _customFonts.values.map((font) => font.path).toList(growable: false),
    );
  }

  Future<void> _loadSelectedCustomFont() async {
    if (!_selectedId.startsWith('custom:')) return;
    await _loadCustomFont(_selectedId.substring('custom:'.length));
  }

  Future<void> _loadCustomFont(String? family) async {
    if (family == null || _loadedCustomFonts.contains(family)) return;
    final record = _customFonts[family];
    if (record == null) return;
    try {
      final bytes = await File(record.path).readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(bytes.buffer.asByteData()));
      await loader.load();
      _loadedCustomFonts.add(family);
    } catch (_) {}
  }

  bool _isKnownId(String id) {
    if (id == vioClass.id || id == system.id) return true;
    if (!id.startsWith('custom:')) return false;
    return _customFonts.containsKey(id.substring('custom:'.length));
  }

  String _extension(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0) return '';
    return name.substring(index).toLowerCase();
  }

  String _stem(String name) {
    final normalized = name.replaceAll('\\', '/').split('/').last;
    final index = normalized.lastIndexOf('.');
    return index <= 0 ? normalized : normalized.substring(0, index);
  }
}

final TwitchAppFontController twitchAppFontController =
    TwitchAppFontController();

class _CustomFontRecord {
  final String label;
  final String path;

  const _CustomFontRecord({required this.label, required this.path});
}
