# FastAPI Backend Integration Guide

## Quick Start

Your Flutter app is now fully integrated with the FastAPI audio processing backend. The integration handles:
- ✅ Multipart form-data uploads
- ✅ Category validation (7 predefined categories)
- ✅ Long-running requests (up to 120 seconds)
- ✅ Automatic retry logic with exponential backoff
- ✅ Error handling and user feedback
- ✅ Response parsing and display
- ✅ Local caching of results

## User Flow

1. **User taps "Summarize"** on any recording in the Recordings screen
2. **Category selection** - User selects from 7 predefined categories:
   - Medical consultation
   - Business meeting
   - Interview
   - Lecture / class
   - Personal note
   - Legal / official
   - Other
3. **Extra details (optional)** - User can add context about the recording
4. **Processing screen** - Shows "Processing..." with animated loading indicator
5. **Results screen** - Displays:
   - Summary (tabbed view)
   - Transcript
   - Translation (if available)
   - Processing cost
   - Copy/Share buttons
6. **Local storage** - Result is automatically saved for offline reference

## API Integration Details

### Endpoint Configuration
```dart
// lib/services/api_service.dart
static const String _baseUrl = 'http://192.168.1.74:8000';
static const String _processAudioEndpoint = '/process-audio';
```

### Request Format
```
POST /process-audio
Content-Type: multipart/form-data

Fields:
- audio: m4a file (required)
- category: string (required, must match exactly)
- detail: string (optional)
```

### Response Format
```json
{
  "transcript": "Full transcribed text...",
  "summary": "Concise summary...",
  "translation": "Translated text (optional)",
  "cost": 0.15
}
```

## Code Examples

### Basic Usage
```dart
final apiService = ApiService();

try {
  final response = await apiService.uploadAudioAndProcess(
    audioPath: '/path/to/recording.m4a',
    category: 'Medical consultation',  // Must match exactly
    detail: 'Patient checkup conversation',
  );
  
  print('Transcript: ${response.transcript}');
  print('Summary: ${response.summary}');
  print('Cost: \$${response.cost}');
} catch (e) {
  if (e is ApiException) {
    print('API Error: ${e.message}');
  }
}
```

### With Progress Tracking
```dart
final response = await apiService.uploadAudioAndProcess(
  audioPath: recordingPath,
  category: selectedCategory,
  detail: optionalDetail,
  onProgress: (count, total) {
    final progress = count / total;
    print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

### Validate Category Before Sending
```dart
if (!ApiService.isValidCategory(userCategory)) {
  showError('Invalid category: $userCategory');
  return;
}
```

## Architecture

### Classes
- **`ApiService`** - HTTP client with retry/timeout logic
- **`AudioProcessResponse`** - Response model with JSON serialization
- **`AudioProcessResultScreen`** - UI for displaying results
- **`_RecordingsScreenState`** - Integration point that calls API

### Error Handling
The integration includes comprehensive error handling:

```dart
try {
  final response = await _apiService.uploadAudioAndProcess(...);
} on ApiException catch (e) {
  // Handle API-specific errors
  final message = e.message; // User-friendly message
  final statusCode = e.statusCode; // HTTP status if available
}
```

## Testing the Integration

### 1. Mock API Testing
Before connecting to the real backend, test with a mock API:

```dart
// Create a mock response for testing
final mockResponse = AudioProcessResponse(
  transcript: 'Test transcript...',
  summary: 'Test summary...',
  translation: null,
  cost: 0.10,
);
```

### 2. Real Backend Testing
Ensure the FastAPI backend is running:
```bash
# Backend should be accessible at:
curl -X POST http://192.168.1.74:8000/process-audio
```

### 3. Test Scenarios
- ✅ Valid audio + valid category → Display results
- ✅ Invalid category → Show validation error
- ✅ Network timeout (>120s) → Show timeout message with retry
- ✅ 400 Bad Request → Show error from backend
- ✅ 500 Server Error → Show retry option
- ✅ Network unavailable → Show connection error

## Configuration for Production

### 1. Move Base URL to Config
Instead of hardcoding the IP address, use environment variables:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.74:8000',
  );
}
```

Build with:
```bash
flutter run --dart-define=API_BASE_URL=https://api.prod.example.com
```

### 2. Add Request Signing (if needed)
```dart
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Authorization'] = 'Bearer $token';
    return handler.next(options);
  },
));
```

