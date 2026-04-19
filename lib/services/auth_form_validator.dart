class AuthFormValidator {
  static const int emailMaxLength = 30;
  static const int passwordMaxLength = 20;

  static final RegExp _emailRegExp = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp _numberRegExp = RegExp(r'\d');

  static String? validateRequiredFields({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return 'All fields are required';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return 'All fields are required';
    }
    if (trimmedValue.length > emailMaxLength) {
      return 'Email must be 30 characters or fewer';
    }
    if (!trimmedValue.contains('@')) {
      return 'Please enter a valid email address';
    }
    if (!_emailRegExp.hasMatch(trimmedValue)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return 'All fields are required';
    }
    if (trimmedValue.length > passwordMaxLength ||
        trimmedValue.length < 8 ||
        !_uppercaseRegExp.hasMatch(trimmedValue) ||
        !_lowercaseRegExp.hasMatch(trimmedValue) ||
        !_numberRegExp.hasMatch(trimmedValue)) {
      return 'Password must be 8-20 characters and include uppercase, lowercase, and number';
    }
    return null;
  }

  static bool hasUppercase(String value) => _uppercaseRegExp.hasMatch(value);

  static bool hasLowercase(String value) => _lowercaseRegExp.hasMatch(value);

  static bool hasNumber(String value) => _numberRegExp.hasMatch(value);
}
