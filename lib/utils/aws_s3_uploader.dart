import 'dart:io';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart';

class AwsS3Uploader {
  static final AwsS3Uploader _instance = AwsS3Uploader._internal();
  factory AwsS3Uploader() => _instance;
  AwsS3Uploader._internal();

  String get _accessKey => dotenv.env['AWS_ACCESS_KEY'] ?? "";
  String get _secretKey => dotenv.env['AWS_SECRET_KEY'] ?? "";
  String get _bucketName => dotenv.env['AWS_S3_BUCKET_NAME'] ?? "";
  String get _region => dotenv.env['AWS_REGION'] ?? "";
  String get _destDir => "uploads/public";

  final ImagePicker _picker = ImagePicker();

  static Future<String?> uploadImage(XFile imageFile) async {
    final instance = AwsS3Uploader();
    try {
      final file = File(imageFile.path);
      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
      final objectKey = '${instance._destDir}/$fileName';

      final s3 = S3(
        region: instance._region,
        credentials: AwsClientCredentials(
          accessKey: instance._accessKey,
          secretKey: instance._secretKey,
        ),
      );

      await s3.putObject(
        bucket: instance._bucketName,
        key: objectKey,
        body: bytes,
        contentLength: bytes.length,
        contentType: lookupMimeType(file.path) ?? 'application/octet-stream',
      );

      final imageURL =
          'https://${instance._bucketName}.s3.${instance._region}.amazonaws.com/$objectKey';
      print("✅ Uploaded: $imageURL");
      return imageURL;
    } catch (e) {
      print('S3 Upload Error: $e');
      return null;
    }
  }
}
