import 'package:flutter/material.dart';
import '../../data/documents_mock_data.dart';
import '../../domain/entities/document_entities.dart';
import '../../../../core/constants/app_colors.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  Color _statusColor(DocumentStatus s) {
    switch (s) {
      case DocumentStatus.missing:
        return Colors.grey;
      case DocumentStatus.uploaded:
        return Colors.blue;
      case DocumentStatus.underReview:
        return Colors.orange;
      case DocumentStatus.verified:
        return Colors.green;
      case DocumentStatus.rejected:
        return AppColors.primaryRed;
    }
  }

  IconData _statusIcon(DocumentStatus s) {
    switch (s) {
      case DocumentStatus.missing:
        return Icons.hourglass_empty;
      case DocumentStatus.uploaded:
        return Icons.cloud_upload_outlined;
      case DocumentStatus.underReview:
        return Icons.pending_actions;
      case DocumentStatus.verified:
        return Icons.verified;
      case DocumentStatus.rejected:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: mockDocuments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final doc = mockDocuments[index];
          return Card(
            child: ListTile(
              leading: Icon(_statusIcon(doc.status), color: _statusColor(doc.status)),
              title: Text(doc.name),
              subtitle: Text(doc.status.label),
              trailing: Chip(
                label: Text(doc.status.label, style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: _statusColor(doc.status),
                visualDensity: VisualDensity.compact,
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Status: ${doc.status.label}'),
                        if (doc.updatedAt != null)
                          Text('Updated: ${doc.updatedAt!.toIso8601String().substring(0, 10)}'),
                        const SizedBox(height: 16),
                        const Text(
                          'Upload and AI document analysis will be available in a future release.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
