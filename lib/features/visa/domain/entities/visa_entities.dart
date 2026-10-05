class Country {
  final String id;
  final String name;
  final String code;
  final String flagEmoji;
  final String slug;

  const Country({
    required this.id,
    required this.name,
    required this.code,
    required this.flagEmoji,
    required this.slug,
  });
}

class VisaCategory {
  final String id;
  final String name;
  final String description;
  final String slug;

  const VisaCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.slug,
  });
}

class VisaSource {
  const VisaSource({
    required this.title,
    required this.url,
    required this.publisher,
    required this.retrievedAt,
  });
  final String title;
  final String url;
  final String publisher;
  final DateTime retrievedAt;
}

class VisaRequirement {
  const VisaRequirement({
    required this.text,
    required this.displayOrder,
    this.isMandatory,
  });
  final String text;
  final int displayOrder;
  final bool? isMandatory;
}

class VisaStep {
  const VisaStep({
    required this.title,
    required this.description,
    required this.displayOrder,
  });
  final String title;
  final String description;
  final int displayOrder;
}

class VisaProgram {
  final String id;
  final String slug;
  final String title;
  final String countryId;
  final String categoryId;
  final String summary;
  final String? description;
  final List<VisaRequirement> requirements;
  final List<VisaStep> steps;
  final String? processingTime;
  final String? fees;
  final VisaSource source;

  const VisaProgram({
    required this.id,
    required this.slug,
    required this.title,
    required this.countryId,
    required this.categoryId,
    required this.summary,
    required this.source,
    this.description,
    this.requirements = const [],
    this.steps = const [],
    this.processingTime,
    this.fees,
  });
}

class VisaCatalog {
  const VisaCatalog({
    required this.countries,
    required this.categories,
    required this.programs,
  });
  final List<Country> countries;
  final List<VisaCategory> categories;
  final List<VisaProgram> programs;
}
