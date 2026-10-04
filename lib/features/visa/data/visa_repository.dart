import '../../../core/supabase/supabase_client.dart';
import '../domain/entities/visa_entities.dart';

class VisaRepository {
  const VisaRepository(this._service);
  final SupabaseClientService _service;

  Future<VisaCatalog> loadCatalog({required String locale}) async {
    if (!_service.isInitialized) {
      throw StateError('Supabase is not configured for this build.');
    }
    final language = locale == 'fa' ? 'fa' : 'en';
    final results = await Future.wait([
      _service.client
          .from('destinations')
          .select(
            'id,code,slug,flag_emoji,destination_localizations!inner(name,summary,locale)',
          )
          .eq('destination_localizations.locale', language)
          .order('display_order'),
      _service.client
          .from('program_categories')
          .select(
            'id,slug,program_category_localizations!inner(name,description,locale)',
          )
          .eq('program_category_localizations.locale', language)
          .order('display_order'),
      _service.client
          .from('visa_programs')
          .select(
            'id,slug,destination_id,category_id,processing_time_text,fees_text,'
            'visa_program_localizations!inner(title,summary,description,locale),'
            'visa_program_requirements(requirement,is_mandatory,display_order,locale),'
            'visa_program_steps(title,description,display_order,locale),'
            'content_sources!visa_programs_primary_source_id_fkey(title,url,publisher,retrieved_at)',
          )
          .eq('visa_program_localizations.locale', language)
          .eq('visa_program_requirements.locale', language)
          .order('published_at', ascending: false),
    ]);

    return VisaCatalog(
      countries: (results[0] as List<dynamic>)
          .map((row) => _country(row as Map<String, dynamic>))
          .toList(growable: false),
      categories: (results[1] as List<dynamic>)
          .map((row) => _category(row as Map<String, dynamic>))
          .toList(growable: false),
      programs: (results[2] as List<dynamic>)
          .map((row) => _program(row as Map<String, dynamic>, language))
          .toList(growable: false),
    );
  }

  Country _country(Map<String, dynamic> row) {
    final localized = _first(row['destination_localizations']);
    return Country(
      id: row['id'] as String,
      code: row['code'] as String,
      slug: row['slug'] as String,
      flagEmoji: row['flag_emoji'] as String? ?? '🌐',
      name: localized['name'] as String,
    );
  }

  VisaCategory _category(Map<String, dynamic> row) {
    final localized = _first(row['program_category_localizations']);
    return VisaCategory(
      id: row['id'] as String,
      slug: row['slug'] as String,
      name: localized['name'] as String,
      description: localized['description'] as String? ?? '',
    );
  }

  VisaProgram _program(Map<String, dynamic> row, String language) {
    final localized = _first(row['visa_program_localizations']);
    final source = row['content_sources'] as Map<String, dynamic>;
    final requirements =
        ((row['visa_program_requirements'] as List<dynamic>?) ?? const [])
            .where((item) => (item as Map<String, dynamic>)['locale'] == language)
            .map((item) {
              final value = item as Map<String, dynamic>;
              return VisaRequirement(
                text: value['requirement'] as String,
                displayOrder: value['display_order'] as int? ?? 0,
                isMandatory: value['is_mandatory'] as bool?,
              );
            })
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final steps = ((row['visa_program_steps'] as List<dynamic>?) ?? const [])
        .where((item) => (item as Map<String, dynamic>)['locale'] == language)
        .map((item) {
          final value = item as Map<String, dynamic>;
          return VisaStep(
            title: value['title'] as String,
            description: value['description'] as String? ?? '',
            displayOrder: value['display_order'] as int? ?? 0,
          );
        })
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return VisaProgram(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: localized['title'] as String,
      summary: localized['summary'] as String,
      description: localized['description'] as String?,
      countryId: row['destination_id'] as String,
      categoryId: row['category_id'] as String,
      processingTime: row['processing_time_text'] as String?,
      fees: row['fees_text'] as String?,
      requirements: requirements,
      steps: steps,
      source: VisaSource(
        title: source['title'] as String,
        url: source['url'] as String,
        publisher: source['publisher'] as String,
        retrievedAt: DateTime.parse(source['retrieved_at'].toString()),
      ),
    );
  }

  Map<String, dynamic> _first(dynamic value) {
    final rows = value as List<dynamic>?;
    if (rows == null || rows.isEmpty) {
      throw const FormatException('Missing localized catalogue content.');
    }
    return rows.first as Map<String, dynamic>;
  }
}
