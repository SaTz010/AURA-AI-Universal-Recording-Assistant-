# API Integration - Quick Reference

## Files Created/Modified

| File | Type | Purpose |
|------|------|---------|
| `lib/services/api_service.dart` | Created | HTTP client with multipart support, retry logic, error handling |
| `lib/models/audio_process_response.dart` | Created | Response model for API responses |
| `lib/screens/audio_process_result_screen.dart` | Created | UI for displaying processing results |
| `lib/screens/recordings_screen.dart` | Modified | Integrated API calls in summarize flow |
| `pubspec.yaml` | Modified | Added `dio: ^5.3.0` dependency |

## API Endpoint

```
POST https://backendforaura.onrender.com/process-audio
Content-Type: multipart/form-data

Input:
  - audio: File (m4a audio file)
  - category: String (must match predefined list exactly)
  - detail: String (optional, for additional context)

Output:
  {
    "transcript": "string",
    "summary": "string",
    "translation": "string or null",
    "cost": 0.0 (number)
  }
```

## Valid Categories (Exact Match Required)

```dart
'Medical consultation'
'Business meeting'
'Interview'
'Lecture / class'
'Personal note'
'Legal / official'
'Other'
```

## Usage Example

```dart
final apiService = ApiService();

try {
  final response = await apiService.uploadAudioAndProcess(
    audioPath: '/path/to/audio.m4a',
    category: 'Medical consultation',
    detail: 'Optional context',
  );
  
  // Use response
  print('Transcript: ${response.transcript}');
  print('Summary: ${response.summary}');
} catch (e) {
  if (e is ApiException) {
    print('Error: ${e.message}');
  }
}
```

## Implementation in RecordingsScreen

The `_startSummarizeFlowForEntry()` method:
1. Prompts user to select category (7 options)
2. Optionally asks for additional details
3. Shows "Processing..." loading screen
4. Calls `_processAudioWithApi()` which:
   - Validates inputs
   - Uploads audio via multipart
   - Handles retries automatically
   - Shows result or error

## Key Features

**Timeout**: 120 seconds (configurable in `ApiService._requestTimeout`)
**Retries**: 2 automatic retries with exponential backoff
**Validation**: Category must match exactly (case-sensitive)
**Multipart**: Proper multipart/form-data encoding (auto-handled by Dio)
**Error Handling**: User-friendly error messages with retry option
**Logging**: Full request/response logging for debugging

## Configuration

### Change Base URL
```dart
// In ApiService class
static const String _baseUrl = 'http://YOUR_SERVER:8000';
```

### Change Timeout
```dart
// In ApiService class
static const Duration _requestTimeout = Duration(seconds: 180);
```

### Add Custom Headers
```dart
// In ApiService._initializeDio()
_dio = Dio(
  BaseOptions(
    baseUrl: _baseUrl,
    headers: {
      'Authorization': 'Bearer $token',
      'X-Custom-Header': 'value',
    },
  ),
);
```

## Error Types

| Error | Cause | User Message |
|-------|-------|--------------|
| 400 | Invalid category/request | "Server returned status 400:..." |
| 401 | Unauthorized | (Configure auth headers first) |
| 500 | Server error | "Server error (Status: 500)" |
| Timeout | Server slow/unreachable | "Request timeout. Please check connection and try again." |
| Network | No internet | "Network error. Please check your internet connection." |

## Important Notes

✅ **Multipart handling**: Dio automatically sets correct Content-Type
✅ **File validation**: File existence is checked before upload
✅ **Category validation**: Happens before network request
✅ **Duplicate prevention**: Current implementation checks local storage
✅ **Progress tracking**: Optional `onProgress` callback for upload progress
✅ **Local caching**: Results automatically saved to `SummariesStorage`

## Testing Checklist

- [ ] Backend is running at `https://backendforaura.onrender.com`
- [ ] `/process-audio` endpoint exists and accepts POST
- [ ] Endpoint accepts multipart/form-data with audio, category, detail
- [ ] Endpoint returns valid JSON with transcript, summary, cost
- [ ] Network is accessible from Flutter app device
- [ ] Category validation works (test invalid category → 400 error)
- [ ] Long processing times handled gracefully (test 60+ second delay)
- [ ] Error scenarios handled (network error, 500, timeout)

## Production Deployment

**For production**, consider:

1. **Change IP to domain/subdomain**
   ```dart
   static const String _baseUrl = 'https://api.yourdomain.com';
   ```

2. **Add HTTPS certificate pinning**
   ```dart
   _dio.httpClientAdapter = IOHttpClientAdapter()
     ..onHttpClientCreate = (client) {
       // Add certificate pinning
       return client;
     };
   ```

3. **Add request signing**
   ```dart
   _dio.interceptors.add(InterceptorsWrapper(
     onRequest: (options, handler) {
       options.headers['Authorization'] = 'Bearer $token';
       return handler.next(options);
     },
   ));
   ```

4. **Use environment variables**
   ```bash
   flutter run \
     --dart-define=API_BASE_URL=https://api.prod.com \
     --dart-define=API_TIMEOUT=120
   ```

## Troubleshooting

**Q: Category error even though I used the right string?**
A: Check for extra spaces or capitalization. Use the exact strings from the list.

**Q: Upload timeout after 120 seconds?**
A: Increase `_requestTimeout` if backend needs longer. Or optimize backend processing.

**Q: Multipart encoding issues?**
A: Ensure audio file path is valid. File must exist before upload.

**Q: Can't connect to backend?**
A: Verify the URL is correct, check internet access, and confirm the Render service is running.

**Q: Results not showing?**
A: Check if response JSON matches expected schema (transcript, summary, cost required).

---

For full documentation, see: `BACKEND_INTEGRATION_GUIDE.md`
