class Validator {

  static String? validateEmail(String email) {

    if (email.isEmpty) {
      return "Enter email";
    }

    final regex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );

    if (!regex.hasMatch(email)) {
      return "Invalid email";
    }

    return null;

  }

  static String? validatePassword(String password) {

    if (password.length < 8) {
      return "At least 8 characters required";
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return "Uppercase letter required";
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return "Lowercase letter required";
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return "Number required";
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]')
        .hasMatch(password)) {
      return "Special character required";
    }

    return null;

  }

}
