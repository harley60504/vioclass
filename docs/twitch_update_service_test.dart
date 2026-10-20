// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/services/update/vioclass_update_service.dart';

// Run both channels with VIOCLASS_VERSION=1.2.3. Every HTTP response is local;
// downloadPreferredAsset is exercised only when it rejects before filesystem IO.
const beta = String.fromEnvironment('VIOCLASS_UPDATE_CHANNEL') == 'beta';

Map<String, dynamic> release(String tag, {bool draft = false}) => {
  'tag_name': tag,
  'draft': draft,
  'name': ' Fixture ',
  'assets': [
    {'name': 'missing-url.zip'},
    {
      'name': 'VioClass-Windows.zip',
      'browser_download_url': 'https://fixture.invalid/windows.zip',
      'size': '123',
    },
    {
      'name': 'android.apk',
      'browser_download_url': 'https://fixture.invalid/android.apk',
      'size': 456,
    },
  ],
};

void main() {
  late Dio dio;
  late VioClassUpdateService service;
  late List<RequestOptions> requests;
  late Object response;
  var fail = false;
  setUp(() {
    requests = [];
    fail = false;
    response = beta ? [release('v1.2.4')] : release('v1.2.4');
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'fixture offline',
              ),
            );
          } else {
            handler.resolve(
              Response<Object>(
                requestOptions: options,
                data: response,
                statusCode: 200,
              ),
            );
          }
        },
      ),
    );
    service = VioClassUpdateService(dio: dio);
  });
  tearDown(() {
    service.dispose();
    dio.close(force: true);
  });

  for (final entry in <String, bool>{
    'v1.2.4': true,
    'v1.3.0': true,
    'v2.0.0': true,
    'v1.2.3': false,
    'V1.2.3+other-build': false,
    'v1.2': false,
    'v1.1.99': false,
  }.entries) {
    test('Numeric version comparison: ${entry.key}', () async {
      response = beta ? [release(entry.key)] : release(entry.key);
      final info = await service.checkLatest();
      expect(info.currentVersion, '1.2.3');
      expect(info.updateAvailable, entry.value);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.uri.path,
        beta
            ? '/repos/harley60504/vioclass/releases'
            : '/repos/harley60504/vioclass/releases/latest',
      );
      if (beta) expect(requests.single.queryParameters['per_page'], 20);
      expect(
        requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    });
  }

  test('Release assets parse and select the current OS', () {
    final parsed = VioClassRelease.fromGithubJson(release(' v1.2.4 '));
    expect(parsed.version, '1.2.4');
    expect(parsed.name, 'Fixture');
    expect(parsed.assets, hasLength(2));
    expect(parsed.assets.first.size, 123);
    expect(parsed.publishedAt, isNull);
    expect(
      parsed.preferredAsset!.name,
      Platform.isAndroid ? 'android.apk' : 'VioClass-Windows.zip',
    );
  });

  test(
    'Missing preferred asset rejects without download or progress',
    () async {
      var progressCalls = 0;
      final info = VioClassUpdateInfo(
        currentVersion: '1.2.3',
        updateAvailable: true,
        release: VioClassRelease.fromGithubJson({'tag_name': 'v1.2.4'}),
      );
      await expectLater(
        service.downloadPreferredAsset(
          info: info,
          onProgress: (_) => progressCalls++,
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);
      expect(progressCalls, 0);
    },
  );

  test('Network failure propagates and explicit retry succeeds', () async {
    fail = true;
    await expectLater(service.checkLatest(), throwsA(isA<DioException>()));
    fail = false;
    expect((await service.checkLatest()).updateAvailable, true);
    expect(requests, hasLength(2));
  });

  if (beta) {
    for (final tags in <List<String>>[
      ['v1.2.4-beta.2', 'v1.2.4-beta.10'],
      ['v1.2.4-beta.10', 'v1.2.4-beta.2'],
      ['v1.2.4-rc.1', 'v1.2.4'],
      ['v1.2.4-beta.1', 'v1.2.4-rc.1'],
      ['v1.2.4-beta', 'v1.2.4-beta.1'],
    ]) {
      test('Beta prerelease precedence ${tags.join(' / ')}', () async {
        response = tags.map(release).toList();
        final expected = tags.contains('v1.2.4')
            ? 'v1.2.4'
            : tags.contains('v1.2.4-rc.1')
            ? 'v1.2.4-rc.1'
            : tags.contains('v1.2.4-beta.10')
            ? 'v1.2.4-beta.10'
            : 'v1.2.4-beta.1';
        expect((await service.checkLatest()).release.tagName, expected);
      });
    }
    test('Beta selects highest numeric version and excludes drafts', () async {
      response = [
        release('v1.2.4-beta.1'),
        release('v99.0.0', draft: true),
        release(''),
        release('v1.4.0-beta.1'),
        release('v1.3.9'),
      ];
      expect((await service.checkLatest()).release.tagName, 'v1.4.0-beta.1');
    });

    test('Beta empty published list is not a successful no-update', () async {
      response = [release('v99.0.0', draft: true), release('')];
      await expectLater(service.checkLatest(), throwsStateError);
    });
  }
}
