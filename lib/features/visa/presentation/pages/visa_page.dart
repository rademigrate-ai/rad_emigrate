import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/visa_entities.dart';
import '../../data/visa_repository.dart';
import '../providers/visa_catalog_provider.dart';
import '../widgets/country_carousel.dart';
import '../widgets/country_photography.dart';

part 'visa_page_countries.dart';
part 'visa_page_country_detail.dart';
part 'visa_page_program.dart';

String _t(BuildContext context, String en, String fa) {
  return Localizations.localeOf(context).languageCode == 'fa' ? fa : en;
}

enum _VisaStage { countries, countryDetail, programDetail }

class VisaPage extends ConsumerStatefulWidget {
  const VisaPage({super.key});

  @override
  ConsumerState<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends ConsumerState<VisaPage> {
  _VisaStage _stage = _VisaStage.countries;
  Country? _country;
  VisaProgram? _program;
  String _query = '';
  var _showSearch = false;

  void _openCountry(Country country) {
    setState(() {
      _country = country;
      _program = null;
      _stage = _VisaStage.countryDetail;
      _showSearch = false;
    });
  }

  void _openProgram(VisaProgram program) {
    setState(() {
      _program = program;
      _stage = _VisaStage.programDetail;
    });
  }

  void _back() {
    setState(() {
      if (_stage == _VisaStage.programDetail) {
        _program = null;
        _stage = _VisaStage.countryDetail;
      } else if (_stage == _VisaStage.countryDetail) {
        _country = null;
        _stage = _VisaStage.countries;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(visaCatalogProvider(locale));

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_stage) {
          _VisaStage.countries => l10n.visaPathways,
          _VisaStage.countryDetail => _country?.name ?? l10n.visaPathways,
          _VisaStage.programDetail => _program?.title ?? l10n.visaPathways,
        }),
        leading: _stage == _VisaStage.countries
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(directionalBack(context)),
                onPressed: _back,
              ),
        actions: [
          if (_stage == _VisaStage.countries)
            IconButton(
              tooltip: l10n.searchProgrammes,
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: () => setState(() => _showSearch = !_showSearch),
            ),
        ],
      ),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: catalog.when(
          loading: () => LoadingState.section(message: l10n.loadingCatalogue),
          error: (error, _) => ErrorState(
            message: _visaErrorMessage(context, error, l10n),
            onRetry: () => ref.invalidate(visaCatalogProvider(locale)),
          ),
          data: (value) => value.countries.isEmpty
              ? EmptyState(
                  icon: Icons.public_off_outlined,
                  title: _t(
                    context,
                    'No published destinations',
                    'هنوز مقصد منتشرشده‌ای وجود ندارد',
                  ),
                  subtitle: _t(
                    context,
                    'Published visa destinations will appear here.',
                    'مقصدهای منتشرشده ویزا در این بخش نمایش داده می‌شوند.',
                  ),
                )
              : switch (_stage) {
                  _VisaStage.countries => _CountriesStage(
                    catalog: value,
                    l10n: l10n,
                    showSearch: _showSearch,
                    query: _query,
                    onQuery: (q) => setState(() => _query = q),
                    onSelect: _openCountry,
                  ),
                  _VisaStage.countryDetail => _CountryDetailStage(
                    catalog: value,
                    country: _country!,
                    l10n: l10n,
                    onSelectProgram: _openProgram,
                  ),
                  _VisaStage.programDetail => _ProgramDetailStage(
                    catalog: value,
                    country: _country!,
                    program: _program!,
                    l10n: l10n,
                  ),
                },
        ),
      ),
    );
  }

  String _visaErrorMessage(
    BuildContext context,
    Object error,
    AppLocalizations l10n,
  ) {
    final kind = error is VisaCatalogException ? error.kind : null;
    return switch (kind) {
      VisaCatalogFailureKind.configuration => _t(
        context,
        'Visa discovery is unavailable in this build configuration.',
        'بخش ویزا در پیکربندی فعلی برنامه در دسترس نیست.',
      ),
      VisaCatalogFailureKind.access => _t(
        context,
        'Published visa content could not be accessed. Please retry.',
        'دسترسی به محتوای منتشرشده ویزا ممکن نشد. دوباره تلاش کنید.',
      ),
      VisaCatalogFailureKind.network => _t(
        context,
        'Check your connection and retry visa discovery.',
        'اتصال اینترنت را بررسی و دوباره تلاش کنید.',
      ),
      VisaCatalogFailureKind.data => _t(
        context,
        'Published visa content is incomplete. Please try again later.',
        'محتوای منتشرشده ویزا کامل نیست. بعداً دوباره تلاش کنید.',
      ),
      _ => l10n.catalogueUnavailable,
    };
  }
}
