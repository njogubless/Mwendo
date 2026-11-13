import 'dart:math';

final _random = Random.secure();
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A 20-character random id (the same shape as Firestore auto-ids), for records created on the device.
String newId() => List.generate(20, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
