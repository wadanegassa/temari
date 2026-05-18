import 'package:intl/intl.dart';

String formatRelative(DateTime time, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(time);
}

String formatDate(DateTime? d) {
  if (d == null) return '—';
  return DateFormat.yMMMd().format(d);
}
