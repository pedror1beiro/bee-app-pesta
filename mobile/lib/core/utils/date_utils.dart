class AppDateUtils {
  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String formatTime(DateTime dt) =>
      '${_pad(dt.hour)}:${_pad(dt.minute)}';

  static String formatDateTime(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)} ${formatTime(dt)}';

  static String formatFull(DateTime dt) =>
      '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${formatTime(dt)}';
}
