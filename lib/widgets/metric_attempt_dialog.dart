import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../theme/app_theme.dart';

class MetricAttemptInput {
  final ChallengeMetric metric;
  final double value;
  final String? note;

  const MetricAttemptInput({
    required this.metric,
    required this.value,
    this.note,
  });
}

class MetricAttemptDialog extends StatefulWidget {
  final List<ChallengeMetric> metrics;

  const MetricAttemptDialog({super.key, required this.metrics});

  @override
  State<MetricAttemptDialog> createState() => _MetricAttemptDialogState();
}

class _MetricAttemptDialogState extends State<MetricAttemptDialog> {
  final _value = TextEditingController();
  final _note = TextEditingController();
  late ChallengeMetric _metric;
  String? _error;

  @override
  void initState() {
    super.initState();
    _metric = widget.metrics.first;
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_value.text.trim());
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid result.');
      return;
    }
    Navigator.pop(
      context,
      MetricAttemptInput(
        metric: _metric,
        value: value,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log a result'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.metrics.length > 1)
            DropdownButtonFormField<ChallengeMetric>(
              initialValue: _metric,
              decoration: const InputDecoration(labelText: 'Metric'),
              items: [
                for (final metric in widget.metrics)
                  DropdownMenuItem(value: metric, child: Text(metric.label)),
              ],
              onChanged: (metric) {
                if (metric != null) setState(() => _metric = metric);
              },
            ),
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _metric.label,
              suffixText: _metric.unit,
              hintText: 'e.g. 5',
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 5000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Log result')),
    ],
  );
}