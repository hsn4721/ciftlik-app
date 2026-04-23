import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/user_model.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await AuthService.instance.getFarmUsers();
    setState(() { _users = users; _loading = false; });
  }

  Future<void> _addUser() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddUserSheet(),
    );
    _load();
  }

  Future<void> _changeRole(UserModel user) async {
    final current = AuthService.instance.currentUser;
    if (current == null || !current.isOwner) return;
    if (user.uid == current.uid) return;

    final roles = [AppConstants.rolePartner, AppConstants.roleVet, AppConstants.roleWorker];
    final roleLabels = {'partner': 'Ortak Sahip', 'vet': 'Veteriner', 'worker': 'Çalışan'};

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rol Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((r) => RadioListTile<String>(
            value: r,
            groupValue: user.role,
            title: Text(roleLabels[r] ?? r),
            onChanged: (v) => Navigator.pop(context, v),
          )).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal'))],
      ),
    );

    if (selected != null && selected != user.role) {
      await AuthService.instance.updateUserRole(user.uid, selected);
      _load();
    }
  }

  Future<void> _deactivate(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kullanıcıyı Devre Dışı Bırak'),
        content: Text('${user.displayName} artık bu çiftliğe giremeyecek. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Devre Dışı Bırak'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.deactivateUser(user.uid);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final isOwner = currentUser?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _addUser,
              tooltip: 'Kullanıcı Ekle',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Kullanıcı bulunamadı'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final user = _users[i];
                    final isSelf = user.uid == currentUser?.uid;
                    return _UserCard(
                      user: user,
                      isSelf: isSelf,
                      isOwner: isOwner,
                      onChangeRole: () => _changeRole(user),
                      onDeactivate: () => _deactivate(user),
                    );
                  },
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final bool isOwner;
  final VoidCallback onChangeRole;
  final VoidCallback onDeactivate;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.isOwner,
    required this.onChangeRole,
    required this.onDeactivate,
  });

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleOwner: return AppColors.primaryGreen;
      case AppConstants.rolePartner: return AppColors.infoBlue;
      case AppConstants.roleVet: return const Color(0xFF6A1B9A);
      default: return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(user.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
        title: Row(children: [
          Expanded(child: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
              child: const Text('Siz', style: TextStyle(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
            ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(user.roleDisplay, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        trailing: isOwner && !isSelf && user.isActive
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'role') onChangeRole();
                  if (v == 'deactivate') onDeactivate();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'role',
                    child: Row(children: [Icon(Icons.swap_horiz, size: 16), SizedBox(width: 8), Text('Rol Değiştir')])),
                  const PopupMenuItem(value: 'deactivate',
                    child: Row(children: [Icon(Icons.person_off, color: Colors.red, size: 16), SizedBox(width: 8), Text('Devre Dışı')])),
                ],
              )
            : null,
      ),
    );
  }
}

// ─── ADD USER SHEET ───────────────────────────────────

class _AddUserSheet extends StatefulWidget {
  const _AddUserSheet();

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = AppConstants.roleWorker;
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  final _roleOptions = [
    {'value': AppConstants.rolePartner, 'label': 'Ortak Sahip', 'desc': 'Tam yetkili erişim'},
    {'value': AppConstants.roleVet, 'label': 'Veteriner', 'desc': 'Sağlık & Aşı modüllerine erişim'},
    {'value': AppConstants.roleWorker, 'label': 'Çalışan', 'desc': 'Görev takibi ve sınırlı erişim'},
  ];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final result = await AuthService.instance.inviteUser(
      email: _emailCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      role: _role,
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_nameCtrl.text} eklendi'), backgroundColor: AppColors.primaryGreen),
      );
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Yeni Kullanıcı Ekle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Ad Soyad *'),
                validator: (v) => v == null || v.isEmpty ? 'Ad soyad giriniz' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'E-posta giriniz';
                  if (!v.contains('@')) return 'Geçersiz e-posta';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Geçici Şifre *',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Şifre giriniz';
                  if (v.length < 6) return 'En az 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Kullanıcı Rolü', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ..._roleOptions.map((opt) => GestureDetector(
                onTap: () => setState(() => _role = opt['value']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _role == opt['value'] ? AppColors.primaryGreen.withValues(alpha: 0.08) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _role == opt['value'] ? AppColors.primaryGreen : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(children: [
                    Radio<String>(
                      value: opt['value']!,
                      groupValue: _role,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(opt['desc']!, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                    ])),
                  ]),
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Kullanıcı Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}
