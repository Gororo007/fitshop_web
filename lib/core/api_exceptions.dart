sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Нет соединения с сервером']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется авторизация']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Доступ запрещён']);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена']);
}

class ConflictException extends ApiException {
  const ConflictException([super.message = 'Конфликт данных']);
}

class ValidationException extends ApiException {
  const ValidationException(this.details, [String message = 'Ошибка валидации'])
    : super(message);

  final Map<String, dynamic> details;
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка сервера']);
}
