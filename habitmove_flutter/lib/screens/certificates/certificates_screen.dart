import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});
  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  List<CertificateModel> _certs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final c = await api.getCertificates();
      setState(() { _certs = c; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.sage50,
    appBar: AppBar(
      title: const Text('Certificates'),
      backgroundColor: AppColors.sage800,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? ErrorRetry(message: _error!, onRetry: _load)
            : _certs.isEmpty
                ? const EmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No certificates yet',
                    subtitle: 'Complete a course to earn your first certificate.',
                  )
                : RefreshIndicator(
                    color: AppColors.sage600,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _certs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CertCard(cert: _certs[i]),
                    ),
                  ),
  );
}

class _CertCard extends StatelessWidget {
  final CertificateModel cert;
  const _CertCard({required this.cert});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.warm200),
    ),
    child: Row(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.warm100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: AppColors.warm600, size: 32),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cert.courseTitle, style: AppTextStyles.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (cert.issuedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Issued ${_formatDate(cert.issuedAt!)}',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400),
                ),
              ],
            ],
          ),
        ),
        if (cert.certificateUrl != null)
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.sage600),
            onPressed: () => launchUrl(
              Uri.parse(cert.certificateUrl!),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ],
    ),
  );

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${_month(dt.month)} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}
