import '../domain/app_notification.dart';

/// Part P-115 (STEP 4): the three recency sections of the notification
/// center. Presentation only: grouping never changes the list provider, the
/// order of the items, or what a tap does.
enum NotificationSection { today, thisWeek, earlier }

/// One section with its items, in the same order the provider holds them.
class NotificationGroup {
  const NotificationGroup({required this.section, required this.items});

  final NotificationSection section;
  final List<AppNotification> items;
}

/// Number of calendar days (device local time) that separate [createdAt]
/// from [now]. Both are reduced to their local calendar date first, and the
/// difference is taken between two UTC midnights, so a daylight-saving day
/// of 23 or 25 hours can never shift a notification into the wrong section.
int notificationAgeInDays(DateTime createdAt, DateTime now) {
  final DateTime local = createdAt.toLocal();
  final DateTime current = now.toLocal();
  final DateTime day = DateTime.utc(local.year, local.month, local.day);
  final DateTime today = DateTime.utc(current.year, current.month, current.day);
  return today.difference(day).inDays;
}

/// Today = the same calendar day (or a time slightly in the future because
/// of a small clock difference with the server). This week = 1 to 6 days
/// ago. Earlier = 7 days or more.
NotificationSection notificationSectionFor(DateTime createdAt, DateTime now) {
  final int age = notificationAgeInDays(createdAt, now);
  if (age <= 0) {
    return NotificationSection.today;
  }
  if (age < 7) {
    return NotificationSection.thisWeek;
  }
  return NotificationSection.earlier;
}

/// Splits [items] into Today / This week / Earlier. Sections come out in that
/// fixed order, empty sections are left out, and the order of the items
/// inside a section is the order they came in.
List<NotificationGroup> groupNotificationsByRecency(
  List<AppNotification> items,
  DateTime now,
) {
  final Map<NotificationSection, List<AppNotification>> buckets =
      <NotificationSection, List<AppNotification>>{
        for (final NotificationSection section in NotificationSection.values)
          section: <AppNotification>[],
      };
  for (final AppNotification item in items) {
    buckets[notificationSectionFor(item.createdAt, now)]!.add(item);
  }
  return <NotificationGroup>[
    for (final NotificationSection section in NotificationSection.values)
      if (buckets[section]!.isNotEmpty)
        NotificationGroup(section: section, items: buckets[section]!),
  ];
}
