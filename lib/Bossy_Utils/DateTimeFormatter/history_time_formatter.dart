import 'package:intl/intl.dart';

class HistoryTimeFormatter {
  static DateTime local(DateTime value) => value.toLocal();

  static DateTime parseLocal(dynamic value) {
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value?.toString() ?? '');
    return (parsed ?? DateTime.now()).toLocal();
  }

  static String list(DateTime value) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(local(value));
  }

  static String timeAgo(DateTime? value) {
    if (value == null) return '';

    final difference = DateTime.now().difference(local(value));
    final seconds = difference.inSeconds;

    if (seconds < 1) return 'just now';
    if (seconds < 60) return _ago(seconds, 'sec');

    final minutes = difference.inMinutes;
    if (minutes < 60) return _ago(minutes, 'min');

    final hours = difference.inHours;
    if (hours < 24) return _ago(hours, 'hour');

    final days = difference.inDays;
    if (days < 30) return _ago(days, 'day');

    final months = days ~/ 30;
    if (months < 12) return _ago(months, 'month');

    return _ago(days ~/ 365, 'year');
  }

  static String _ago(int value, String unit) {
    return '$value $unit${value == 1 ? '' : 's'} ago';
  }

  static String detail(DateTime value) {
    return DateFormat('dd MMM yyyy, h:mm a').format(local(value));
  }

  static String shortDate(DateTime value) {
    return DateFormat('dd MMM').format(local(value));
  }

  static String shortMonthYear(DateTime value) {
    return DateFormat('MMM yyyy').format(local(value));
  }

  static String month(DateTime value) {
    return DateFormat('MMMM').format(local(value));
  }

  static String year(DateTime value) {
    return DateFormat('yyyy').format(local(value));
  }
}
