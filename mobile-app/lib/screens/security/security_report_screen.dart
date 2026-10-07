import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_system.dart';

class SecurityReportScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const SecurityReportScreen({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iocs = List<Map<String, dynamic>>.from(report['iocs'] ?? []);
    final transcript = List<Map<String, dynamic>>.from(report['transcript'] ?? []);
    final scamType = report['scam_type'] ?? 'Unknown';
    final duration = report['duration_seconds'] ?? 0;
    final threatScore = (report['threat_score'] ?? 0.0) as double;
    final evelynTurns = report['evelyn_turns'] ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Security Report',
            style: GoogleFonts.inter(color: AegisColors.accentGreen, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AegisColors.accentGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AegisBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Banner ──
                AegisGlassContainer(
                  padding: const EdgeInsets.all(24),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  borderColor: Colors.redAccent.withValues(alpha: 0.5),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text('AegisMesh Protected You',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Scam Type: $scamType',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Evelyn kept the scammer engaged for ${duration}s across $evelynTurns exchanges.',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
    
                const SizedBox(height: 24),
    
                // ── Stats Row ──
                Row(
                  children: [
                    _StatCard(
                      label: 'Threat Score',
                      value: '${(threatScore * 100).toStringAsFixed(0)}%',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Call Duration',
                      value: '${duration}s',
                      icon: Icons.timer,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'IoCs Found',
                      value: '${iocs.length}',
                      icon: Icons.bug_report,
                      color: Colors.purpleAccent,
                    ),
                  ],
                ),
    
                const SizedBox(height: 32),
    
                // ── Indicators of Compromise ──
                _SectionHeader(icon: Icons.radar, title: 'Indicators of Compromise (IoCs)'),
                const SizedBox(height: 16),
                if (iocs.isEmpty)
                  Text('No IoCs detected.', style: GoogleFonts.inter(color: AegisColors.textSecondary))
                else
                  ...iocs.map((ioc) => _IoCCard(ioc: ioc)).toList(),
    
                const SizedBox(height: 32),
    
                // ── Live Transcript ──
                _SectionHeader(icon: Icons.chat_bubble_outline, title: 'Call Transcript'),
                const SizedBox(height: 16),
                AegisGlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: transcript.map((entry) {
                        final isEvelyn = entry['speaker'] == 'Evelyn';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isEvelyn
                                      ? AegisColors.accentGreen.withValues(alpha: 0.15)
                                      : Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry['speaker'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: isEvelyn ? AegisColors.accentGreen : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry['text'] ?? '',
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
    
                const SizedBox(height: 40),
    
                // ── Report Actions ──
                AegisButton(
                  text: 'Return Home',
                  onPressed: () {
                    // Pop back to home by removing all routes until home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-Widgets ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AegisColors.accentGreen, size: 20),
        const SizedBox(width: 12),
        Text(title,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AegisGlassContainer(
        padding: const EdgeInsets.all(16),
        backgroundColor: color.withValues(alpha: 0.05),
        borderColor: color.withValues(alpha: 0.2),
        borderRadius: 16,
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.inter(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(color: AegisColors.textSecondary, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _IoCCard extends StatelessWidget {
  final Map<String, dynamic> ioc;
  const _IoCCard({required this.ioc});

  @override
  Widget build(BuildContext context) {
    final type = ioc['type'] ?? 'Unknown';
    final value = ioc['value'] ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'URL/Domain':
        icon = Icons.link;
        color = Colors.orangeAccent;
        break;
      case 'Phone Number':
        icon = Icons.phone;
        color = Colors.redAccent;
        break;
      case 'Email':
        icon = Icons.email;
        color = Colors.purpleAccent;
        break;
      default:
        icon = Icons.warning;
        color = Colors.yellow;
    }

    return AegisGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: color.withValues(alpha: 0.05),
      borderColor: color.withValues(alpha: 0.2),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}
