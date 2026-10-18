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
    context.go('/ai-assistant?context=${Uri.encodeComponent(ctx)}');
  }

  void _openConsultation(BuildContext context) {
    context.go('/consultation?topic=${Uri.encodeComponent(program.title)}');
  }

  @override
  Widget build(BuildContext context) {
    final category = catalog.categoryById(program.categoryId);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final hasDescription = (program.description ?? '').trim().isNotEmpty;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      country.name,
                      if (category != null) category.name,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (program.summary.trim().isNotEmpty)
          Text(program.summary, style: Theme.of(context).textTheme.bodyLarge),
        if (program.requirements.isEmpty && program.steps.isEmpty) ...[
          const SizedBox(height: 22),
          EmptyState(
            title: l10n.structuredDetailsPending,
            subtitle: l10n.structuredDetailsPendingBody,
            icon: Icons.fact_check_outlined,
          ),
        ],
        const SizedBox(height: 12),
        _ProgramAccordions(
          description: hasDescription ? program.description!.trim() : null,
          requirements: program.requirements,
          steps: program.steps,
          processingTime: program.processingTime,
          fees: program.fees,
          source: program.source,
          l10n: l10n,
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 24),
          AppButton(
            label: AppLocalizations.of(context).bookConsultationAction,
            icon: Icons.event_available_outlined,
            onPressed: () => _openConsultation(context),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: AppLocalizations.of(context).askAssistantAction,
            variant: AppButtonVariant.secondary,
            icon: Icons.auto_awesome_outlined,
            onPressed: () => _openAi(context),
          ),
          const SizedBox(height: 28),
        ],
      ],
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: SingleChildScrollView(child: content)),
                const SizedBox(width: 20),
                SizedBox(
                  width: 280,
                  child: Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppLocalizations.of(context).nextStepsHeading,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          AppButton(
                            label: AppLocalizations.of(context)
                                .bookConsultationAction,
                            icon: Icons.event_available_outlined,
                            onPressed: () => _openConsultation(context),
                          ),
                          const SizedBox(height: 10),
                          AppButton(
                            label: AppLocalizations.of(context)
                                .askAssistantAction,
                            icon: Icons.auto_awesome_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _openAi(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: content,
        ),
      ),
    );
  }
}

class _ProgramAccordions extends StatefulWidget {
  const _ProgramAccordions({
    required this.description,
    required this.requirements,
    required this.steps,
    required this.processingTime,
    required this.fees,
    required this.source,
    required this.l10n,
  });

  final String? description;
  final List<VisaRequirement> requirements;
  final List<VisaStep> steps;
  final String? processingTime;
  final String? fees;
  final VisaSource source;
  final AppLocalizations l10n;

  @override
  State<_ProgramAccordions> createState() => _ProgramAccordionsState();
}

class _ProgramAccordionsState extends State<_ProgramAccordions> {
  late final Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    final first = widget.description != null
        ? 'overview'
        : widget.requirements.isNotEmpty
        ? 'requirements'
        : widget.steps.isNotEmpty
        ? 'steps'
        : 'source';
    _expanded = {first};
  }

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (widget.description != null) {
      panels.add(
        _accordion(
          keyName: 'overview',
          title: AppLocalizations.of(context).programOverview,
          child: Text(widget.description!),
        ),
      );
    }
    if (widget.requirements.isNotEmpty) {
      panels.add(
        _accordion(
          keyName: 'requirements',
          title: widget.l10n.publishedRequirements,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in widget.requirements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r.isMandatory == true
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (widget.steps.isNotEmpty) {
      panels.add(
        _accordion(
          keyName: 'steps',
          title: widget.l10n.applicationSteps,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primaryRed,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.steps[i].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.steps[i].description.isNotEmpty)
                              Text(widget.steps[i].description),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if ((widget.processingTime ?? '').isNotEmpty ||
        (widget.fees ?? '').isNotEmpty) {
      panels.add(
        _accordion(
          keyName: 'timing',
          title: AppLocalizations.of(context).timingAndFees,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((widget.processingTime ?? '').isNotEmpty)
                Text(
                  '${AppLocalizations.of(context).processingTimeLabel}: ${widget.processingTime}',
                ),
              if ((widget.fees ?? '').isNotEmpty)
                Text(
                  '${AppLocalizations.of(context).feesLabel}: ${widget.fees}',
                ),
            ],
          ),
        ),
      );
    }
    panels.add(
      _accordion(
        keyName: 'source',
        title: widget.l10n.source,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.source.title} — ${widget.source.publisher}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.source.url.isNotEmpty) ...[
              const SizedBox(height: 4),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  widget.source.url,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.teal),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              widget.l10n.structuredSourceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );

    return Column(children: panels);
  }

  Widget _accordion({
    required String keyName,
    required String title,
    required Widget child,
  }) {
    final open = _expanded.contains(keyName);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: ExpansionTile(
        key: PageStorageKey(keyName),
        initiallyExpanded: open,
        onExpansionChanged: (v) {
          setState(() {
            if (v) {
              _expanded.add(keyName);
            } else {
              _expanded.remove(keyName);
            }
          });
        },
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
