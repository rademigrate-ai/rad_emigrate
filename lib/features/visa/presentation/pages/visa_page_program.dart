part of 'visa_page.dart';

class _ProgramDetailStage extends StatelessWidget {
  const _ProgramDetailStage({
    required this.catalog,
    required this.country,
    required this.program,
    required this.l10n,
  });

  final VisaCatalog catalog;
  final Country country;
  final VisaProgram program;
  final AppLocalizations l10n;

  void _openAi(BuildContext context) {
    final ctx = '${program.title} · ${country.name}';
    context.push(
      '/ai-assistant?context=${Uri.encodeComponent(ctx)}',
    );
  }

  void _openConsultation(BuildContext context) {
    final topic = '${program.title} · ${country.name}';
    context.push(
      '/consultation?topic=${Uri.encodeComponent(topic)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        isRtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        program.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  country.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (program.summary != null &&
                    program.summary!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    program.summary!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openConsultation(context),
                      icon: const Icon(Icons.support_agent_outlined),
                      label: Text(l10n.requestConsultation),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openAi(context),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(l10n.askAiAssistant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
       .SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _ProgramAccordions(
              program: program,
              l10n: l10n,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgramAccordions extends StatefulWidget {
  const _ProgramAccordions({
    required this.program,
    required this.l10n,
  });

  final VisaProgram program;
  final AppLocalizations l10n;

  @override
  State<_ProgramAccordions> createState() => _ProgramAccordionsState();
}

class _ProgramAccordionsState extends State<_ProgramAccordions> {
  late final List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    final n = _sections.length;
    _expanded = List<bool>.generate(n, (i) => i == 0);
  }

  List<({String title, String? body})> get _sections {
    final p = widget.program;
    final l10n = widget.l10n;
    return [
      (title: l10n.eligibility, body: p.eligibility),
      (title: l10n.requiredDocuments, body: p.requiredDocuments),
      (title: l10n.processingTime, body: p.processingTime),
      (title: l10n.fees, body: p.fees),
      (title: l10n.notes, body: p.notes),
    ]
        .where((s) => s.body != null && s.body!.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (var i = 0; i < sections.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              initiallyExpanded: _expanded[i],
              onExpansionChanged: (v) => setState(() => _expanded[i] = v),
              title: Text(
                sections[i].title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(sections[i].body!),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
