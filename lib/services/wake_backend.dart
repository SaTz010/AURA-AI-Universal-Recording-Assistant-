import 'package:http/http.dart' as http;

Future<void> wakeBackend() async {
  try {
    await http.get(Uri.parse('https://backendforaura.onrender.com/wake'));
  } catch (_) {
    // ignore
  }
}
