import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }
}