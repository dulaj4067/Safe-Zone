import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, PostgrestException;

import 'supabase_service.dart';

/// Status of the signed-in user's account-deletion request.
enum DeletionStatus { none, received, processing, completed, cancelled }

class DeletionRequest {
  final DeletionStatus status;
  final DateTime? requestedAt;
  const DeletionRequest(this.status, this.requestedAt);

  bool get isOpen => status == DeletionStatus.received || status == DeletionStatus.processing;

  static DeletionRequest fromRow(Map<String, dynamic>? row) {
    if (row == null) return const DeletionRequest(DeletionStatus.none, null);
    final status = DeletionStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => DeletionStatus.received,
    );
    return DeletionRequest(
      status,
      DateTime.tryParse(row['requested_at'] as String? ?? '')?.toLocal(),
    );
  }
}

/// Account/data deletion requests via the `request_account_deletion` /
/// `cancel_account_deletion` RPCs (sql/privacy_consent_onboarding_migration.sql).
///
/// The app only ever reports what the server confirmed: a request is
/// "received" once the row exists; it is "completed" only when the operator
/// has actually deleted the data.
class AccountDeletionService {
  Future<DeletionRequest> current() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return const DeletionRequest(DeletionStatus.none, null);
    final row = await SupabaseService.client
        .from('account_deletion_requests')
        .select('status, requested_at')
        .eq('user_id', uid)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return DeletionRequest.fromRow(row);
  }

  /// Idempotent: a second call returns the already-open request.
  Future<DeletionRequest> request({String? reason}) async {
    try {
      final row = await SupabaseService.client
          .rpc('request_account_deletion', params: {'reason': reason})
          .single();
      return DeletionRequest.fromRow(row);
    } on PostgrestException catch (e) {
      throw DeletionException(_friendly(e));
    }
  }

  Future<void> cancel() async {
    try {
      await SupabaseService.client.rpc('cancel_account_deletion');
    } on PostgrestException catch (e) {
      throw DeletionException(_friendly(e));
    }
  }

  // ─── Authority side ───────────────────────────────────────────────────────

  /// Open requests with the requester's name (authorities only, via RLS).
  Future<List<OpenDeletionRequest>> listOpen() async {
    final rows = await SupabaseService.client
        .from('open_deletion_requests')
        .select()
        .order('requested_at');
    return [
      for (final r in rows as List) OpenDeletionRequest.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Deletes the account behind [requestId] via the process-account-deletion
  /// Edge Function. Returns only once the server reports it completed.
  Future<void> process(String requestId) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'process-account-deletion',
        body: {'request_id': requestId},
      );
      final data = res.data;
      if (data is! Map || data['status'] != 'completed') {
        throw DeletionException('The server didn’t confirm the deletion.');
      }
    } on FunctionException catch (e) {
      final details = e.details;
      throw DeletionException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Deletion failed (${e.status}). It can be retried safely.',
      );
    }
  }

  static String _friendly(PostgrestException e) {
    // Missing function = the migration hasn't been applied on this backend.
    if (e.code == 'PGRST202' || e.code == '42883') {
      return 'Account deletion isn\'t available on this server yet. '
          'Please contact the operator through Give feedback in Settings.';
    }
    return e.message;
  }
}

class OpenDeletionRequest {
  final String id;
  final String? userId;
  final String name;
  final DeletionStatus status;
  final String? reason;
  final DateTime? requestedAt;

  const OpenDeletionRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.status,
    this.reason,
    this.requestedAt,
  });

  factory OpenDeletionRequest.fromRow(Map<String, dynamic> r) => OpenDeletionRequest(
    id: r['id'] as String,
    userId: r['user_id'] as String?,
    name: (r['full_name'] as String?)?.trim().isNotEmpty == true
        ? r['full_name'] as String
        : 'Unnamed account',
    status: DeletionRequest.fromRow(r).status,
    reason: r['reason'] as String?,
    requestedAt: DateTime.tryParse(r['requested_at'] as String? ?? '')?.toLocal(),
  );
}

class DeletionException implements Exception {
  final String message;
  DeletionException(this.message);
  @override
  String toString() => message;
}
