import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/premium_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../domain/city_catalog.dart';
import '../../domain/local_date_format.dart';
import '../../domain/meeting_planner.dart';
import '../../domain/timezone_engine.dart';
import 'global_time_labels.dart';

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
  late City _origin;
  late City _destination;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 0);
  int _duration = 60;
  int? _occurrence;
  bool _computed = false;
  List<tz.TZDateTime> _candidates = [];
  List<MeetingWindow> _windows = [];
  tz.TZDateTime? _converted;
  List<City> get _cities => {
    for (final c in [...CityCatalog.all, ...widget.cities]) c.id: c,
  }.values.toList();
  @override
  void initState() {
    super.initState();
    _origin = widget.cities.isNotEmpty
        ? widget.cities.first
        : CityCatalog.defaults.first;
    _destination = widget.cities.length > 1
        ? widget.cities[1]
        : CityCatalog.defaults[1];
    _date = TimezoneEngine.nowInCity(_origin);
  }

  void _clear() {
    _computed = false;
    _converted = null;
    _windows = [];
    _candidates = [];
    _occurrence = null;
  }

  void _compute() {
    final candidates = TimezoneEngine.localCandidates(
      _origin.timezone,
      _date,
      _time.hour,
      _time.minute,
    );
    setState(() {
      _computed = true;
      _candidates = candidates;
      _converted = null;
      _windows = [];
      if (candidates.isEmpty || candidates.length > 1 && _occurrence == null) {
        return;
      }
      _converted = tz.TZDateTime.from(
        candidates[_occurrence ?? 0],
        TimezoneEngine.locationOf(_destination.timezone),
      );
      _windows = MeetingPlanner.suggestWindows(
        origin: _origin,
        destination: _destination,
        year: _date.year,
        month: _date.month,
        day: _date.day,
        durationMinutes: _duration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = GlobalTimeLabels(widget.languageCode);
    Widget cityField(
      String title,
      City value,
      ValueChanged<City> change,
    ) => InputDecorator(
      decoration: InputDecoration(labelText: title, isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<City>(
          value: _cities.firstWhere((c) => c.id == value.id),
          isExpanded: true,
          items: [
            for (final c in _cities)
              DropdownMenuItem(
                value: c,
                child: Text(
                  '${c.flagEmoji ?? ''} ${c.localizedName(widget.languageCode)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                change(v);
                _clear();
              });
            }
          },
        ),
      ),
    );
    final fields = [
      SizedBox(
        width: 210,
        child: cityField(l.meetingOrigin, _origin, (v) => _origin = v),
      ),
      IconButton(
        tooltip: l.meetingDestination,
        onPressed: () => setState(() {
          final c = _origin;
          _origin = _destination;
          _destination = c;
          _clear();
        }),
        icon: const Icon(Icons.swap_horiz),
      ),
      SizedBox(
        width: 210,
        child: cityField(
          l.meetingDestination,
          _destination,
          (v) => _destination = v,
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.premium.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFFFF7685),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.meetingPlannerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            labels.assumptions,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 500
                ? Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: fields,
                  )
                : Column(
                    children: [
                      cityField(l.meetingOrigin, _origin, (v) => _origin = v),
                      const SizedBox(height: 12),
                      cityField(
                        l.meetingDestination,
                        _destination,
                        (v) => _destination = v,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('meeting-date'),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatLocalDate(_date, widget.languageCode)),
                onPressed: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (chosen != null && mounted) {
                    setState(() {
                      _date = chosen;
                      _clear();
                    });
                  }
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('meeting-time'),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  '${labels.originTime}: ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                ),
                onPressed: () async {
                  final chosen = await showTimePicker(
                    context: context,
                    initialTime: _time,
                    builder: (ctx, child) => MediaQuery(
                      data: MediaQuery.of(ctx)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (chosen != null && mounted) {
                    setState(() {
                      _time = chosen;
                      _clear();
                    });
                  }
                },
              ),
              DropdownButton<int>(
                value: _duration,
                items: [
                  for (final m in [30, 60, 90])
                    DropdownMenuItem(
                      value: m,
                      child: Text(l.meetingMinutes(m)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _duration = v;
                      _clear();
                    });
                  }
                },
              ),
              FilledButton.icon(
                key: const ValueKey('meeting-convert'),
                onPressed: _compute,
                icon: const Icon(Icons.compare_arrows),
                label: Text(l.meetingShow),
              ),
            ],
          ),
          if (_computed && _candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                labels.gap,
                style: TextStyle(color: context.premium.accentForeground),
              ),
            ),
          if (_candidates.length > 1) ...[
            const SizedBox(height: 12),
            Text(labels.fold),
            Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < _candidates.length; i++)
                  ChoiceChip(
                    label: Text(
                      '${i == 0 ? labels.first : labels.second} (${_candidates[i].timeZoneName})',
                    ),
                    selected: _occurrence == i,
                    onSelected: (_) {
                      setState(() => _occurrence = i);
                      _compute();
                    },
                  ),
              ],
            ),
          ],
          if (_converted != null) ...[
            const Divider(height: 32),
            Text(
              labels.converted,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Result(
                  city: _origin,
                  instant: _candidates[_occurrence ?? 0],
                  language: widget.languageCode,
                ),
                _Result(
                  city: _destination,
                  instant: _converted!,
                  language: widget.languageCode,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l.meetingSuggestedWindows,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (_windows.isEmpty) Text(labels.noOverlap),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final w in _windows.take(3))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF207D69)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF0D4D3D).withValues(alpha: .12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_origin.localizedName(widget.languageCode)} ${formatLocalTime(w.startLocalOrigin)} - ${formatLocalTime(w.endLocalOrigin)}',
                        ),
                        Text(
                          '${_destination.localizedName(widget.languageCode)} ${formatLocalTime(w.startLocalDestination)} - ${formatLocalTime(w.endLocalDestination)}',
                        ),
                        Text(
                          formatLocalDate(
                            w.startLocalDestination,
                            widget.languageCode,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.city,
    required this.instant,
    required this.language,
  });
  final City city;
  final tz.TZDateTime instant;
  final String language;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${city.flagEmoji ?? ''} ${city.localizedName(language)}'),
      Text(
        formatLocalTime(instant),
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      Text(formatLocalDate(instant, language)),
      Text(
        '${city.timezone}  ${TimezoneEngine.offsetLabel(city.timezone, at: instant)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
