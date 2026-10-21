import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../../visa/data/canonical_pathway_repository.dart';
import '../../../visa/domain/entities/canonical_pathway_entities.dart';
import '../../../visa/domain/entities/search_entities.dart';
import '../../data/admin_cms_repository.dart';

class AdminCmsCanonicalEditorPage extends ConsumerStatefulWidget {
  final String articleId;

  const AdminCmsCanonicalEditorPage({super.key, required this.articleId});

  @override
  ConsumerState<AdminCmsCanonicalEditorPage> createState() =>
      _AdminCmsCanonicalEditorPageState();
}

class _AdminCmsCanonicalEditorPageState
    extends ConsumerState<AdminCmsCanonicalEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  FactualStatus _factualStatus = FactualStatus.verified;
  ArticleEditorialStatus _editorialStatus = ArticleEditorialStatus.published;
  bool _isLoading = false;
  CanonicalPathwayArticle? _loadedArticle;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _summaryController = TextEditingController();
    _loadArticle();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    setState(() => _isLoading = true);
    // Load article from repository
    final repo = ref.read(canonicalPathwayRepositoryProvider);
    final article = await repo.getCanonicalPathway(
      countryCode: 'de',
      pathwaySlug: 'chancenkarte',
    );
    if (mounted && article != null) {
      setState(() {
        _loadedArticle = article;
        _titleController.text = article.pathwayTitle;
        _summaryController.text = article.summary;
        _factualStatus = article.factualStatus;
        _editorialStatus = article.editorialStatus;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _loadedArticle == null) return;
    setState(() => _isLoading = true);

    final updated = CanonicalPathwayArticle(
      id: _loadedArticle!.id,
      slug: _loadedArticle!.slug,
      countryCode: _loadedArticle!.countryCode,
      countryName: _loadedArticle!.countryName,
      countryFlag: _loadedArticle!.countryFlag,
      pathwayTitle: _titleController.text.trim(),
      category: _loadedArticle!.category,
      factualStatus: _factualStatus,
      editorialStatus: _editorialStatus,
      summary: _summaryController.text.trim(),
      officialSources: _loadedArticle!.officialSources,
      sections: _loadedArticle!.sections,
      eligibility: _loadedArticle!.eligibility,
      costs: _loadedArticle!.costs,
      steps: _loadedArticle!.steps,
      requiredDocuments: _loadedArticle!.requiredDocuments,
      faqItems: _loadedArticle!.faqItems,
      relatedArticles: _loadedArticle!.relatedArticles,
      lastFactCheckedAt: _loadedArticle!.lastFactCheckedAt,
    );

    final cmsRepo = ref.read(adminCmsRepositoryProvider);
    final ok = await cmsRepo.saveCanonicalArticle(updated);

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تغییرات مقاله با موفقیت ذخیره شد.')),
        );
        context.go('/admin/cms');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin/cms'),
        title: const Text('ویرایش مقاله مسیر تجمیعی'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: const Icon(Icons.check, size: 16),
            label: const Text(
              'ذخیره و انتشار',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: RadPending())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Metadata card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مشخصات عمومی و عنوان',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان فارسی مسیر مهاجرتی',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'عنوان الزامی است'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _summaryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'خلاصه اجرایی مقاله',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'خلاصه الزامی است'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Decoupled Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تفکیک وضعیت انطباق حقیقت و چرخه حیات انتشار',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'وضعیت حقیقت (انطباق با منابع رسمی دولتی) مستقل از تأیید یا انتشار سردبیری نگهداری می‌شود.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Factual status dropdown
                        DropdownButtonFormField<FactualStatus>(
                          initialValue: _factualStatus,
                          decoration: const InputDecoration(
                            labelText: 'وضعیت حقیقت علمی/رسمی (Factual Status)',
                            border: OutlineInputBorder(),
                          ),
                          items: FactualStatus.values.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.toDisplayPersian()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _factualStatus = v);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Editorial status dropdown
                        DropdownButtonFormField<ArticleEditorialStatus>(
                          initialValue: _editorialStatus,
                          decoration: const InputDecoration(
                            labelText: 'چرخه انتشار سردبیری (Editorial Status)',
                            border: OutlineInputBorder(),
                          ),
                          items: ArticleEditorialStatus.values.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s.toDisplayPersian()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _editorialStatus = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Official Sources Card
                  if (_loadedArticle != null &&
                      _loadedArticle!.officialSources.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.verified_outlined,
                                color: AppColors.success,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'منابع رسمی متصل به این مقاله',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ..._loadedArticle!.officialSources.map((src) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.public,
                                color: AppColors.teal,
                              ),
                              title: Text(
                                src.authorityName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                src.originalEvidenceUrl,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
