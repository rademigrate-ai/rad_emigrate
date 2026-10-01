class Country {
  final String id;
  final String name;
  final String code;
  final String flagEmoji;

  const Country({
    required this.id,
    required this.name,
    required this.code,
    required this.flagEmoji,
  });
}

class VisaCategory {
  final String id;
  final String name;
  final String description;

  const VisaCategory({
    required this.id,
    required this.name,
    required this.description,
  });
}

class VisaProgram {
  final String id;
  final String title;
  final String countryId;
  final String categoryId;
  final String summary;
  final List<String> requirements;
  final String? processingTime;

  const VisaProgram({
    required this.id,
    required this.title,
    required this.countryId,
    required this.categoryId,
    required this.summary,
    this.requirements = const [],
    this.processingTime,
  });
}
