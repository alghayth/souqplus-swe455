import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF6FB8E6);
const kPrimaryLightColor = Color(0xFFF2E199);
const kPrimaryGradientColor = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFA53E), Color(0xFF1B3A68)],
);
const kSecondaryColor = Color.fromARGB(255, 27, 58, 104);
const kTextColor = Color.fromARGB(255, 27, 58, 104);

const kAnimationDuration = Duration(milliseconds: 200);

const headingStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: kPrimaryColor,
  height: 1.5,
);

const defaultDuration = Duration(milliseconds: 250);

// Form Error
final RegExp emailValidatorRegExp =
    RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");

    final RegExp saudiPhoneRegExp =
    RegExp(r'^(?:\+966|966|0)?5\d{8}$');

    const String kNamelNullError = "Please Enter your name";
    

/*const String kEmailNullError = "Please Enter your email";
const String kInvalidEmailError = "Please Enter Valid Email";
const String kPassNullError = "Please Enter your password";
const String kShortPassError = "Password is too short";
const String kMatchPassError = "Passwords don't match";
const String kNamelNullError = "Please Enter your name";
const String kPhoneNumberNullError = "Please Enter your phone number";
const String kAddressNullError = "Please Enter your address";
const String kShortAddressError = "Address is too short";*/

// First Name
const String kFirstNameNullError = "Please enter your first name";
const String kShortFirstNameError = "First name must be at least 2 characters";
const String kLongFirstNameError = "First name cannot exceed 30 characters";


// Last Name
const String kLastNameNullError = "Please enter your last name";
const String kShortLastNameError = "Last name must be at least 2 characters";
const String kLongLastNameError = "Last name cannot exceed 30 characters";

// Email
const String kEmailNullError = "Please enter your email";
const String kInvalidEmailError = "Please enter a valid email address";
const String kEmailTooLongError = "Email must be 20 characters or fewer";

// Phone
const String kPhoneNumberNullError = "Please enter your phone number";
const String kInvalidPhoneNumberError = "Please enter a valid phone number";

// Password
const String kPassNullError = "Please enter your password";
const String kShortPassError = "Password must be at least 8 characters";
const String kLongPassError = "Password must be 20 characters or fewer";
const String kPasswordMustContainUppercase =
    "Password must contain at least one uppercase letter";
const String kPasswordMustContainLowercase =
    "Password must contain at least one lowercase letter";
const String kPasswordMustContainNumber =
    "Password must contain at least one number";
const String kPasswordMustContainSpecialCharacter =
    "Password must contain at least one special character";
const String kPasswordMustContainLetter =
    "Password must contain at least one letter";
const String kMatchPassError = "Passwords don't match";

// Address
const String kAddressNullError = "Please enter your City";
const String kShortAddressError =
    "City must be at least 3 characters";


final otpInputDecoration = InputDecoration(
  contentPadding: const EdgeInsets.symmetric(vertical: 16),
  border: outlineInputBorder(),
  focusedBorder: outlineInputBorder(),
  enabledBorder: outlineInputBorder(),
);

OutlineInputBorder outlineInputBorder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: kTextColor),
  );
}
