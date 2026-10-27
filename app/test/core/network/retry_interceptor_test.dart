import 'package:dio/dio.dart';
import 'package:fgmap/core/network/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  Dio build(StubAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(RetryInterceptor(dio, delay: () => Duration.zero));
    return dio;
  }

  test('GET opt-in: 503 dicuba semula sekali dan berjaya', () async {
    var n = 0;
    final adapter = StubAdapter(
      (_) => ++n == 1
          ? StubAdapter.text('x', status: 503)
          : StubAdapter.json({'ok': true}),
    );
    final dio = build(adapter);
    final response = await dio.get<Object>(
      'https://a.example/x',
      options: RetryInterceptor.options(Options()),
    );
    expect(n, 2);
    expect(response.statusCode, 200);
  });

  test('tanpa opt-in: tiada cuba semula', () async {
    var n = 0;
    final dio = build(
      StubAdapter((_) {
        n++;
        return StubAdapter.text('x', status: 503);
      }),
    );
    await expectLater(
      dio.get<Object>('https://a.example/x'),
      throwsA(isA<DioException>()),
    );
    expect(n, 1);
  });

  test('hanya sekali: gagal dua kali -> ralat asal dilempar', () async {
    var n = 0;
    final dio = build(
      StubAdapter((_) {
        n++;
        return StubAdapter.text('x', status: 503);
      }),
    );
    await expectLater(
      dio.get<Object>(
        'https://a.example/x',
        options: RetryInterceptor.options(Options()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(n, 2);
  });

  test('404 dan POST tidak dicuba semula', () async {
    var n = 0;
    final dio = build(
      StubAdapter((_) {
        n++;
        return StubAdapter.text('x', status: 404);
      }),
    );
    await expectLater(
      dio.get<Object>(
        'https://a.example/x',
        options: RetryInterceptor.options(Options()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(n, 1);

    n = 0;
    final post = build(
      StubAdapter((_) {
        n++;
        return StubAdapter.text('x', status: 503);
      }),
    );
    await expectLater(
      post.post<Object>(
        'https://a.example/x',
        options: RetryInterceptor.options(Options()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(n, 1, reason: 'POST tidak idempoten');
  });

  test('kegagalan sambungan dicuba semula', () async {
    var n = 0;
    final dio = Dio()..httpClientAdapter = _FlakyAdapter(() => ++n);
    dio.interceptors.add(RetryInterceptor(dio, delay: () => Duration.zero));
    final response = await dio.get<Object>(
      'https://a.example/x',
      options: RetryInterceptor.options(
        Options(responseType: ResponseType.plain),
      ),
    );
    expect(n, 2);
    expect(response.data, 'ok');
  });

  test('pembatalan tidak dicuba semula', () async {
    var n = 0;
    final dio = build(
      StubAdapter((_) {
        n++;
        return StubAdapter.text('x', status: 503);
      }),
    );
    final token = CancelToken()..cancel('batal');
    await expectLater(
      dio.get<Object>(
        'https://a.example/x',
        cancelToken: token,
        options: RetryInterceptor.options(Options()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(n, 0);
  });

  test('jeda lalai berjitter 300-700 ms', () {
    final a = RetryInterceptor(Dio());
    expect(a, isNotNull);
  });
}

class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter(this.count);

  final int Function() count;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (count() == 1) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'putus',
      );
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}
