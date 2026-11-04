import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/data/editorial_repository.dart';
import '../../../visa/data/frozen_visa_content.dart';
import '../../data/admin_cms_repository.dart';
import '../../domain/entities/admin_cms_entities.dart';

/// Authenticated employer workspace: frozen-source inventory → matched real
/// research proposals → the EXISTING secured full-page review/CMS draft flow.
/// This screen never edits shipped assets or submits an unbound proposal.
final adminFrozenSourceProposalsProvider =
    FutureProvider.autoDispose<List<AdminSourceChangeProposal>>((ref) async {
      ref.watch(supabaseAuthUserIdProvider);
      return ref.watch(adminCmsRepositoryProvider).listProposals();
    });

class AdminSourceContentPage extends ConsumerStatefulWidget {
  const AdminSourceContentPage({super.key});

  @override
  ConsumerState<AdminSourceContentPage> createState() =>
      _AdminSourceContentPageState();
}

class _AdminSourceContentPageState
    extends ConsumerState<AdminSourceContentPage> {
  final _search = TextEditingController();
  String _country = '';
  String _submittedSearch = '';
  int _page = 0;
  String _activeLocale = '';
  late Future<Map<String, dynamic>> _catalogFuture;
  late Future<List<Map<String, dynamic>>> _countriesFuture;

  void _refreshCatalog() {
    _catalogFuture = frozenVisaContent.reviewCatalog(
      _activeLocale,
      countryCode: _country,
      search: _submittedSearch,
      cursor: '${_page * 24}',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = Localizations.localeOf(context).languageCode == 'fa'
        ? 'fa'
        : 'en';
    if (current != _activeLocale) {
      _activeLocale = current;
      _page = 0;
      _countriesFuture = frozenVisaContent.countries(current);
      _refreshCatalog();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetPage() => setState(() {
    _page = 0;
    _refreshCatalog();
  });

  @override
  Widget build(BuildContext context) {
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final locale = isFa ? 'fa' : 'en';
    final session = ref.watch(supabaseAuthUserIdProvider).valueOrNull;
    if (session == null) {
      // Route auth is a first defense; server role and RLS are authoritative.
      return Scaffold(
        appBar: AppBar(title: Text(isFa ? 'بازبینی منابع' : 'Source Review')),
        body: Center(
          child: Text(
            isFa
                ? 'برای بازبینی، ورود با حساب مدیر لازم است.'
                : 'Sign in with an authorized administrator account.',
          ),
        ),
      );
    }
    final proposals = ref.watch(adminFrozenSourceProposalsProvider);
    final catalog = FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('$locale:$_country:$_submittedSearch:$_page'),
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            isFa
                ? 'فهرست محتوا قابل خواندن نیست. هیچ تغییری اعمال نشد.'
                : 'The source index is unavailable. No changes were made.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: RadLoadingIndicator(label: 'Loading source articles'),
          );
        }
        final rows = (snapshot.data!['items'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final allProposals =
            proposals.valueOrNull ?? const <AdminSourceChangeProposal>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isFa
                  ? '${snapshot.data!['total']} مقالهٔ منبع‌دار در این فهرست'
                  : '${snapshot.data!['total']} source-backed articles',
            ),
            if (rows.isEmpty) Text(isFa ? 'موردی یافت نشد.' : 'No results.'),
            for (final article in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          (article['country_codes'] as List).join(' · '),
                          (article['source_publishers'] as List).join(' · '),
                          article['locale'] as String,
                        ].where((s) => s.isNotEmpty).join(' — '),
                      ),
                      const SizedBox(height: 8),
                      for (final proposal in allProposals.where(
                        (p) => p.targetArticleId == article['id'],
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: OutlinedButton.icon(
                            onPressed:
                                proposal.reviewStatus ==
                                    SourceProposalReviewStatus.pending
                                ? () => context.go(
                                    '/admin/sources/${proposal.id}/review',
                                  )
                                : null,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              proposal.reviewStatus ==
                                      SourceProposalReviewStatus.pending
                                  ? (isFa
                                        ? 'بررسی پیشنهاد پژوهشی در CMS'
                                        : 'Review matching research proposal in CMS')
                                  : (isFa
                                        ? 'این پیشنهاد قبلاً تعیین تکلیف شده است'
                                        : 'This proposal has already been decided'),
                            ),
                          ),
                        ),
                      if (!allProposals.any(
                        (p) => p.targetArticleId == article['id'],
                      ))
                        Text(
                          proposals.hasError
                              ? (isFa
                                    ? 'ارتباط با CMS/پیشنهادها در دسترس نیست. تأیید غیرفعال است.'
                                    : 'CMS proposals unavailable. Approval disabled.')
                              : (isFa
                                    ? 'پیشنهاد متصل به نسخهٔ واقعی CMS موجود نیست؛ تأیید غیرفعال است.'
                                    : 'No live CMS-bound proposal; approval disabled.'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      TextButton.icon(
                        onPressed: () => context.push(
                          editorialCardRoute(article, requestedLocale: locale),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(
                          isFa ? 'خواندن نسخهٔ منبع' : 'Read source snapshot',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _page == 0
                      ? null
                      : () => setState(() {
                          _page--;
                          _refreshCatalog();
                        }),
                  child: Text(isFa ? 'قبلی' : 'Previous'),
                ),
                TextButton(
                  onPressed: snapshot.data!['has_more'] == true
                      ? () => setState(() {
                          _page++;
                          _refreshCatalog();
                        })
                      : null,
                  child: Text(isFa ? 'بعدی' : 'Next'),
                ),
              ],
            ),
          ],
        );
      },
    );
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/admin'),
          title: Text(
            isFa
                ? 'محتوای سه سایت و بازبینی کارفرما'
                : 'Three-Site Source Review',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              isFa
                  ? '۱٬۰۷۷ مقالهٔ فقط‌خواندنی · ۵۶ کشور · ۲۵۱ عنوان مستقل · ۲۳ مورد متوقف'
                  : '1,077 read-only articles · 56 countries · 251 Other Titles · 23 holds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isFa
                  ? 'این متن‌ها کپی منبع هستند، نه نسخهٔ تأییدشدهٔ CMS. دستیار فقط پیشنهاد می‌دهد. تأیید و ساخت Draft با هویت مدیر و از مسیر رسمی سرور انجام می‌شود. انتشار مرحله‌ای جداگانه است.'
                  : 'These source reproductions are not approved CMS revisions. The assistant can propose changes only. An authenticated Admin must approve changes through the server workflow to create a draft; publication is separate.',
            ),
            const SizedBox(height: 12),
            if (proposals.hasValue)
              Text(
                proposals.valueOrNull!.isEmpty
                    ? (isFa
                          ? 'هنوز پیشنهاد پژوهشیِ متصل به CMS وجود ندارد؛ تأیید غیرفعال است.'
                          : 'No live CMS-bound proposals; approval disabled until the CMS has matching revisions.')
                    : (isFa
                          ? '${proposals.valueOrNull!.length} پیشنهاد واقعی CMS قابل بررسی است.'
                          : '${proposals.valueOrNull!.length} live CMS proposals available for review.'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/sources'),
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: Text(
                    isFa ? 'پایش و پیشنهادهای پژوهشی' : 'Source Monitor',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/cms'),
                  icon: const Icon(Icons.article_outlined),
                  label: Text(isFa ? 'نسخه‌های CMS' : 'CMS Articles'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(adminFrozenSourceProposalsProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    isFa ? 'بازخوانی پیشنهادها' : 'Refresh proposals',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: isFa ? 'جست‌وجوی عنوان یا منبع' : 'Search articles',
                suffixIcon: IconButton(
                  onPressed: () {
                    _submittedSearch = _search.text;
                    _resetPage();
                  },
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (value) {
                _submittedSearch = value;
                _resetPage();
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _countriesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return DropdownButtonFormField<String>(
                  key: ValueKey(_country),
                  initialValue: _country,
                  decoration: InputDecoration(
                    labelText: isFa ? 'فیلتر کشور' : 'Country',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(
                        isFa ? 'تمام کشورها و عناوین' : 'All countries',
                      ),
                    ),
                    for (final item in snapshot.data!)
                      DropdownMenuItem(
                        value: item['country_code'] as String,
                        child: Text(item['country_code'] as String),
                      ),
                  ],
                  onChanged: (code) {
                    _country = code ?? '';
                    _resetPage();
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            if (proposals.isLoading)
              Text(
                isFa
                    ? 'در حال دریافت پیشنهادهای واقعی CMS…'
                    : 'Loading real CMS proposals…',
              ),
            if (proposals.hasError)
              Text(
                isFa
                    ? 'دسترسی پژوهشی سرور هنوز برقرار نیست؛ فهرست فقط‌خواندنی قابل بررسی است، اما تأیید انجام نمی‌شود.'
                    : 'Live proposal API unavailable; read-only browsing works, but approvals are blocked.',
              ),
            catalog,
          ],
        ),
      ),
    );
  }
}
