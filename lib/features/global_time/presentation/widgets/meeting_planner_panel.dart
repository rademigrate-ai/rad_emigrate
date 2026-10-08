import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
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
        color: const Color(0xFF141C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.primaryRed),
              const SizedBox(width: 8),
              Text(
                lang == 'fa' ? 'برنامه‌ریزی تماس بین‌المللی' : 'International Meeting Planner',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lang == 'fa'
                ? 'پنجره‌های پیشنهادی همپوشانی ساعات کاری (نه تأیید دسترسی)'
                : 'Suggested overlapping working-hour windows (not confirmed availability)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CityDropdown(
                  label: lang == 'fa' ? 'مبدأ' : 'Origin',
                  value: _origin,
                  cities: widget.cities,
                  languageCode: lang,
                  onChanged: (c) => setState(() => _origin = c),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.swap_horiz, color: Colors.white54),
              ),
              Expanded(
                child: _CityDropdown(
                  label: lang == 'fa' ? 'مقصد' : 'Destination',
                  value: _destination,
                  cities: widget.cities,
                  languageCode: lang,
                  onChanged: (c) => setState(() => _destination = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('yyyy-MM-dd').format(_date)),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _durationMinutes,
                dropdownColor: const Color(0xFF1A222D),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                  DropdownMenuItem(value: 90, child: Text('90 min')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _durationMinutes = v);
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _compute,
                child: Text(lang == 'fa' ? 'نمایش' : 'Show'),
              ),
            ],
          ),
          if (_windows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              lang == 'fa' ? 'پنجره‌های پیشنهادی' : 'Suggested windows',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
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
        labelStyle: const TextStyle(color: Colors.white70),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<City>(
          value: value != null && cities.any((c) => c.id == value!.id)
              ? cities.firstWhere((c) => c.id == value!.id)
              : null,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A222D),
          style: const TextStyle(color: Colors.white),
          hint: Text(label, style: const TextStyle(color: Colors.white38)),
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
            : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: good
              ? AppColors.success.withValues(alpha: 0.5)
              : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(origin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          Text(dest, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            good
                ? (languageCode == 'fa' ? 'مناسب' : 'Suitable')
                : (languageCode == 'fa' ? 'نسبی' : 'Partial'),
            style: TextStyle(
              color: good ? AppColors.success : Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
