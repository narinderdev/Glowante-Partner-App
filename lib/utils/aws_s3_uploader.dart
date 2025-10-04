// import 'dart:io';
// import 'package:aws_s3_api/s3-2006-03-01.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mime/mime.dart';
// import 'package:path/path.dart';
// import 'package:image_picker/image_picker.dart';

// class AwsS3Uploader {
//   static final AwsS3Uploader _instance = AwsS3Uploader._internal();
//   factory AwsS3Uploader() => _instance;
//   AwsS3Uploader._internal();

//   String get _accessKey => dotenv.env['AWS_ACCESS_KEY'] ?? "";
//   String get _secretKey => dotenv.env['AWS_SECRET_KEY'] ?? "";
//   String get _bucketName => dotenv.env['AWS_S3_BUCKET_NAME'] ?? "";
//   String get _region => dotenv.env['AWS_REGION'] ?? "";
//   String get _destDir => "uploads/public";

//   final ImagePicker _picker = ImagePicker();

//   static Future<String?> uploadImage(XFile imageFile) async {
//     final instance = AwsS3Uploader();
//     try {
//       final file = File(imageFile.path);
//       final bytes = await file.readAsBytes();
//       final fileName = '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
//       final objectKey = '${instance._destDir}/$fileName';

//       final s3 = S3(
//         region: instance._region,
//         credentials: AwsClientCredentials(
//           accessKey: instance._accessKey,
//           secretKey: instance._secretKey,
//         ),
//       );

//       await s3.putObject(
//         bucket: instance._bucketName,
//         key: objectKey,
//         body: bytes,
//         contentLength: bytes.length,
//         contentType: lookupMimeType(file.path) ?? 'application/octet-stream',
//       );

//       final imageURL =
//           'https://${instance._bucketName}.s3.${instance._region}.amazonaws.com/$objectKey';
//       print("✅ Uploaded: $imageURL");
//       return imageURL;
//     } catch (e) {
//       print('S3 Upload Error: $e');
//       return null;
//     }
//   }
// }
import 'dart:io';
import 'package:aws_s3_upload_lite/aws_s3_upload_lite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';

class AwsS3Uploader {
  static final AwsS3Uploader _instance = AwsS3Uploader._internal();
  factory AwsS3Uploader() => _instance;
  AwsS3Uploader._internal();

  String get _accessKey => dotenv.env['AWS_ACCESS_KEY'] ?? "";
  String get _secretKey => dotenv.env['AWS_SECRET_KEY'] ?? "";
  String get _bucketName => dotenv.env['AWS_S3_BUCKET_NAME'] ?? "";
  String get _region => dotenv.env['AWS_REGION'] ?? "";
  String get _destDir => "uploads/public";

  // Future<String?> uploadImage(XFile imageFile) async {
  //   try {
  //     final file = File(imageFile.path);
  //     final fileName = '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
  //     final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
  //     final fileBytes = await file.readAsBytes();

  //     final response = await AwsS3.upload(
  //       accessKey: _accessKey,
  //       secretKey: _secretKey,
  //       file: fileBytes,
  //       bucket: _bucketName,
  //       region: _region,
  //       destDir: _destDir,
  //       filename: fileName,
  //       metadata: {'Content-Type': mimeType},
  //       onUploadProgress: (sentBytes, totalBytes) {
  //         print('Upload progress: $sentBytes/$totalBytes');
  //       },
  //     );

  //     if (response != null) {
  //       final imageURL = 'https://$_bucketName.s3.$_region.amazonaws.com/$_destDir/$fileName';
  //       print("✅ Uploaded: $imageURL");
  //       return imageURL;
  //     } else {
  //       print('❌ Upload failed');
  //       return null;
  //     }
  //   } catch (e) {
  //     print('S3 Upload Error: $e');
  //     return null;
  //   }
  // }
  Future<String?> uploadImage(XFile imageFile) async {
  final file = File(imageFile.path);
  final fileName = '${DateTime.now().millisecondsSinceEpoch}-${basename(file.path)}';
  final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
  final fileBytes = await file.readAsBytes();

  int lastPrinted = 0;

  final response = await AwsS3.upload(
    accessKey: _accessKey,
    secretKey: _secretKey,
    file: fileBytes,
    bucket: _bucketName,
    region: _region,
    destDir: _destDir,
    filename: fileName,
    metadata: {'Content-Type': mimeType},
    onUploadProgress: (sent, total) {
      // Print every 5% progress
      int progress = ((sent / total) * 100).toInt();
      if (progress - lastPrinted >= 5) {
        lastPrinted = progress;
        print('Upload progress: $progress% ($sent/$total bytes)');
      }
    },
  );

  if (response != null) {
    final imageURL = 'https://$_bucketName.s3.$_region.amazonaws.com/$_destDir/$fileName';
    print("✅ Uploaded: $imageURL");
    return imageURL;
  } else {
    print('❌ Upload failed');
    return null;
  }
}

}
