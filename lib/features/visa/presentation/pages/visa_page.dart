import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/visa_entities.dart';
import '../providers/visa_catalog_provider.dart';

class VisaPage extends ConsumerStatefulWidget {
  const VisaPage({super.key});

  @override
  ConsumerState<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends ConsumerState<VisaPage> {
  String? _countryId;
  String? _categoryId;
  String _query = '';
  VisaProgram? _selected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isFa = locale == 'fa';
    final catalog = ref.watch(visaCatalogProvider(locale));
    if (_selected != null) {
      return catalog.maybeWhen(
        data: (value) => _ProgramDetail(
          program: _selected!,
          country: value.countries.firstWhere(
            (item) => item.id == _selected!.countryId,
          ),
          isFa: isFa,
          onBack: () => setState(() => _selected = null),
        ),
        orElse: () => const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFa ? 'مسیرهای مهاجرت و ویزا' : 'Visa and migration pathways',
        ),
      ),
      body: catalog.when(
        loading: () => LoadingState(
          message: isFa
              ? 'در حال دریافت اطلاعات…'
              : 'Loading verified catalogue…',
        ),
        error: (error, _) => ErrorState(
          message: isFa
              ? 'دریافت اطلاعات ممکن نشد: $error'
              : 'Catalogue unavailable: $error',
          onRetry: () => ref.invalidate(visaCatalogProvider(locale)),
        ),
        data: (value) => _catalog(context, value, isFa),
      ),
    );
  }

  Widget _catalog(BuildContext context, VisaCatalog catalog, bool isFa) {
    final query = _query.trim().toLowerCase();
    final programs = catalog.programs.where((program) {
      return (_countryId == null || program.countryId == _countryId) &&
          (_categoryId == null || program.categoryId == _categoryId) &&
          (query.isEmpty ||
              program.title.toLowerCase().contains(query) ||
              program.summary.toLowerCase().contains(query));
    }).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              isFa ? 'مسیر مناسب را پیدا کنید' : 'Find a relevant pathway',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isFa
                  ? 'فقط محتوای منتشرشده و منبع‌دار نمایش داده می‌شود. شرایط روز را همیشه با مرجع رسمی بررسی کنید.'
                  : 'Only published, sourced RAD content is shown. Always verify current rules with the official authority.',
            ),
            const SizedBox(height: 20),
            SearchBar(
              hintText: isFa ? 'جست‌وجوی کشور یا مسیر' : 'Search programmes',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(isFa ? 'همه کشورها' : 'All destinations'),
                  selected: _countryId == null,
                  onSelected: (_) => setState(() => _countryId = null),
                ),
                ...catalog.countries.map(
                  (country) => FilterChip(
                    label: Text('${country.flagEmoji} ${country.name}'),
                    selected: _countryId == country.id,
                    onSelected: (_) => setState(() => _countryId = country.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(isFa ? 'همه خدمات' : 'All services'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                ...catalog.categories.map(
                  (category) => FilterChip(
                    label: Text(category.name),
                    selected: _categoryId == category.id,
                    onSelected: (_) =>
                        setState(() => _categoryId = category.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (programs.isEmpty)
              EmptyState(
                title: isFa ? 'موردی پیدا نشد' : 'No programme found',
                subtitle: isFa
                    ? 'فیلترها یا عبارت جست‌وجو را تغییر دهید.'
                    : 'Try changing the search or filters.',
                icon: Icons.public_off_outlined,
              ),
            ...programs.map((program) {
              final country = catalog.countries.firstWhere(
                (item) => item.id == program.countryId,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(
                  title: program.title,
                  subtitle:
                      '${country.flagEmoji} ${country.name} · ${program.source.publisher}',
                  icon: Icons.flight_takeoff,
                  onTap: () => setState(() => _selected = program),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProgramDetail extends StatelessWidget {
  const _ProgramDetail({
    required this.program,
    required this.country,
    required this.isFa,
    required this.onBack,
  });

  final VisaProgram program;
  final Country country;
  final bool isFa;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(program.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                '${country.flagEmoji} ${country.name}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(program.summary),
              if (program.description != null) ...[
                const SizedBox(height: 12),
                Text(program.description!),
              ],
              if (program.processingTime != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${isFa ? 'زمان اعلام‌شده' : 'Published timeline'}: '
                  '${program.processingTime}',
                ),
              ],
              if (program.fees != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${isFa ? 'هزینه اعلام‌شده' : 'Published fee'}: '
                  '${program.fees}',
                ),
              ],
              if (program.requirements.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  isFa
                      ? 'مدارک و الزامات منتشرشده'
                      : 'Published requirements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ...program.requirements.map(
                  (item) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryRed,
                    ),
                    title: Text(item.text),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                isFa ? 'منبع' : 'Source',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(program.source.title),
              SelectionArea(
                child: Text(
                  program.source.url,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFa
                    ? 'این اطلاعات تضمین نتیجه نیست و جایگزین بررسی مقررات رسمی یا مشاوره تخصصی نمی‌شود.'
                    : 'This information does not guarantee an outcome and does not replace current official rules or professional review.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
