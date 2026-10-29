import '../../../../core/theme/premium_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/visa_entities.dart';
import '../../data/visa_repository.dart';
import '../providers/visa_catalog_provider.dart';
import '../../../../core/widgets/reference_widgets.dart';
import '../widgets/country_photography.dart';
import '../widgets/country_visa_content.dart';
import '../../data/editorial_repository.dart';
import 'visa_content_countries_page.dart';

part 'visa_page_countries.dart';
part 'visa_page_country_detail.dart';
part 'visa_page_program.dart';

enum _VisaStage { countries, countryDetail, programDetail }

class VisaPage extends ConsumerStatefulWidget {
  const VisaPage({super.key, this.countryId, this.programId});
  final String? countryId;
  final String? programId;

  @override
  ConsumerState<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends ConsumerState<VisaPage> {
  _VisaStage _stage = _VisaStage.countries;
  Country? _country;
  VisaProgram? _program;
  String _query = '';

  void _openCountry(Country country) {
    if (GoRouter.maybeOf(context) != null) {
      context.go('/visa/${Uri.encodeComponent(country.id)}');
      return;
    }
    setState(() {
      _country = country;
      _program = null;
      _stage = _VisaStage.countryDetail;
    });
  }

  void _openProgram(VisaProgram program) {
    if (GoRouter.maybeOf(context) != null) {
      context.go(
        '/visa/${Uri.encodeComponent(program.countryId)}/programs/${Uri.encodeComponent(program.id)}',
      );
      return;
    }
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
    final publishedContentCountries = ref.watch(
      visaContentCountriesProvider(locale),
    );
    if (widget.countryId == null &&
        (publishedContentCountries.valueOrNull?.isNotEmpty ?? false)) {
      return const VisaContentCountriesPage();
    }
    final catalog = ref.watch(visaCatalogProvider(locale));
    // Routed detail pages derive selection from the catalog instead of requiring
    // a preceding tap. Invalid/stale IDs offer a visible route back to Visa.
    if (widget.countryId != null) {
      final value = catalog.valueOrNull;
      _country = value?.countryById(widget.countryId!);
      _program = null;
      if (widget.programId != null && value != null) {
        for (final program in value.programsForCountry(widget.countryId!)) {
          if (program.id == widget.programId) _program = program;
        }
      }
      _stage = widget.programId != null
          ? _VisaStage.programDetail
          : _VisaStage.countryDetail;
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: locale == 'fa' ? 'دیگر عناوین' : 'Other Titles',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () => context.push('/visa/other-titles'),
          ),
          IconButton(
            tooltip: locale == 'fa'
                ? 'محتوای کامل ویزا'
                : 'Complete Visa content',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/visa/content-countries'),
          ),
        ],
        title: Text(switch (_stage) {
          _VisaStage.countries => l10n.visaPathways,
          _VisaStage.countryDetail => _country?.name ?? l10n.visaPathways,
          _VisaStage.programDetail => _program?.title ?? l10n.visaPathways,
        }),
        automaticallyImplyLeading: false,
        leading: _stage == _VisaStage.countries
            ? null
            : widget.countryId != null
            ? AppBackButton(fallback: '/visa')
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(directionalBack(context)),
                onPressed: _back,
              ),
      ),
      body: PremiumCanvas(
        accent: AppColors.teal,
        child: catalog.when(
          loading: () => LoadingState.section(message: l10n.loadingCatalogue),
          error: (error, _) => ErrorState(
            message: _visaErrorMessage(context, error, l10n),
            onRetry: () => ref.invalidate(visaCatalogProvider(locale)),
          ),
          data: (value) =>
              widget.countryId != null &&
                  (_country == null ||
                      (widget.programId != null && _program == null))
              ? EmptyState(
                  title: l10n.catalogueUnavailable,
                  actionLabel: l10n.visaPathways,
                  onAction: () => context.go('/visa'),
                )
              : value.countries.isEmpty
              ? EmptyState(
                  icon: Icons.public_off_outlined,
                  title: AppLocalizations.of(context).noPublishedDestinations,
                  subtitle: AppLocalizations.of(context)
                      .publishedDestinationsEmpty,
                )
              : switch (_stage) {
                  _VisaStage.countries => _CountriesStage(
                    catalog: value,
                    l10n: l10n,
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
      VisaCatalogFailureKind.configuration => AppLocalizations.of(
        context,
      ).visaConfigurationUnavailable,
      VisaCatalogFailureKind.access => AppLocalizations.of(
        context,
      ).visaContentAccessFailed,
      VisaCatalogFailureKind.network => AppLocalizations.of(
        context,
      ).visaConnectionFailed,
      VisaCatalogFailureKind.data => AppLocalizations.of(
        context,
      ).visaContentIncomplete,
      _ => l10n.catalogueUnavailable,
    };
  }
}
