import 'package:flutter/material.dart';
import '../../data/applications_mock_data.dart';
import '../../domain/entities/application_entities.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/constants/app_colors.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  Application? _selected;

  Color _statusColor(ColorStatus s) {
    switch (s) {
      case ColorStatus.grey:
        return Colors.grey;
      case ColorStatus.blue:
        return Colors.blue;
      case ColorStatus.orange:
        return Colors.orange;
      case ColorStatus.green:
        return Colors.green;
      case ColorStatus.red:
        return AppColors.primaryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      final app = _selected!;
      return Scaffold(
        appBar: AppBar(
          title: Text(app.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selected = null),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Program'),
              subtitle: Text(app.programName),
            ),
            ListTile(
              title: const Text('Country'),
              subtitle: Text(app.country),
            ),
            ListTile(
              title: const Text('Status'),
              subtitle: Text(app.status.label),
              trailing: Chip(
                label: Text(app.status.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: _statusColor(app.status.colorStatus),
              ),
            ),
            ListTile(
              title: const Text('Last updated'),
              subtitle: Text('${app.updatedAt.year}-${app.updatedAt.month.toString().padLeft(2, '0')}-${app.updatedAt.day.toString().padLeft(2, '0')}'),
            ),
            if (app.notes != null)
              ListTile(
                title: const Text('Notes'),
                subtitle: Text(app.notes!),
              ),
          ],
        ),
      );
    }

    if (mockApplications.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Applications')),
        body: const EmptyView(
          title: 'No applications yet',
          subtitle: 'Start a new immigration application from Visa programs.',
          icon: Icons.assignment_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: mockApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final app = mockApplications[index];
          return Card(
            child: ListTile(
              title: Text(app.title),
              subtitle: Text('${app.programName} · ${app.country}'),
              trailing: Chip(
                label: Text(app.status.label, style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: _statusColor(app.status.colorStatus),
                visualDensity: VisualDensity.compact,
              ),
              onTap: () => setState(() => _selected = app),
            ),
          );
        },
      ),
    );
  }
}
