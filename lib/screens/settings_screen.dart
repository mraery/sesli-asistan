import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _backendUrlController = TextEditingController();
  bool _obscureApiKey = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final key = await StorageService.getApiKey();
    final url = await StorageService.getBackendUrl();
    setState(() {
      _apiKeyController.text = key;
      _backendUrlController.text = url;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.setApiKey(_apiKeyController.text);
    await StorageService.setBackendUrl(_backendUrlController.text);
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayarlar başarıyla kaydedildi!')),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar & Bilgi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: theme.colorScheme.primary, size: 26),
                            const SizedBox(width: 8),
                            Text(
                              'Hibrit Çözümleme Aktif',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uygulama; "saat 2\'de ara", "15 dakika sonra fırını kapat", "yarın 9\'da fatura öde" gibi konuşmaları telefonun kendi işlemcisinde SIFIR MALİYET ve ANLIK olarak çözer. İnternet gerektirmez.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Yapay Zeka (Gemini) Desteği (İsteğe Bağlı)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Çok dolaylı ve karmaşık konuşmalar için kendi Gemini API anahtarınızı veya özel backend sunucunuzu bağlayabilirsiniz. Boş bırakırsanız cihaz içi motor çalışır.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Anahtarı',
                    hintText: 'AIzaSy...',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureApiKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _backendUrlController,
                  decoration: InputDecoration(
                    labelText: 'Özel Backend URL (İsteğe Bağlı)',
                    hintText: 'https://api.benimsitem.com/parse',
                    prefixIcon: const Icon(Icons.cloud_queue_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Ayarları Kaydet'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Test & Bildirimler',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await NotificationService().showInstantNotification(
                      title: '🔔 Sesli Asistan Bildirim Testi',
                      body: 'Tebrikler! Alarmlarınız ve bildirimleriniz başarıyla çalışıyor.',
                    );
                    if (!mounted || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test bildirimi gönderildi!')),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Anlık Bildirim & Alarmı Test Et'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await NotificationService().requestPermissions();
                    if (!mounted || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('İzin talebi gönderildi.')),
                    );
                  },
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('Alarm & Bildirim İzinlerini Yenile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await NotificationService().cancelAllNotifications();
                    if (!mounted || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tüm bekleyen alarmlar temizlendi!')),
                    );
                  },
                  icon: const Icon(Icons.notifications_off_rounded),
                  label: const Text('Tüm Bekleyen Alarmları İptal Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
