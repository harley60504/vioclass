// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import '../lib/features/twitch/presentation/widgets/shared/twitch_login_webview_host.dart';

/// Isolated Windows input test: no login, authentication hooks or saved cookies.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _InputProbe(),
    ),
  );
}

class _InputProbe extends StatefulWidget {
  const _InputProbe();
  @override
  State<_InputProbe> createState() => _InputProbeState();
}

class _InputProbeState extends State<_InputProbe> {
  bool _excludeFlutterFocus = false;
  late final Future<WebViewEnvironment> _environment = _createEnvironment();

  Future<WebViewEnvironment> _createEnvironment() async {
    final profile = await Directory.systemTemp.createTemp(
      'vioclass_input_probe_',
    );
    return WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
    );
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reportFocus);
  }

  void _reportFocus() {
    debugPrint(
      '[InputProbe][flutter-focus] '
      '${FocusManager.instance.primaryFocus?.debugLabel ?? 'none'}',
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reportFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('WebView 輸入測試（不會登入）'),
      actions: [
        IconButton(
          tooltip: '關閉',
          onPressed: () => windowManager.close(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    body: Column(
      children: [
        SwitchListTile(
          title: const Text('隔離 Flutter 焦點（比較用，非正式修正）'),
          value: _excludeFlutterFocus,
          onChanged: (value) => setState(() => _excludeFlutterFocus = value),
        ),
        Expanded(
          child: TwitchLoginWebViewHost(
            createEnvironment: () => _environment,
            builder: (environment) => ExcludeFocus(
              excluding: _excludeFlutterFocus,
              child: InAppWebView(
                webViewEnvironment: environment,
                initialData: InAppWebViewInitialData(data: _html),
                initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                onConsoleMessage: (_, message) {
                  if (message.message.startsWith('[InputProbe]')) {
                    debugPrint(message.message);
                  }
                },
                onLoadStart: (_, _) => debugPrint('[InputProbe][load-start]'),
                onLoadStop: (_, _) => debugPrint('[InputProbe][load-stop]'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

const _html = '''<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{background:#18181b;color:#eee;font:20px sans-serif;padding:24px}
input{display:block;margin:20px 0;padding:16px;font-size:22px;width:80%}</style>
</head><body><p>請點輸入框，輸入 abc，再切換上方開關比較。</p>
<p>不要填真實帳號或密碼。這頁沒有授權或網路請求。</p>
<input id="text" placeholder="一般輸入框"><input id="password" type="password" placeholder="測試密碼框">
<script>
const report=(event)=>console.log('[InputProbe][dom] '+event.type+
' target='+(event.target.id||event.target.tagName||'window')+
' focused='+document.hasFocus()+' active='+(document.activeElement?.id||document.activeElement?.tagName)+
' time='+Math.round(performance.now()));
for(const type of ['pointerdown','pointerup','focusin','focusout'])document.addEventListener(type,report,true);
for(const type of ['focus','blur'])window.addEventListener(type,report);
</script></body></html>''';
