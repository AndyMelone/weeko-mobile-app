// Config injectée au build : `flutter run --dart-define-from-file=.env.json`.
// Émulateur Android : API_URL = http://10.0.2.2:3000/api.

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');
const apiKey = String.fromEnvironment('API_KEY');
