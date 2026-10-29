import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../platform/browser.dart';
import 'onboarding_models.dart';

/// Holds onboarding drafts in this browser tab (`sessionStorage`), so a page
/// refresh or a switch to the pharmacist account keeps them.
///
/// Swap for an API-backed store once the backend has patient-create endpoints.
class OnboardingStore extends ChangeNotifier {
  OnboardingStore({this.persist = true}) {
    if (persist) _load();
  }

  static const _key = 'aimesis.web.onboarding';

  /// False in tests, so drafts don't leak between them.
  final bool persist;
  final Map<String, OnboardingDraft> _drafts = {};

  List<OnboardingDraft> get drafts =>
      _drafts.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  List<OnboardingDraft> get inProgress => drafts.where((d) => !d.isSent).toList();
  List<OnboardingDraft> get sent => drafts.where((d) => d.isSent).toList();

  OnboardingDraft? byId(String id) => _drafts[id];

  OnboardingDraft create({required String createdBy}) {
    final now = DateTime.now();
    final id = 'NEW-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final d = OnboardingDraft(id: id, createdAt: now, createdBy: createdBy);
    _drafts[id] = d;
    _changed();
    return d;
  }

  void save(OnboardingDraft d) {
    d.updatedAt = DateTime.now();
    _drafts[d.id] = d;
    _changed();
  }

  void remove(String id) {
    if (_drafts.remove(id) != null) _changed();
  }

  void _changed() {
    if (persist) {
      storageSet(_key, jsonEncode([for (final d in _drafts.values) d.toJson()]));
    }
    notifyListeners();
  }

  void _load() {
    final raw = storageGet(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      for (final j in jsonDecode(raw) as List) {
        final d = OnboardingDraft.fromJson(Map<String, dynamic>.from(j as Map));
        _drafts[d.id] = d;
      }
    } catch (_) {
      // Unreadable (older format): start clean rather than fail the app.
      _drafts.clear();
      storageRemove(_key);
    }
  }
}
