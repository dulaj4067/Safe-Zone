import '../models/shelter.dart';
import 'supabase_service.dart';

class ShelterService {
  Future<List<Shelter>> fetchShelters() async {
    final rows = await SupabaseService.client.from('shelters').select();
    return (rows as List)
        .map((row) => Shelter.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}