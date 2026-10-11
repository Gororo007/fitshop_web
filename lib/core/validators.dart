class Validators {
  Validators._();

  static String? requiredField(String? value, {String label = 'Поле'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label обязательно';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email обязателен';
    }
    final pattern = RegExp(r'^[\w.\+-]+@[\w.-]+\.[a-zA-Z]{2,}$');
    if (!pattern.hasMatch(value.trim())) {
      return 'Некорректный email';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Пароль обязателен';
    }
    if (value.length < minLength) {
      return 'Минимум $minLength символов';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Пароль должен содержать цифру';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(value)) {
      return 'Пароль должен содержать спецсимвол';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Телефон обязателен';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Некорректный телефон';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String label = 'Значение'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label обязательно';
    }
    final n = num.tryParse(value.replaceAll(',', '.'));
    if (n == null || n <= 0) {
      return '$label должно быть больше 0';
    }
    return null;
  }

  static String? nonNegativeNumber(String? value, {String label = 'Значение'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label обязательно';
    }
    final n = num.tryParse(value.replaceAll(',', '.'));
    if (n == null || n < 0) {
      return '$label не может быть отрицательным';
    }
    return null;
  }

  static String? rating(String? value) {
    final err = nonNegativeNumber(value, label: 'Оценка');
    if (err != null) return err;
    final n = num.parse(value!.replaceAll(',', '.'));
    if (n < 1 || n > 5) {
      return 'Оценка от 1 до 5';
    }
    return null;
  }
}
