import '../domain/entities/visa_entities.dart';

const mockCountries = [
  Country(id: 'ca', name: 'Canada', code: 'CA', flagEmoji: '🇨🇦'),
  Country(id: 'au', name: 'Australia', code: 'AU', flagEmoji: '🇦🇺'),
  Country(id: 'de', name: 'Germany', code: 'DE', flagEmoji: '🇩🇪'),
  Country(id: 'tr', name: 'Turkey', code: 'TR', flagEmoji: '🇹🇷'),
  Country(id: 'gb', name: 'United Kingdom', code: 'GB', flagEmoji: '🇬🇧'),
];

const mockCategories = [
  VisaCategory(id: 'study', name: 'Study', description: 'Student visas and study permits'),
  VisaCategory(id: 'work', name: 'Work', description: 'Work permits and skilled worker programs'),
  VisaCategory(id: 'visit', name: 'Visit', description: 'Tourist and visitor visas'),
  VisaCategory(id: 'immigrate', name: 'Immigrate', description: 'Permanent residence pathways'),
];

const mockPrograms = [
  VisaProgram(
    id: 'ca-study',
    title: 'Canada Study Permit',
    countryId: 'ca',
    categoryId: 'study',
    summary: 'Study at a designated learning institution in Canada.',
    requirements: ['Letter of acceptance', 'Proof of funds', 'Language test', 'Valid passport'],
    processingTime: '4–12 weeks',
  ),
  VisaProgram(
    id: 'ca-express',
    title: 'Express Entry',
    countryId: 'ca',
    categoryId: 'immigrate',
    summary: 'Federal skilled worker permanent residence pathway.',
    requirements: ['Language results', 'Education assessment', 'Work experience', 'Proof of funds'],
    processingTime: '6 months',
  ),
  VisaProgram(
    id: 'au-student',
    title: 'Australia Student Visa (500)',
    countryId: 'au',
    categoryId: 'study',
    summary: 'Study full-time in Australia.',
    requirements: ['Confirmation of Enrolment', 'GTE statement', 'OSHC', 'Financial capacity'],
    processingTime: '4–8 weeks',
  ),
  VisaProgram(
    id: 'de-jobseeker',
    title: 'Germany Job Seeker Visa',
    countryId: 'de',
    categoryId: 'work',
    summary: 'Search for employment in Germany for up to 6 months.',
    requirements: ['University degree', 'Proof of funds', 'Health insurance', 'CV'],
    processingTime: '4–12 weeks',
  ),
];
