import '../../data/models/finance_model.dart';
import '../../data/repositories/finance_repository.dart';
import 'notification_service.dart';

/// Vadeli ödeme bildirimlerini finans kayıtlarıyla senkronize tutan
/// merkezi yardımcı. Kaydetme/güncelleme/silme noktalarından çağrılır;
/// böylece hatırlatıcılar zamanında planlanır ve zamanında iptal edilir.
class PaymentReminderSync {
  PaymentReminderSync._();

  /// Finans kaydı oluşturulduğunda veya güncellendiğinde çağrılır.
  /// - Ödenmişse veya dueDate yoksa: varsa hatırlatıcı iptal edilir.
  /// - Aksi halde mevcut iptal edilip yeni zamana göre yeniden planlanır.
  static Future<void> onSave(FinanceModel f) async {
    if (f.id == null) return;
    if (f.isPaid || f.dueDate == null) {
      await NotificationService.instance.cancelPaymentReminder(f.id!);
      return;
    }
    final due = DateTime.tryParse(f.dueDate!);
    if (due == null) {
      await NotificationService.instance.cancelPaymentReminder(f.id!);
      return;
    }
    await NotificationService.instance.schedulePaymentReminder(
      financeId: f.id!,
      category: f.category,
      amount: f.amount,
      dueDate: due,
      description: f.description,
    );
  }

  /// Finans kaydı silindiğinde çağrılır.
  static Future<void> onDelete(int financeId) async {
    await NotificationService.instance.cancelPaymentReminder(financeId);
  }

  /// Veritabanındaki tüm bekleyen (isPaid=0 + dueDate) kayıtlar için
  /// hatırlatıcıları yeniden planlar. Uygulama yeniden yüklendikten
  /// sonra veya "Ödeme Hatırlatıcılarını Yenile" butonundan çağrılır.
  /// Dönen değer: yeniden planlanan kayıt sayısı.
  static Future<int> rescheduleAll() async {
    final repo = FinanceRepository();
    final unpaid = await repo.getUnpaid();
    int scheduled = 0;
    for (final f in unpaid) {
      if (f.id == null || f.dueDate == null) continue;
      final due = DateTime.tryParse(f.dueDate!);
      if (due == null) continue;
      await NotificationService.instance.schedulePaymentReminder(
        financeId: f.id!,
        category: f.category,
        amount: f.amount,
        dueDate: due,
        description: f.description,
      );
      scheduled++;
    }
    return scheduled;
  }
}
