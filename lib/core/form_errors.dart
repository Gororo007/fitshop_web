import 'api_exceptions.dart';

/// Extracts PocketBase per-field errors (`data.<field>.message`) from a
/// [ValidationException] so forms can display them under the inputs.
Map<String, String> fieldErrorsOf(ValidationException e) {
  final result = <String, String>{};
  final data = e.details['data'];
  if (data is Map) {
    data.forEach((key, value) {
      if (value is Map && value['message'] is String) {
        result['$key'] = value['message'] as String;
      }
    });
  }
  return result;
}
