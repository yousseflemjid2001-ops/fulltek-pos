import 'dart:convert';
import '../models/models.dart';
import 'http_bridge.dart';

typedef HttpTransport = Future<({int status, String body})> Function(
  String method,
  String url, {
  String? body,
  Map<String, String>? headers,
  Duration timeout,
});

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final List<CatalogImportRowError> errors;

  const ApiException({
    this.statusCode,
    required this.message,
    this.errors = const [],
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiResult<T> {
  final bool ok;
  final int? statusCode;
  final T? data;
  final String? error;
  final List<CatalogImportRowError> errors;

  const ApiResult.success(this.data, {this.statusCode = 200})
      : ok = true,
        error = null,
        errors = const [];

  const ApiResult.failure(
    this.error, {
    this.statusCode,
    this.errors = const [],
  })  : ok = false,
        data = null;
}

class ApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
  static String baseUrl = defaultBaseUrl;
  static HttpTransport httpTransport = httpRequest;

  static String? _token;
  static AdminProfile? _adminProfile;
  static void Function()? onUnauthorized;

  static String? get token => _token;
  static AdminProfile? get adminProfile => _adminProfile;
  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  static void setToken(String token, {AdminProfile? admin}) {
    _token = token;
    if (admin != null) {
      _adminProfile = admin;
    }
  }

  static void clearToken() {
    _token = null;
    _adminProfile = null;
  }

  static void resetForTest() {
    baseUrl = defaultBaseUrl;
    httpTransport = httpRequest;
    _token = null;
    _adminProfile = null;
    onUnauthorized = null;
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static Future<({int status, Map<String, dynamic> json, String rawBody})> _send(
    String method,
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 5),
    bool requiresAdminAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    final isProtectedAdminPath = path.startsWith('/api/admin/') &&
        path != '/api/admin/login' &&
        path != '/api/admin/auth/login';
    if (requiresAdminAuth &&
        isProtectedAdminPath &&
        _token != null &&
        _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    final res = await httpTransport(
      method,
      '$baseUrl$path',
      body: body == null ? null : jsonEncode(body),
      headers: headers,
      timeout: timeout,
    );

    Map<String, dynamic> decoded = const {};
    if (res.body.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(res.body);
        decoded = _asMap(parsed);
      } on FormatException {
        if (res.status >= 200 && res.status < 300) {
          throw const ApiException(message: 'Réponse JSON invalide du serveur');
        }
      }
    }

    if (res.status == 401) {
      if (requiresAdminAuth && isProtectedAdminPath) {
        clearToken();
        onUnauthorized?.call();
      }
      throw ApiException(
        statusCode: 401,
        message: (decoded['error'] as String?) ?? 'Non autorisé (401)',
      );
    }

    if (res.status < 200 || res.status >= 300) {
      final rowErrors = (decoded['errors'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CatalogImportRowError.fromJson(_asMap(e)))
          .toList();
      throw ApiException(
        statusCode: res.status,
        message: (decoded['error'] as String?) ?? 'Erreur HTTP ${res.status}',
        errors: rowErrors,
      );
    }

    return (status: res.status, json: decoded, rawBody: res.body);
  }

  static Future<ApiResult<T>> _guard<T>(
    Future<ApiResult<T>> Function() action,
  ) async {
    try {
      return await action();
    } on ApiException catch (e) {
      return ApiResult.failure(
        e.message,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  static Future<ApiResult<({String token, int expiresIn, AdminProfile admin})>>
      loginSuperAdmin(String username, String password) {
    return _guard(() async {
      final res = await _send(
        'POST',
        '/api/admin/login',
        body: {
          'username': username.trim(),
          'password': password,
        },
        requiresAdminAuth: false,
      );
      final token = (res.json['token'] as String?) ?? '';
      if (token.isEmpty) {
        return const ApiResult.failure(
          'Réponse de connexion invalide (jeton manquant)',
        );
      }
      final expiresIn = (res.json['expiresIn'] as num?)?.toInt() ?? 86400;
      final adminMap = _asMap(res.json['admin']);
      final admin = AdminProfile.fromJson(adminMap);
      setToken(token, admin: admin);
      return ApiResult.success(
        (token: token, expiresIn: expiresIn, admin: admin),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<AdminProfile>> fetchMe() {
    return _guard(() async {
      final res = await _send('GET', '/api/admin/me');
      final adminMap = res.json['admin'] != null
          ? _asMap(res.json['admin'])
          : res.json;
      final admin = AdminProfile.fromJson(adminMap);
      _adminProfile = admin;
      return ApiResult.success(admin, statusCode: res.status);
    });
  }

  static Future<
      ApiResult<
          ({
            List<TenantStore> stores,
            List<SubscriptionPayment> payments,
            List<AuditEntry> audits,
          })>> fetchDashboard() {
    return _guard(() async {
      final res = await _send('GET', '/api/admin/dashboard');
      final data = res.json;
      final stores = (data['stores'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TenantStore.fromJson(_asMap(e)))
          .toList();
      final payments = (data['payments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SubscriptionPayment.fromJson(_asMap(e)))
          .toList();
      final audits = (data['audits'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AuditEntry.fromJson(_asMap(e)))
          .toList();
      return ApiResult.success(
        (stores: stores, payments: payments, audits: audits),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<TenantStore>> createTenant(TenantStore store) {
    return _guard(() async {
      final res = await _send(
        'POST',
        '/api/admin/tenants',
        body: store.toJson(),
      );
      final tenantJson = res.json['tenant'] != null
          ? _asMap(res.json['tenant'])
          : res.json;
      return ApiResult.success(
        TenantStore.fromJson(tenantJson),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<TenantStore>> updateTenant(TenantStore store) {
    return _guard(() async {
      final res = await _send(
        'PATCH',
        '/api/admin/tenants/${store.id}',
        body: store.toJson(),
      );
      final tenantJson = res.json['tenant'] != null
          ? _asMap(res.json['tenant'])
          : res.json;
      return ApiResult.success(
        TenantStore.fromJson(tenantJson),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<TenantStore>> extendTenant(
    int id, {
    int days = 30,
  }) {
    return _guard(() async {
      final res = await _send(
        'POST',
        '/api/admin/tenants/$id/extend',
        body: {'days': days},
      );
      final tenantJson = res.json['tenant'] != null
          ? _asMap(res.json['tenant'])
          : res.json;
      return ApiResult.success(
        TenantStore.fromJson(tenantJson),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<TenantStore>> toggleLock(int id) {
    return _guard(() async {
      final res = await _send('POST', '/api/admin/tenants/$id/toggle-lock');
      final tenantJson = res.json['tenant'] != null
          ? _asMap(res.json['tenant'])
          : res.json;
      return ApiResult.success(
        TenantStore.fromJson(tenantJson),
        statusCode: res.status,
      );
    });
  }

  static Future<ApiResult<OfflineLicenseResponse>> generateOfflineCode(
    int id,
    int days, {
    int graceDays = 7,
    String? registerCode,
    String? hardwareFingerprint,
  }) {
    return _guard(() async {
      final res = await _send(
        'POST',
        '/api/admin/tenants/$id/offline-code',
        body: {
          'days': days,
          'graceDays': graceDays,
          if (registerCode != null && registerCode.trim().isNotEmpty)
            'registerCode': registerCode.trim(),
          if (hardwareFingerprint != null &&
              hardwareFingerprint.trim().isNotEmpty)
            'hardwareFingerprint': hardwareFingerprint.trim(),
        },
      );
      final license = OfflineLicenseResponse.fromJson(res.json);
      if (license.code.isEmpty) {
        return const ApiResult.failure(
          'Réponse licence invalide (code manquant)',
        );
      }
      return ApiResult.success(license, statusCode: res.status);
    });
  }

  static Future<ApiResult<void>> logSupport(int id) {
    return _guard(() async {
      final res = await _send('POST', '/api/admin/tenants/$id/support');
      return ApiResult.success(null, statusCode: res.status);
    });
  }

  static Future<ApiResult<void>> approvePayment(String payCode) {
    return _guard(() async {
      final res = await _send(
        'POST',
        '/api/admin/payments/${Uri.encodeComponent(payCode)}/approve',
      );
      return ApiResult.success(null, statusCode: res.status);
    });
  }

  static Future<ApiResult<CatalogImportResult>> importCatalog(
    int tenantId, {
    required String filename,
    required String format,
    String? csvText,
    String? contentBase64,
  }) {
    return _guard(() async {
      final fmt = format.trim().toLowerCase();
      if (fmt != 'csv' && fmt != 'xlsx') {
        return const ApiResult.failure(
          'Format non supporté : utilisez .csv ou .xlsx',
          statusCode: 400,
        );
      }
      if (fmt == 'csv' && (csvText == null || csvText.trim().isEmpty)) {
        return const ApiResult.failure(
          'Contenu CSV vide',
          statusCode: 400,
        );
      }
      if (fmt == 'xlsx' &&
          (contentBase64 == null || contentBase64.trim().isEmpty)) {
        return const ApiResult.failure(
          'Contenu XLSX Base64 vide',
          statusCode: 400,
        );
      }

      final res = await _send(
        'POST',
        '/api/admin/tenants/$tenantId/catalog/import',
        timeout: const Duration(seconds: 30),
        body: {
          'filename': filename,
          'format': fmt,
          'csvText': ?csvText,
          'contentBase64': ?contentBase64,
        },
      );
      final parsed = CatalogImportResult.fromJson(res.json, forceOk: true);
      return ApiResult.success(parsed, statusCode: res.status);
    });
  }
}
