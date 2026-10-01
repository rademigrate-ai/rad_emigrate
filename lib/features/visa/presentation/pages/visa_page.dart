import 'package:flutter/material.dart';

import '../../data/visa_catalog.dart';
import '../../domain/entities/visa_entities.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';

class VisaPage extends StatefulWidget {
  const VisaPage({super.key});

  @override
  State<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends State<VisaPage> {
  String? _selectedCountryId;
  VisaProgram? _selectedProgram;

  @override
  Widget build(BuildContext context) {
    if (_selectedProgram != null) {
      return _ProgramDetail(
        program: _selectedProgram!,
        onBack: () => setState(() => _selectedProgram = null),
      );
    }

    final programs = _selectedCountryId == null
        ? visaPrograms
        : visaPrograms.where((p) => p.countryId == _selectedCountryId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Visa programs')),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Find the right path',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore visa programs by destination. Requirements and timelines are provided as guidance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                Text(
                  'Choose a destination',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visaCountries.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final selected = _selectedCountryId == null;
                        return FilterChip(
                          label: const Text('All'),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCountryId = null),
                          selectedColor: AppColors.primaryRed.withValues(
                            alpha: 0.15,
                          ),
                        );
                      }
                      final c = visaCountries[index - 1];
                      final selected = _selectedCountryId == c.id;
                      return FilterChip(
                        label: Text('${c.flagEmoji} ${c.name}'),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedCountryId = c.id),
                        selectedColor: AppColors.primaryRed.withValues(
                          alpha: 0.15,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Available programs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (programs.isEmpty)
                  const EmptyState(
                    title: 'No programs found',
                    subtitle: 'Try another destination to explore available pathways.',
                    icon: Icons.public_off_outlined,
                  ),
                ...programs.map((p) {
                  final country = visaCountries.firstWhere(
                    (c) => c.id == p.countryId,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SectionCard(
                      title: p.title,
                      subtitle:
                          '${country.flagEmoji} ${country.name} · ${p.processingTime ?? 'TBD'}',
                      icon: Icons.flight_takeoff,
                      onTap: () => setState(() => _selectedProgram = p),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramDetail extends StatelessWidget {
  final VisaProgram program;
  final VoidCallback onBack;

  const _ProgramDetail({required this.program, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final country = visaCountries.firstWhere((c) => c.id == program.countryId);
    return Scaffold(
      appBar: AppBar(
        title: Text(program.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            '${country.flagEmoji} ${country.name}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(program.summary),
          if (program.processingTime != null) ...[
            const SizedBox(height: 12),
            Text(
              'Processing time: ${program.processingTime}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Key requirements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...program.requirements.map(
            (r) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.primaryRed,
              ),
              title: Text(r),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Information is for guidance only. Always verify with official immigration authorities.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
