import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../network/dio_client.dart';

class ImageUploadService {
  final DioClient dioClient;
  final ImagePicker _picker = ImagePicker();

  ImageUploadService(this.dioClient);

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Upload user profile image
  Future<String> uploadUserProfileImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await dioClient.dio.post(
        '/api/v1/users/me/profile-image',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['s3Key'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to upload user profile image: $e');
    }
  }

  /// Upload profile avatar
  Future<String> uploadProfileAvatar(int profileId, File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await dioClient.dio.post(
        '/api/profiles/$profileId/avatar',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['s3Key'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to upload profile avatar: $e');
    }
  }

  /// Show image source selection dialog
  Future<ImageSource?> showImageSourceDialog() async {
    // This will be called from the UI and return the selected source
    return null; // Placeholder - will be implemented in UI
  }
}



