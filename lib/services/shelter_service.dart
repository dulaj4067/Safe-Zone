import '../models/shelter.dart';
import 'supabase_service.dart';

class ShelterService {
  Future<List<Shelter>> fetchShelters() async {
    final rows = await SupabaseService.client.from('shelters').select();
    return (rows as List)
        .map((row) => Shelter.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Name of the person / organisation in `shelters.managed_by`, looked up
  /// in `profiles`. Returns null when the shelter has no manager or the
  /// profile can't be read — the detail sheet simply hides that row.
  Future<String?> fetchManagerName(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return null;
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', profileId)
          .maybeSingle();
      final name = row?['full_name'] as String?;
      return (name == null || name.trim().isEmpty) ? null : name;
    } catch (_) {
      return null;
    }
  }
}
