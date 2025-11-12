// import 'dart:io';
// import 'package:aws_s3_upload_lite/aws_s3_upload_lite.dart';
// import 'package:aws_s3_upload_lite/enum/acl.dart'; // 👈 Import the ACL enum
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:mime/mime.dart';
// import 'package:path/path.dart';

// /// Singleton AWS S3 uploader class.
// /// Handles image upload with progress tracking and proper ACL configuration.
// class AwsS3Uploader {
//   static final AwsS3Uploader _instance = AwsS3Uploader._internal();
//   factory AwsS3Uploader() => _instance;
//   AwsS3Uploader._internal();

//   // --- AWS Config from .env ---
//   String get _accessKey => dotenv.env['AWS_ACCESS_KEY'] ?? "";
//   String get _secretKey => dotenv.env['AWS_SECRET_KEY'] ?? "";
//   String get _bucketName => dotenv.env['AWS_S3_BUCKET_NAME'] ?? "";
//   String get _region => dotenv.env['AWS_REGION'] ?? "";
//   String get _destDir => "uploads/public"; // Change as per your folder

//   /// Uploads an image to S3 and returns the public URL.
//   Future<String?> uploadImage(XFile imageFile) async {
//     try {
//       final file = File(imageFile.path);
//       final fileName =
//           '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
//       final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
//       final fileBytes = await file.readAsBytes();

//       print("🚀 Starting upload to S3...");
//       int lastPrinted = 0;

//       final response = await AwsS3.upload(
//         accessKey: _accessKey,
//         secretKey: _secretKey,
//         file: fileBytes,
//         bucket: _bucketName,
//         region: _region,
//         destDir: _destDir,
//         filename: fileName,
//         metadata: {'Content-Type': mimeType},
//         acl: ACL.public_read,
//  // ✅ Fixed type
//         onUploadProgress: (sent, total) {
//           int progress = ((sent / total) * 100).toInt();
//           if (progress - lastPrinted >= 5) {
//             lastPrinted = progress;
//             print('📤 Upload progress: $progress% ($sent/$total bytes)');
//           }
//         },
//       );

//       if (response != null) {
//         final imageUrl =
//             'https://$_bucketName.s3.$_region.amazonaws.com/$_destDir/$fileName';
//         print("✅ Upload complete: $imageUrl");
//         return imageUrl;
//       } else {
//         print('❌ Upload failed: No response from AWS');
//         return null;
//       }
//     } catch (e) {
//       print('❌ Upload error: $e');
//       return null;
//     }
//   }
// }
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import '../utils/api_service.dart';

class UploadResult {
  final String publicUrl;   // primary public URL
  final String? cdnUrl;     // secondary/cdn/public variant (if provided)
  final String? key;        // object key/path in bucket (if provided)

  const UploadResult({
    required this.publicUrl,
    this.cdnUrl,
    this.key,
  });

  @override
  String toString() => 'UploadResult(publicUrl: $publicUrl, cdnUrl: $cdnUrl, key: $key)';
}

class AwsS3Uploader {
  static final AwsS3Uploader _instance = AwsS3Uploader._internal();
  factory AwsS3Uploader() => _instance;
  AwsS3Uploader._internal();

  String get _apiBase => (dotenv.env['API_BASE_URL'] ?? '').trim();
  String get _presignPath => '/uploads/presign';
  String? get _folder => dotenv.env['UPLOAD_FOLDER']; // e.g. uploads/public

  Uri _buildApiUri(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p');
  }

  void _assertValidBase() {
    if (_apiBase.isEmpty) {
      throw ArgumentError('API_BASE_URL is empty. Set it to a full URL (e.g. https://api.example.com)');
    }
    final uri = Uri.tryParse(_apiBase);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError('Invalid API_BASE_URL: $_apiBase — must include scheme and host (e.g. https://dev-api.example.com)');
    }
  }

  /// Backwards-compatible: returns the primary public URL only.
  Future<String?> uploadImage(XFile imageFile, {String? folder}) async {
    final result = await uploadImageResult(imageFile, folder: folder);
    return result?.publicUrl;
  }

  /// Preferred: returns both public URLs (if backend provides two) and the key.
  Future<UploadResult?> uploadImageResult(XFile imageFile, {String? folder}) async {
    try {
      _assertValidBase();

      final file = File(imageFile.path);
      if (!await file.exists()) {
        print('❌ File not found: ${file.path}');
        return null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
      final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final selectedFolder = (folder ?? _folder)?.trim();

      // 1) Presign (authorized)
      final presignUrl = _buildApiUri(_apiBase, _presignPath);
      final presignPayload = <String, String>{
        'fileName': fileName,
        'contentType': contentType,
        if (selectedFolder != null && selectedFolder.isNotEmpty) 'folder': selectedFolder,
      };

      final token = await ApiService().getAuthToken();
      if (token == null || token.isEmpty) {
        print('❌ No auth token available for presign');
        return null;
      }

      print('📝 Presign request => $presignUrl  payload=$presignPayload');

      final presignResp = await http
          .post(
            presignUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(presignPayload),
          )
          .timeout(const Duration(seconds: 20));

      if (presignResp.statusCode < 200 || presignResp.statusCode >= 300) {
        print('❌ Presign failed: ${presignResp.statusCode} ${presignResp.body}');
        return null;
      }

      final decoded = jsonDecode(presignResp.body) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (!success || data == null) {
        print('❌ Presign response not successful: $decoded');
        return null;
      }

      // Flexible field names to be future-proof with your backend
      final uploadUrl  = (data['uploadUrl']  ?? data['upload_url'])  as String?;
      String? publicUrl = (data['publicUrl'] ?? data['public_url'] ?? data['url']) as String?;
      final cdnUrl     = (data['publicCdnUrl'] ?? data['cdnUrl'] ?? data['public_cdn_url']) as String?;
      final key        = (data['key'] ?? data['objectKey'] ?? data['path']) as String?;

      if (uploadUrl == null || publicUrl == null) {
        print('❌ Presign data missing uploadUrl/publicUrl: $data');
        return null;
      }

      // 2) Upload to Spaces with a simple PUT (no streaming hang)
      print('🚀 Uploading to Spaces…');
      final bytes = await file.readAsBytes();
      final putResp = await http
          .put(
            Uri.parse(uploadUrl),
            headers: {
              'Content-Type': contentType,
              // ⚠️ Do NOT add x-amz-acl unless the signature expects it
           'x-amz-acl': 'public-read',
            },
            body: bytes,
          )
          .timeout(const Duration(minutes: 2));

      if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
        // Some providers return no body; log status only if empty
        print('❌ Upload failed: ${putResp.statusCode} ${putResp.body}');
        return null;
      }

      // Prefer CDN URL if provided as the “secondary public”
      final result = UploadResult(
        publicUrl: publicUrl,
        cdnUrl: cdnUrl,
        key: key,
      );

      print('✅ Upload complete: $result');
      return result;
    } on TimeoutException catch (e) {
      print('⏱️ Timeout during upload: $e');
      return null;
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
