import 'dart:convert';

import 'package:flutter/services.dart';

class AuthorizationRight {
  final int id;
  final String module;
  final String right;
  const AuthorizationRight({required this.id, required this.module, required this.right});

  factory AuthorizationRight.fromMap(Map<String, dynamic> map) {
    return AuthorizationRight(id: map['id'] as int, module: map['module'] as String, right: map['right'] as String);
  }

  Map<String, dynamic> toMap() => {'id': id, 'module': module, 'right': right};
}

List<AuthorizationRight>? _cache;

/// Loads the same 673-row ERP rights catalog bundled as
/// src/data/erpAuthorizationRights.json on the website, so the ERP access
/// picker in IT Request Form (Application) offers identical options.
Future<List<AuthorizationRight>> loadAuthorizationRights() async {
  if (_cache != null) return _cache!;
  final raw = await rootBundle.loadString('assets/data/erpAuthorizationRights.json');
  final decoded = jsonDecode(raw) as List;
  _cache = decoded.map((e) => AuthorizationRight.fromMap(e as Map<String, dynamic>)).toList();
  return _cache!;
}
