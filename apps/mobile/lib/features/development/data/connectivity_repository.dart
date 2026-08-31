import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

enum ConnectivityProbeResult { apiUnavailable, databaseUnavailable, ready }

abstract interface class ConnectivityRepository {
  Future<ConnectivityProbeResult> check();
}

final connectivityRepositoryProvider = Provider<ConnectivityRepository>(
  (ref) => DioConnectivityRepository(ref.watch(dioProvider)),
);

class DioConnectivityRepository implements ConnectivityRepository {
  DioConnectivityRepository(this._dio);

  final Dio _dio;

  @override
  Future<ConnectivityProbeResult> check() async {
    try {
      final healthResponse = await _dio.get<Map<String, dynamic>>('/health');
      if (healthResponse.statusCode != 200 ||
          healthResponse.data?['status'] != 'ok') {
        return ConnectivityProbeResult.apiUnavailable;
      }
    } on DioException {
      return ConnectivityProbeResult.apiUnavailable;
    } on Object {
      return ConnectivityProbeResult.apiUnavailable;
    }

    try {
      final readyResponse = await _dio.get<Map<String, dynamic>>('/ready');
      if (readyResponse.statusCode == 200 &&
          readyResponse.data?['status'] == 'ready' &&
          readyResponse.data?['database'] == 'connected') {
        return ConnectivityProbeResult.ready;
      }
      if (readyResponse.statusCode == 503) {
        return ConnectivityProbeResult.databaseUnavailable;
      }
      return ConnectivityProbeResult.apiUnavailable;
    } on DioException catch (error) {
      if (error.response?.statusCode == 503) {
        return ConnectivityProbeResult.databaseUnavailable;
      }
      return ConnectivityProbeResult.apiUnavailable;
    } on Object {
      return ConnectivityProbeResult.apiUnavailable;
    }
  }
}
