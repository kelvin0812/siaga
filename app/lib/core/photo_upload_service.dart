import 'dart:math';
import 'package:http/http.dart' as http;

/// Uploads a report photo directly to Supabase Storage's REST API, bypassing
/// the FastAPI backend for the file bytes themselves — report_screen.dart's
/// ReportIn.photo_url doc comment already assumed this shape ("set by the
/// client after it uploads the photo directly to object storage"). Only the
/// resulting public URL is ever sent to the backend (ApiClient.submitReport),
/// so the Section 5.3 /reports endpoint stays a small JSON body.
///
/// The embedded key is Supabase's anon/publishable key, which is designed to
/// be public (it's shipped in every Supabase client app) and is constrained
/// by the storage.objects RLS policies on the report-photos bucket: anon may
/// INSERT (upload) and SELECT (read back a public URL) but never UPDATE or
/// DELETE. This is not the same class of secret as the backend's
/// DATABASE_URL or a service-role key, so committing it here is intentional,
/// not an oversight of Section 10's "secrets in env vars" rule.
class PhotoUploadService {
  static const _baseUrl = 'https://oqsdoubmzzkfgcvvsbfb.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xc2RvdWJtenprZmdjdnZzYmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MzQxNTksImV4cCI6MjEwMjIxMDE1OX0.QizwV00qxMexZNUKVQ7V7LOCBBBNe3CfdzvBVohjOb8';
  static const _bucket = 'report-photos';

  final http.Client _client;
  PhotoUploadService({http.Client? client}) : _client = client ?? http.Client();

  /// Uploads [bytes] and returns the public URL to store as ReportIn's
  /// photo_url. Throws [PhotoUploadException] on failure — the caller
  /// decides whether to block submission or drop the photo and continue.
  Future<String> upload(List<int> bytes, {required String contentType}) async {
    final ext = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        'report_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.$ext';

    final res = await _client.post(
      Uri.parse('$_baseUrl/storage/v1/object/$_bucket/$path'),
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (res.statusCode != 200) {
      throw PhotoUploadException('Photo upload failed: ${res.statusCode}');
    }
    return '$_baseUrl/storage/v1/object/public/$_bucket/$path';
  }

  String _randomSuffix() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  }
}

class PhotoUploadException implements Exception {
  final String message;
  PhotoUploadException(this.message);
  @override
  String toString() => 'PhotoUploadException: $message';
}
