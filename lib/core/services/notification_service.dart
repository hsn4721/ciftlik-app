import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleVaccineReminder({
    required int id,
    required String animalName,
    required String vaccineName,
    required DateTime dueDate,
  }) async {
    final scheduled = tz.TZDateTime.from(
      DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0),
      tz.local,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      'Aşı Hatırlatması',
      '$animalName için $vaccineName aşısı bugün yapılmalı',
      scheduled,
      _notifDetails(channelId: 'vaccine', channelName: 'Aşı Hatırlatmaları'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleBirthReminder({
    required int id,
    required String animalName,
    required DateTime expectedDate,
  }) async {
    final reminderDate = expectedDate.subtract(const Duration(days: 3));
    final scheduled = tz.TZDateTime.from(
      DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 9, 0),
      tz.local,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id + 10000,
      'Doğum Yaklaşıyor',
      '$animalName için tahmini doğum 3 gün sonra',
      scheduled,
      _notifDetails(channelId: 'birth', channelName: 'Doğum Hatırlatmaları'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Vadeli ödeme hatırlatması: 1 gün önce + ödeme günü (09:00).
  /// Finans kaydı silinince/ödenince [cancelPaymentReminder] ile iptal edilir.
  Future<void> schedulePaymentReminder({
    required int financeId,
    required String category,
    required double amount,
    required DateTime dueDate,
    String? description,
  }) async {
    // Mevcut olasılıkları temizle (re-schedule senaryosunda)
    await cancelPaymentReminder(financeId);

    final now = tz.TZDateTime.now(tz.local);
    final amountStr = amount.toStringAsFixed(2);

    // Ödeme günü 09:00
    final dueAt = tz.TZDateTime.from(
      DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0),
      tz.local,
    );
    if (dueAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        20000 + financeId,
        'Ödeme Günü',
        '$category — TL $amountStr bugün ödenmeli${description != null ? ' · $description' : ''}',
        dueAt,
        _notifDetails(channelId: 'payment', channelName: 'Ödeme Hatırlatmaları'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Bir gün önce 09:00
    final preAt = tz.TZDateTime.from(
      DateTime(dueDate.year, dueDate.month, dueDate.day - 1, 9, 0),
      tz.local,
    );
    if (preAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        30000 + financeId,
        'Ödeme Yarın',
        '$category — TL $amountStr yarın ödenecek${description != null ? ' · $description' : ''}',
        preAt,
        _notifDetails(channelId: 'payment', channelName: 'Ödeme Hatırlatmaları'),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelPaymentReminder(int financeId) async {
    await _plugin.cancel(20000 + financeId);
    await _plugin.cancel(30000 + financeId);
  }

  /// Veteriner talep bildirimi (vet'e gelen canlı istek).
  /// Anlık (schedule değil) — listener çağırınca gösterilir.
  Future<void> showVetRequestAlert({
    required String farmName,
    required String requesterName,
    required String category,
    required String urgency,
    required int notifId,
  }) async {
    final title = urgency == 'Acil'
        ? '🚨 ACİL Veteriner Talebi'
        : urgency == 'Orta'
            ? '⚠️ Veteriner Talebi'
            : 'Veteriner Talebi';
    final body = '$farmName · $requesterName\n$category · $urgency';
    await _plugin.show(
      50000 + notifId,
      title,
      body,
      _notifDetails(channelId: 'vet_request', channelName: 'Veteriner Talepleri'),
    );
  }

  /// Requester'a: "Veteriniz talebinizi gördü".
  Future<void> showVetReadReceipt({
    required String vetName,
    required String category,
    required int notifId,
  }) async {
    await _plugin.show(
      60000 + notifId,
      'Talebiniz okundu',
      '$vetName talebinizi gördü · $category',
      _notifDetails(channelId: 'vet_request', channelName: 'Veteriner Talepleri'),
    );
  }

  /// Owner'a: "X daveti kabul etti / reddetti".
  Future<void> showInvitationResponse({
    required String inviteeName,
    required String inviteeEmail,
    required String farmName,
    required bool accepted,
    required int notifId,
  }) async {
    final title = accepted ? '✅ Davet Kabul Edildi' : '❌ Davet Reddedildi';
    final label = inviteeName.isNotEmpty ? inviteeName : inviteeEmail;
    final body = accepted
        ? '$label "$farmName" çiftliğinize katıldı'
        : '$label "$farmName" davetinizi reddetti';
    await _plugin.show(
      70000 + notifId,
      title,
      body,
      _notifDetails(channelId: 'invitation', channelName: 'Davet Bildirimleri'),
    );
  }

  /// Personele: yeni görev atandı.
  Future<void> showTaskAssigned({
    required String taskTitle,
    required String assignedByName,
    required String priorityLabel,
    DateTime? dueDate,
    required int notifId,
  }) async {
    final due = dueDate == null ? '' : ' · Son: ${dueDate.day}.${dueDate.month}.${dueDate.year}';
    await _plugin.show(
      80000 + notifId,
      '📋 Yeni Görev',
      '$taskTitle\n$assignedByName · $priorityLabel$due',
      _notifDetails(channelId: 'task', channelName: 'Görev Bildirimleri'),
    );
  }

  /// Owner/Assistant'a: görev tamamlandı.
  Future<void> showTaskCompleted({
    required String taskTitle,
    required String completedByName,
    String? completionNote,
    required int notifId,
  }) async {
    final body = completionNote != null && completionNote.isNotEmpty
        ? '$completedByName tamamladı\n📝 $completionNote'
        : '$completedByName tamamladı';
    await _plugin.show(
      90000 + notifId,
      '✅ Görev Tamamlandı',
      '$taskTitle\n$body',
      _notifDetails(channelId: 'task', channelName: 'Görev Bildirimleri'),
    );
  }

  /// Owner/Assistant'a: yeni izin talebi.
  Future<void> showLeaveRequested({
    required String staffName,
    required String reason,
    required int dayCount,
    required int notifId,
  }) async {
    await _plugin.show(
      100000 + notifId,
      '🗓️ Yeni İzin Talebi',
      '$staffName · $reason · $dayCount gün',
      _notifDetails(channelId: 'leave', channelName: 'İzin Bildirimleri'),
    );
  }

  /// Personele/Vet'e: izin talebi onay/red.
  Future<void> showLeaveResponse({
    required String reason,
    required bool approved,
    required String responderName,
    String? responseNote,
    required int notifId,
  }) async {
    final title = approved ? '✅ İzin Onaylandı' : '❌ İzin Reddedildi';
    final note = responseNote != null && responseNote.isNotEmpty
        ? '\n📝 $responseNote' : '';
    await _plugin.show(
      110000 + notifId,
      title,
      '$reason · $responderName$note',
      _notifDetails(channelId: 'leave', channelName: 'İzin Bildirimleri'),
    );
  }

  Future<void> showLowStockAlert(String stockName) async {
    await _plugin.show(
      stockName.hashCode.abs(),
      'Düşük Stok Uyarısı',
      '$stockName stoku kritik seviyenin altına düştü',
      _notifDetails(channelId: 'stock', channelName: 'Stok Uyarıları'),
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  NotificationDetails _notifDetails({
    required String channelId,
    required String channelName,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