### 3. Add Analytics
```dart
_dio.interceptors.add(InterceptorsWrapper(
  onResponse: (response, handler) {
    // Track successful requests
    Analytics.trackEvent('api_request_success', {
      'endpoint': response.requestOptions.path,
      'duration': response.requestOptions.connectTimeout,
    });
    return handler.next(response);
  },
));
```

## Troubleshooting

### Issue: "Invalid category" error
**Cause**: Category string doesn't match exactly (case/spaces matter)
**Solution**: Use exact strings from the list:
```dart
const validCategories = [
  'Medical consultation',  // Note the space
  'Business meeting',      // No extra spaces
  // ... etc
];
```

### Issue: Request timeout (120 seconds)
**Cause**: Backend is slow or network is unreliable
**Solution**: 
- Increase timeout in `ApiService._requestTimeout`
- Check backend logs for slow operations
- Verify network connection quality

### Issue: Multipart encoding errors
**Cause**: Audio file path is invalid
**Solution**:
```dart
// Always verify file exists before uploading
final file = File(audioPath);
if (!await file.exists()) {
  throw ApiException(message: 'Audio file not found');
}
```

### Issue: Can't connect to backend (connection refused)
**Cause**: Backend not running or wrong IP address
**Solution**:
```bash
# Test connectivity
ping 192.168.1.74
curl -X POST http://192.168.1.74:8000/health
```

## Performance Optimization

### 1. Reduce File Size Before Upload
```dart
// Optional: Compress audio before sending
// Use a codec with lower bitrate
```

### 2. Cache Results Locally
The integration already caches results in `SummariesStorage` for offline access.

### 3. Implement Request Deduplication
Track uploaded files to prevent re-uploading the same file:
```dart
final sha256 = calculateHash(file);
final isDuplicate = await checkIfAlreadyProcessed(sha256);
```

## Security Considerations

1. **Network Security**
   - Use HTTPS in production (change http → https)
   - Implement certificate pinning if needed

2. **Data Privacy**
   - Audio files contain sensitive information
   - Consider encrypting before upload
   - Implement proper access controls

3. **API Keys** (if needed)
   - Store in secure storage (not in code)
   - Rotate regularly
   - Use environment variables

## Backend Requirements

The FastAPI backend must:
1. ✅ Accept POST requests to `/process-audio`
2. ✅ Accept multipart/form-data with: `audio`, `category`, `detail`
3. ✅ Validate category against predefined list
4. ✅ Return JSON: `{transcript, summary, translation?, cost}`
5. ✅ Handle long-running requests (30-90 seconds typical)
6. ✅ Set appropriate CORS headers (if needed)

Example FastAPI endpoint:
```python
from fastapi import FastAPI, File, Form, UploadFile

@app.post("/process-audio")
async def process_audio(
    audio: UploadFile = File(...),
    category: str = Form(...),
    detail: Optional[str] = Form(None)
):
    # Validate category
    valid_categories = [
        "Medical consultation",
        "Business meeting",
        # ...
    ]
    
    if category not in valid_categories:
        raise HTTPException(status_code=400, detail="Invalid category")
    
    # Process audio with Whisper, translate, summarize with GPT
    # ...
    
    return {
        "transcript": "...",
        "summary": "...",
        "translation": None,  # Optional
        "cost": 0.15
    }
```

## Monitoring and Debugging

### Enable Detailed Logging
The `ApiService` includes logging for all requests/responses. Check logs via:
```bash
flutter run -v  # Verbose output
# Look for [Dio] log entries
```

### Monitor Processing Times
```dart
final stopwatch = Stopwatch()..start();
final response = await apiService.uploadAudioAndProcess(...);
stopwatch.stop();
print('Total processing time: ${stopwatch.elapsedMilliseconds}ms');
```

### Check Backend Health
```dart
// Add a simple health check endpoint
GET /health → returns {"status": "ok"}
```

## Next Steps

1. ✅ **Dependency installed**: Dio 5.3.0+
2. ✅ **Models created**: API response model
3. ✅ **Service created**: API service with retry/timeout
4. ✅ **UI created**: Result display screen
5. ✅ **Integration complete**: Recordings screen → API → Results

Ready to test with real backend! Just ensure:
- FastAPI server is running at `http://192.168.1.74:8000`
- `/process-audio` endpoint is implemented
- Network connection between Flutter app and backend is available

## Support & Debugging

For issues, check:
1. **Backend logs** - Is the request reaching the server?
2. **Network logs** - Use `flutter logs` to see HTTP requests
3. **Error messages** - API exceptions include detailed user-friendly messages
4. **Response validation** - Ensure backend returns valid JSON schema

---

**Integration completed**: April 15, 2026
**Status**: Ready for testing
