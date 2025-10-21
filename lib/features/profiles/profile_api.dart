import 'package:dio/dio.dart';

class ProfileApi {
  ProfileApi(this._dio);
  final Dio _dio;

  static const _root = '/api/profiles';

  Future<List<dynamic>> list() async {
    final r = await _dio.get(_root);
    return (r.data as List);
  }

  Future<Map<String, dynamic>> create({required String name, String? avatarUrl}) async {
    final r = await _dio.post(_root, data: {
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return r.data;
  }
}
