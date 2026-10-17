import '../../../../l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/city.dart';
import '../../domain/meeting_planner.dart';

class MeetingPlannerPanel extends StatefulWidget {
  const MeetingPlannerPanel({
    super.key,
    required this.cities,
    required this.languageCode,
  });

  final List<City> cities;
  final String languageCode;

  @override
  State<MeetingPlannerPanel> createState() => _MeetingPlannerPanelState();
}

class _MeetingPlannerPanelState extends State<MeetingPlannerPanel> {
  City? _origin;
  City? _destination;
  DateTime _date = DateTime.now();
  int _durationMinutes = 60;
  List<MeetingWindow> _windows = [];

  @override
  void initState() {
    super.initState();
    if (widget.cities.length >= 2) {
      _origin = widget.cities[0];
      _destination = widget.cities[1];
    } else if (widget.cities.isNotEmpty) {
      _origin = widget.cities.first;
    }
  }

  @override
  void didUpdateWidget(covariant MeetingPlannerPanel old) {
    super.didUpdateWidget(old);
    if (_origin == null && widget.cities.isNotEmpty) {
      _origin = widget.cities.first;
    }
  }

  void _compute() {
    if (_origin == null || _destination == null) return;
    setState(() {
      _windows = MeetingPlanner.suggestWindows(
        origin: _origin!,
        destination: _destination!,
        year: _date.year,
        month: _date.month,
        day: _date.day,
        durationMinutes: _durationMinutes,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).meetingPlannerTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.premium.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).meetingPlannerDisclaimer,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.premium.mutedText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CityDropdown(
                  label: AppLocalizations.of(context).meetingOrigin,
                  value: _origin,
                  cities: widget.cities,
                  languageCode: lang,
                  onChanged: (c) => setState(() => _origin = c),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz, color: context.premium.mutedText),
              ),
              Expanded(
                child: _CityDropdown(
                  label: AppLocalizations.of(context).meetingDestination,
                  value: _destination,
                  cities: widget.cities,
                  languageCode: lang,
                  onChanged: (c) => setState(() => _destination = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).languageCode,
                    ).format(_date),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _durationMinutes,
                dropdownColor: context.premium.surfaceElevated,
                style: TextStyle(color: context.premium.text),
                items: [
                  for (final minutes in [30, 60, 90])
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(
                        AppLocalizations.of(context).meetingMinutes(minutes),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _durationMinutes = v);
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _compute,
                child: Text(AppLocalizations.of(context).meetingShow),
              ),
            ],
          ),
          if (_windows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).meetingSuggestedWindows,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: context.premium.text),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in _windows.take(4))
                  _WindowChip(window: w, languageCode: lang),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CityDropdown extends StatelessWidget {
  const _CityDropdown({
    required this.label,
    required this.value,
    required this.cities,
    required this.languageCode,
    required this.onChanged,
  });

  final String label;
  final City? value;
  final List<City> cities;
  final String languageCode;
  final ValueChanged<City?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.premium.mutedText),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<City>(
          value: value != null && cities.any((c) => c.id == value!.id)
              ? cities.firstWhere((c) => c.id == value!.id)
              : null,
          isExpanded: true,
          dropdownColor: context.premium.surfaceElevated,
          style: TextStyle(color: context.premium.text),
          hint: Text(label, style: TextStyle(color: context.premium.mutedText)),
          items: [
            for (final c in cities)
              DropdownMenuItem(
                value: c,
                child: Text(
                  '${c.flagEmoji ?? ''} ${c.localizedName(languageCode)}',
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({required this.window, required this.languageCode});
  final MeetingWindow window;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm');
    final origin =
        '${fmt.format(window.startLocalOrigin)}–${fmt.format(window.endLocalOrigin)}';
    final dest =
        '${fmt.format(window.startLocalDestination)}–${fmt.format(window.endLocalDestination)}';
    final good = window.quality >= 0.9;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: good
            ? AppColors.success.withValues(alpha: 0.2)
            : context.premium.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: good
              ? AppColors.success.withValues(alpha: 0.5)
              : context.premium.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            origin,
            style: TextStyle(
              color: context.premium.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            dest,
            style: TextStyle(color: context.premium.mutedText, fontSize: 12),
          ),
          Text(
            good
                ? (AppLocalizations.of(context).meetingSuitable)
                : (AppLocalizations.of(context).meetingPartial),
            style: TextStyle(
              color: good ? AppColors.success : context.premium.mutedText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
