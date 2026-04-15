import 'dart:io';

import 'package:dio/dio.dart';

import '../models/audio_process_response.dart';

/// Exception thrown when API operations fail.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.originalException,
  });

  final String message;
  final int? statusCode;
  final Exception? originalException;

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Service for communicating with the FastAPI backend for audio processing.
/// 
/// Handles audio file uploads, transcription, translation, and summarization.
class ApiService {
  /// Base URL of the FastAPI backend.
  static const String _baseUrl = String.fromEnvironment(
    'AURA_API_BASE_URL',
    defaultValue: 'http://192.168.1.74:8000',
  );

  /// Endpoint for audio processing.
  static const String _processAudioEndpoint = '/process-audio';

  /// Request timeout in seconds.
  static const Duration _requestTimeout = Duration(seconds: 120);

  /// Maximum number of retry attempts for failed requests.
  static const int _maxRetries = 2;

  late final Dio _dio;

  ApiService() {
    _initializeDio();
  }

  /// Initializes the Dio HTTP client with proper configuration.
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        sendTimeout: _requestTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Add logging interceptor for debugging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[Dio] $obj'),
      ),
    );
  }

  /// Valid categories for audio processing.
  static const List<String> validCategories = [
    'Medical consultation',
    'Business meeting',
    'Interview',
    'Lecture / class',
    'Personal note',
    'Legal / official',
    'Other',
  ];

  /// Validates that the category matches exactly one of the valid categories.
  static bool isValidCategory(String category) {
    return validCategories.contains(category);
  }

  /// Processes an audio file with the FastAPI backend.
  /// 
  /// Parameters:
  ///   - [audioPath]: Full file system path to the audio file (typically .m4a)
  ///   - [category]: Recording context - must match one of [validCategories] exactly
  ///   - [detail]: Optional additional context about the recording
  ///   - [onProgress]: Optional callback for upload progress (0.0 to 1.0)
  /// 
  /// Returns an [AudioProcessResponse] containing the transcript, summary, etc.
  /// 
  /// Throws [ApiException] if:
  ///   - [audioPath] file does not exist
  ///   - [category] is not valid
  ///   - HTTP request fails
  ///   - Response cannot be parsed
  /// 
  /// Example:
  /// ```dart
  /// final response = await apiService.uploadAudioAndProcess(
  ///   '/sdcard/Aura_001.m4a',
  ///   'Medical consultation',
  ///   'Patient checkup conversation',
  /// );
  /// print('Transcript: ${response.transcript}');
  /// print('Summary: ${response.summary}');
  /// ```
  Future<AudioProcessResponse> uploadAudioAndProcess({
    required String audioPath,
    required String category,
    String? detail,
    ProgressCallback? onProgress,
  }) async {
    // Validate audio file exists
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw ApiException(
        message: 'Audio file not found at path: $audioPath',
      );
    }

    // Validate category
    if (!isValidCategory(category)) {
      throw ApiException(
        message: 'Invalid category: "$category". Must be one of: ${validCategories.join(", ")}',
      );
    }

    // Retry logic
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _uploadAudioWithRetry(
          audioPath: audioPath,
          category: category,
          detail: detail,
          onProgress: onProgress,
        );
      } on ApiException {
        rethrow; // Don't retry validation errors
      } catch (e) {
        if (attempt == _maxRetries) {
          // Final attempt failed
          throw ApiException(
            message: 'Audio processing failed after ${_maxRetries + 1} attempts',
            originalException: e is Exception ? e : Exception(e.toString()),
          );
        }
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    throw ApiException(
      message: 'Unexpected error in upload retry loop',
    );
  }

  /// Internal method that performs the actual multipart upload.
  Future<AudioProcessResponse> _uploadAudioWithRetry({
    required String audioPath,
    required String category,
    String? detail,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: File(audioPath).path.split(Platform.pathSeparator).last,
        ),
        'category': category,
        if (detail != null && detail.isNotEmpty) 'detail': detail,
      });

      // Send POST request
      final response = await _dio.post(
        _processAudioEndpoint,
        data: formData,
        onSendProgress: onProgress,
      );

      // Check response status
      if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
        throw ApiException(
          message: 'Server returned status ${response.statusCode}: ${response.statusMessage}',
          statusCode: response.statusCode,
        );
      }

      // Parse response data
      if (response.data is! Map<String, dynamic>) {
        throw ApiException(
          message: 'Invalid response format from server',
        );
      }

      return AudioProcessResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error during audio processing: $e',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Converts Dio exceptions into user-friendly [ApiException] objects.
  ApiException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException(
          message: 'Request timeout. The server is taking too long to respond. Please check your connection and try again.',
          originalException: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String errorMessage = 'Server error (Status: $statusCode)';

        // Try to extract error message from response
        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['detail'] ?? 
              responseData['message'] ?? 
              responseData['error'] ?? 
              errorMessage;
        }

        return ApiException(
          message: errorMessage,
          statusCode: statusCode,
          originalException: e,
        );

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return ApiException(
            message: _buildSocketExceptionMessage(e.error as SocketException),
            originalException: e,
          );
        }
        return ApiException(
          message: 'Network error: ${e.message}',
          originalException: e,
        );

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request cancelled.',
          originalException: e,
        );

      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'SSL certificate error. Cannot establish secure connection.',
          originalException: e,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: _buildConnectionErrorMessage(e.message),
          originalException: e,
        );
    }
  }

  String _buildSocketExceptionMessage(SocketException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('connection refused')) {
      return 'Cannot connect to backend at $_baseUrl. '
          'Server may be down or not listening on LAN. '
          'Start FastAPI with --host 0.0.0.0 --port 8000.';
    }

    if (msg.contains('failed host lookup')) {
      return 'Cannot resolve backend host in $_baseUrl. '
          'Check the IP/domain and ensure phone/emulator is on the same network.';
    }

    if (msg.contains('network is unreachable') || msg.contains('no route to host')) {
      return 'Backend unreachable at $_baseUrl. '
          'Ensure device and backend PC are on the same Wi-Fi and firewall allows port 8000.';
    }

    return 'Connection to backend failed at $_baseUrl. '
        'Check Wi-Fi/LAN, backend server status, and Android cleartext permissions.';
  }

  String _buildConnectionErrorMessage(String? dioMessage) {
    final raw = (dioMessage ?? '').toLowerCase();

    if (raw.contains('connection refused')) {
      return 'Cannot connect to backend at $_baseUrl (connection refused). '
          'Make sure FastAPI is running and bound to 0.0.0.0:8000.';
    }

    return 'Connection error while reaching $_baseUrl. '
        'Verify backend is running, device is on same network, and port 8000 is accessible.';
  }

  /// Disposes the Dio client when the service is no longer needed.
  void dispose() {
    _dio.close();
  }
}
