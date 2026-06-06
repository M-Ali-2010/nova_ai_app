// ═══════════════════════════════════════════════════════════════════════════
// NOVA AI STUDIO — PART 1
// Core Architecture + Services + Home + Generator
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'api_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const NovaApp());
}

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════
const _bg0 = Color(0xFF010108);
const _bg1 = Color(0xFF05050F);
const _bg2 = Color(0xFF080818);
const _bg3 = Color(0xFF0B0B20);

const _violet      = Color(0xFF7B5EA7);
const _violetDeep  = Color(0xFF4A2D8A);
const _electric    = Color(0xFF8B7FFF);
const _electricBright = Color(0xFFB8B0FF);
const _glow        = Color(0xFFD4D0FF);
const _rose        = Color(0xFFE8547A);
const _roseBright  = Color(0xFFFF7A96);
const _amber       = Color(0xFFE8A854);
const _teal        = Color(0xFF54C5B8);
const _emerald     = Color(0xFF3DD68C);
const _emeraldBright = Color(0xFF6FFFB8);
const _gold        = Color(0xFFFFD700);
const _platinum    = Color(0xFFE8E8FF);

const _glass1  = Color(0x12FFFFFF);
const _glass2  = Color(0x08FFFFFF);
const _glass3  = Color(0x1AFFFFFF);
const _glass4  = Color(0x22FFFFFF);
const _border1 = Color(0x20FFFFFF);
const _border2 = Color(0x10FFFFFF);
const _border3 = Color(0x35FFFFFF);

const _bgGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.35, 0.7, 1.0],
  colors: [Color(0xFF02020C), Color(0xFF060614), Color(0xFF08081A), Color(0xFF0A0A1E)],
);

const accentGrad = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_electricBright, _electric, _violet],
  stops: [0.0, 0.5, 1.0],
);

const accentGradSubtle = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6B60E0), Color(0xFF4A3AA0)],
);

const _roseGrad    = LinearGradient(colors: [_roseBright, _rose, Color(0xFFAA2050)], stops: [0.0, 0.5, 1.0]);
const _tealGrad    = LinearGradient(colors: [Color(0xFF7EEEE6), _teal, Color(0xFF2A8F84)]);
const _amberGrad   = LinearGradient(colors: [Color(0xFFFFCA7A), _amber, Color(0xFFA86020)]);
const _emeraldGrad = LinearGradient(colors: [_emeraldBright, _emerald, Color(0xFF1FAA60)]);

// ═══════════════════════════════════════════════════════════════════════════
// GENERATION STATE MACHINE
// ═══════════════════════════════════════════════════════════════════════════
enum GenerationState { idle, queued, processing, succeeded, failed, cancelled }

extension GenerationStateX on GenerationState {
  String get label {
    switch (this) {
      case GenerationState.idle:        return 'Ready';
      case GenerationState.queued:      return 'Queued…';
      case GenerationState.processing:  return 'Processing…';
      case GenerationState.succeeded:   return 'Done';
      case GenerationState.failed:      return 'Failed';
      case GenerationState.cancelled:   return 'Cancelled';
    }
  }
  bool get isActive => this == GenerationState.queued || this == GenerationState.processing;
  Color get color {
    switch (this) {
      case GenerationState.idle:        return _electric;
      case GenerationState.queued:      return _amber;
      case GenerationState.processing:  return _electric;
      case GenerationState.succeeded:   return _emerald;
      case GenerationState.failed:      return _rose;
      case GenerationState.cancelled:   return Colors.white38;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GENERATION ITEM MODEL
// ═══════════════════════════════════════════════════════════════════════════
class GenerationItem {
  final String id;
  final String url;
  final String type; // 'image' | 'video'
  final String prompt;
  final DateTime createdAt;

  GenerationItem({
    required this.id,
    required this.url,
    required this.type,
    required this.prompt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'type': type,
    'prompt': prompt,
    'ts': createdAt.toIso8601String(),
  };

  factory GenerationItem.fromJson(Map<String, dynamic> j) => GenerationItem(
    id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    url: j['url'] as String,
    type: j['type'] as String,
    prompt: j['prompt'] as String? ?? '',
    createdAt: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCAL STORAGE SERVICE
// ═══════════════════════════════════════════════════════════════════════════
class LocalStorageService {
  static const _galleryKey     = 'gallery_v2';
  static const _promptHistKey  = 'prompt_history';
  static const _statsKey       = 'stats_v2';

  // ── Gallery ────────────────────────────────────────────────────────────
  Future<List<GenerationItem>> loadGallery() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_galleryKey) ?? [];
    return raw
        .map((e) => GenerationItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<void> saveItem(GenerationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_galleryKey) ?? [];
    raw.add(jsonEncode(item.toJson()));
    await prefs.setStringList(_galleryKey, raw);
    await _incrementStat(item.type == 'image' ? 'images' : 'videos');
  }

  Future<void> deleteItem(GenerationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_galleryKey) ?? [];
    raw.removeWhere((e) {
      final m = jsonDecode(e) as Map<String, dynamic>;
      return m['id'] == item.id;
    });
    await prefs.setStringList(_galleryKey, raw);
  }

  Future<void> clearGallery() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_galleryKey);
  }

  // ── Prompt history ─────────────────────────────────────────────────────
  Future<List<String>> loadPromptHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_promptHistKey) ?? [];
  }

  Future<void> addPromptToHistory(String prompt) async {
    if (prompt.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_promptHistKey) ?? [];
    list.remove(prompt); // deduplicate
    list.insert(0, prompt);
    if (list.length > 20) list.removeLast();
    await prefs.setStringList(_promptHistKey, list);
  }

  // ── Stats ───────────────────────────────────────────────────────────────
  Future<Map<String, int>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return {'images': 0, 'videos': 0, 'total': 0};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<void> _incrementStat(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await loadStats();
    stats[key] = (stats[key] ?? 0) + 1;
    stats['total'] = (stats['total'] ?? 0) + 1;
    await prefs.setString(_statsKey, jsonEncode(stats));
  }

  Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
  }

  Future<int> estimateStorageBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_galleryKey) ?? [];
    final list = await raw;
    return list.fold<int>(0, (acc, e) => acc + e.length * 2);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// API SERVICE
// ═══════════════════════════════════════════════════════════════════════════
class ApiService {
  static const _timeout = Duration(seconds: 10);
  final _client = http.Client();
  bool _cancelled = false;

  void cancel() => _cancelled = true;
  void reset()  => _cancelled = false;

  Future<bool> checkHealth() async {
    try {
      final res = await _client.get(
        Uri.parse('https://api.replicate.com/v1/models/stability-ai/sdxl'),
        headers: {'Authorization': 'Bearer ${ApiConfig.apiKey}'},
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns poll URL
  Future<String> createPrediction({
    required String prompt,
    required String modelVersion,
    required Map<String, dynamic> extraInput,
  }) async {
    final res = await _client.post(
      Uri.parse(ApiConfig.baseUrl),
      headers: {
        'Authorization': 'Bearer ${ApiConfig.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'version': modelVersion,
        'input': {'prompt': prompt, ...extraInput},
      }),
    );
    if (res.statusCode != 201) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Failed to create prediction');
    }
    final data = jsonDecode(res.body) as Map;
    return data['urls']['get'] as String;
  }

  /// Polls until succeeded/failed/cancelled. Calls onStatus for UI updates.
  Future<String> pollUntilDone(
      String pollUrl, {
        required void Function(String) onStatus,
        int maxRetries = 120,
      }) async {
    for (int i = 0; i < maxRetries; i++) {
      if (_cancelled) throw Exception('cancelled');
      await Future.delayed(const Duration(seconds: 2));
      if (_cancelled) throw Exception('cancelled');

      final res = await _client.get(
        Uri.parse(pollUrl),
        headers: {'Authorization': 'Bearer ${ApiConfig.apiKey}'},
      );
      if (res.statusCode != 200) continue;

      final data   = jsonDecode(res.body) as Map;
      final status = data['status'] as String;
      onStatus(status);

      if (status == 'succeeded') {
        final output = data['output'];
        return output is List ? output.first as String : output as String;
      } else if (status == 'failed' || status == 'canceled') {
        final errMsg = data['error'] ?? 'unknown error';
        throw Exception('Prediction $status: $errMsg');
      }
    }
    throw Exception('Timed out after ${maxRetries * 2}s');
  }

  void dispose() => _client.close();
}

// ═══════════════════════════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════════════════════════
class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg0,
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEBULA BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════
class NebulaBackground extends StatefulWidget {
  const NebulaBackground({super.key});
  @override State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(painter: _NebulaPainter(_ctrl.value), size: Size.infinite),
    ),
  );
}

class _NebulaPainter extends CustomPainter {
  final double t;
  _NebulaPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, size,
        cx: size.width * (0.28 + 0.12 * math.sin(t * math.pi * 2)),
        cy: size.height * (0.18 + 0.06 * math.cos(t * math.pi * 1.3)),
        r: size.width * 0.75, color: const Color(0xFF1A0844), opacity: 0.38);
    _draw(canvas, size,
        cx: size.width * (0.82 - 0.09 * math.sin(t * math.pi * 2)),
        cy: size.height * (0.62 + 0.07 * math.cos(t * math.pi * 1.7)),
        r: size.width * 0.62, color: const Color(0xFF0D0A30), opacity: 0.42);
    _draw(canvas, size,
        cx: size.width * (0.92 + 0.05 * math.cos(t * math.pi * 1.5)),
        cy: size.height * (0.08 + 0.04 * math.sin(t * math.pi * 2.2)),
        r: size.width * 0.38, color: const Color(0xFF300818), opacity: 0.32);
    _draw(canvas, size,
        cx: size.width * (0.04 + 0.04 * math.sin(t * math.pi * 1.8)),
        cy: size.height * (0.88 + 0.03 * math.cos(t * math.pi * 2.4)),
        r: size.width * 0.32, color: const Color(0xFF041818), opacity: 0.28);
    // Extra deep violet bloom
    _draw(canvas, size,
        cx: size.width * (0.5 + 0.06 * math.sin(t * math.pi * 0.9)),
        cy: size.height * (0.5 + 0.04 * math.cos(t * math.pi * 1.1)),
        r: size.width * 0.5, color: const Color(0xFF0A0630), opacity: 0.18);
  }

  void _draw(Canvas c, Size s, {
    required double cx, required double cy, required double r,
    required Color color, required double opacity,
  }) {
    final p = Paint()..shader = RadialGradient(
      colors: [color.withOpacity(opacity), color.withOpacity(0)],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), p);
  }

  @override
  bool shouldRepaint(_NebulaPainter o) => o.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
// STAR FIELD
// ═══════════════════════════════════════════════════════════════════════════
class StarField extends StatefulWidget {
  const StarField({super.key});
  @override State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rand = math.Random(42);
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(160, (i) => _Star(_rand, i));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _StarPainter(_stars, _ctrl.value),
        size: Size.infinite,
      ),
    ),
  );
}

class _Star {
  final double x, y, size, speed, opacity, phase;
  final bool isGlow, isBright;
  _Star(math.Random r, int i)
      : x = r.nextDouble(), y = r.nextDouble(),
        size = r.nextDouble() * 2.4 + 0.2,
        speed = r.nextDouble() * 0.4 + 0.06,
        opacity = r.nextDouble() * 0.75 + 0.15,
        phase = r.nextDouble() * math.pi * 2,
        isGlow   = i % 10 == 0,
        isBright = i % 25 == 0;
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final flicker = (math.sin(t * math.pi * 2 * s.speed + s.phase) + 1) / 2;
      final alpha = s.opacity * (0.45 + flicker * 0.55);
      final x = s.x * size.width;
      final y = s.y * size.height;

      if (s.isBright) {
        final gp = Paint()..shader = RadialGradient(
          colors: [_electricBright.withOpacity(alpha * 0.5), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: s.size * 6));
        canvas.drawCircle(Offset(x, y), s.size * 6, gp);
      } else if (s.isGlow) {
        final gp = Paint()..shader = RadialGradient(
          colors: [Colors.white.withOpacity(alpha * 0.55), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: s.size * 4));
        canvas.drawCircle(Offset(x, y), s.size * 4, gp);
      }

      final p = Paint()..color = s.isBright
          ? _electricBright.withOpacity(alpha)
          : s.isGlow
          ? const Color(0xFFD4D0FF).withOpacity(alpha)
          : Colors.white.withOpacity(alpha * 0.8);
      canvas.drawCircle(Offset(x, y), s.size, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter o) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// NOISE OVERLAY — subtle film grain for premium glass depth
// ═══════════════════════════════════════════════════════════════════════════
class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _NoisePainter(), size: Size.infinite),
  );
}

class _NoisePainter extends CustomPainter {
  final _rand = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..strokeWidth = 0.5;
    for (int i = 0; i < 1200; i++) {
      final x = _rand.nextDouble() * size.width;
      final y = _rand.nextDouble() * size.height;
      p.color = Colors.white.withOpacity(_rand.nextDouble() * 0.025);
      canvas.drawCircle(Offset(x, y), 0.4, p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════
class GlassPane extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double sigma;
  final Color? tint;
  final double borderWidth;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  const GlassPane({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.sigma = 28,
    this.tint,
    this.borderWidth = 0.6,
    this.borderColor,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tint ?? _glass3).withOpacity(0.14),
                (tint ?? _glass1).withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? _border1,
              width: borderWidth,
            ),
            boxShadow: shadows ?? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _electric.withOpacity(0.03),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassBorderPane extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Gradient borderGradient;
  final double borderWidth;

  const GlassBorderPane({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.borderGradient = accentGrad,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient,
        boxShadow: [
          BoxShadow(
            color: _electric.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1C080820), Color(0x12040410)],
              ),
              borderRadius: BorderRadius.circular(radius - borderWidth),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOVA APP BAR — Ultra premium frosted glass, deeper blur, inner glow
// ═══════════════════════════════════════════════════════════════════════════
class NovaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final ValueNotifier<double>? scrollNotifier;

  const NovaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.scrollNotifier,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final notifier = scrollNotifier ?? ValueNotifier(0.0);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: notifier,
        builder: (context, _) {
          final scrollT  = (notifier.value / 60.0).clamp(0.0, 1.0);
          final easedT   = Curves.easeOutCubic.transform(scrollT);
          final blurSigma    = lerpDouble(48.0, 90.0, easedT)!;
          final tintOpacity  = lerpDouble(0.50, 0.92, easedT)!;
          final glowOpacity  = lerpDouble(0.08, 0.28, easedT)!;
          final topFadeOp    = lerpDouble(0.0, 0.55, easedT)!;
          final innerGlowOp  = lerpDouble(0.03, 0.10, easedT)!;

          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Stack(
                children: [
                  // Base deep tint
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          _bg0.withOpacity(tintOpacity),
                          _bg0.withOpacity(tintOpacity * 0.80),
                          _bg0.withOpacity(tintOpacity * 0.45),
                        ],
                      ),
                    ),
                  ),

                  // Violet depth layer
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _violet.withOpacity(0.05 * easedT),
                          _electric.withOpacity(0.03 * easedT),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Inner top reflection (specular highlight)
                  Positioned(
                    top: 0, left: 0, right: 0, height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(innerGlowOp * 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top status bar fade
                  if (topFadeOp > 0)
                    Positioned(
                      top: 0, left: 0, right: 0, height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(topFadeOp * 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                  // AppBar content
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: leading,
                    title: ShaderMask(
                      shaderCallback: (bounds) => accentGrad.createShader(bounds),
                      child: Text(
                        title,
                        style: GoogleFonts.spaceMono(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    actions: actions,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Multi-layer hairline separator
                          Container(
                            height: 0.6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _border2.withOpacity(0.4 + glowOpacity),
                                  _electric.withOpacity(glowOpacity * 0.6),
                                  _electricBright.withOpacity(glowOpacity * 0.3),
                                  _electric.withOpacity(glowOpacity * 0.6),
                                  _border2.withOpacity(0.4 + glowOpacity),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.15, 0.35, 0.5, 0.65, 0.85, 1.0],
                              ),
                            ),
                          ),
                          // Glow diffuse below hairline
                          Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _electric.withOpacity(glowOpacity * 0.14),
                                  _violet.withOpacity(glowOpacity * 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.3, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHELL
// ═══════════════════════════════════════════════════════════════════════════
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _idx = 0;
  final _scrollNotifier = ValueNotifier<double>(0.0);

  @override
  void dispose() { _scrollNotifier.dispose(); super.dispose(); }

  void _nav(int i) => setState(() => _idx = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _nav, scrollNotifier: _scrollNotifier),
      GeneratorScreen(scrollNotifier: _scrollNotifier),
      ExploreScreen(scrollNotifier: _scrollNotifier),
      GalleryScreen(scrollNotifier: _scrollNotifier),
      ProfileScreen(scrollNotifier: _scrollNotifier),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: _bgGrad)),
          const NebulaBackground(),
          const StarField(),
          Opacity(
            opacity: 0.012,
            child: const NoiseOverlay(),
          ),
          Opacity(
            opacity: 0.018,
            child: RepaintBoundary(
              child: CustomPaint(painter: _ScanLinePainter(), size: Size.infinite),
            ),
          ),
          IndexedStack(index: _idx, children: screens),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _idx,
        onTap: _nav,
        scrollNotifier: _scrollNotifier,
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white..strokeWidth = 0.4;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAV — Ultra deep glass dock, specular inner reflection
// ═══════════════════════════════════════════════════════════════════════════
class _BottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final ValueNotifier<double> scrollNotifier;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.scrollNotifier,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> with TickerProviderStateMixin {
  late List<AnimationController> _scaleCtrl;
  late List<Animation<double>> _scaleAnim;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.auto_fix_high_rounded, Icons.auto_fix_normal_outlined, 'Create'),
    (Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
    (Icons.photo_library_rounded, Icons.photo_library_outlined, 'Gallery'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _scaleCtrl = List.generate(_items.length, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: i == widget.currentIndex ? 1.0 : 0.0,
    ));
    _scaleAnim = _scaleCtrl.map((c) => Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: c, curve: Curves.elasticOut))).toList();
  }

  @override
  void didUpdateWidget(_BottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _scaleCtrl[old.currentIndex].reverse();
      _scaleCtrl[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() { for (final c in _scaleCtrl) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.scrollNotifier,
        builder: (context, _) {
          final scrollT  = (widget.scrollNotifier.value / 60.0).clamp(0.0, 1.0);
          final easedT   = Curves.easeOutCubic.transform(scrollT);
          final blur     = lerpDouble(44.0, 80.0, easedT)!;
          final tintOp   = lerpDouble(0.13, 0.48, easedT)!;
          final borderOp = lerpDouble(0.07, 0.22, easedT)!;
          final shadowOp = lerpDouble(0.42, 0.72, easedT)!;
          final elevSc   = lerpDouble(1.0, 1.14, easedT)!;

          return Padding(
            padding: EdgeInsets.only(
              left: 18, right: 18,
              bottom: bottomPad + 14,
              top: 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 1.0],
                      colors: [
                        const Color(0xFF0A0A22).withOpacity(tintOp * 0.65),
                        const Color(0xFF080820).withOpacity(tintOp),
                        const Color(0xFF040412).withOpacity(tintOp * 1.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withOpacity(borderOp),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(shadowOp),
                        blurRadius: 32 * elevSc,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: _electric.withOpacity(0.04 + easedT * 0.05),
                        blurRadius: 44,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.025 + easedT * 0.02),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Top specular reflection
                      Positioned(
                        top: 0, left: 14, right: 14,
                        child: Container(
                          height: 0.7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.14 + easedT * 0.12),
                                _electricBright.withOpacity(0.08 + easedT * 0.07),
                                Colors.white.withOpacity(0.14 + easedT * 0.12),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Inner light reflection (lens effect)
                      Positioned(
                        top: 0, left: 0, right: 0, height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.025 + easedT * 0.02),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(34),
                              topRight: Radius.circular(34),
                            ),
                          ),
                        ),
                      ),
                      // Bottom fade
                      Positioned(
                        bottom: 0, left: 0, right: 0, height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.10 + easedT * 0.07),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(34),
                              bottomRight: Radius.circular(34),
                            ),
                          ),
                        ),
                      ),
                      // Nav items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(_items.length, (i) => _NavItem(
                          index: i,
                          currentIndex: widget.currentIndex,
                          item: _items[i],
                          scaleAnimation: _scaleAnim[i],
                          onTap: widget.onTap,
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index, currentIndex;
  final (IconData, IconData, String) item;
  final Animation<double> scaleAnimation;
  final Function(int) onTap;

  const _NavItem({
    required this.index, required this.currentIndex,
    required this.item, required this.scaleAnimation, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62, height: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: scaleAnimation,
              builder: (_, __) {
                final springScale = 1.0 + scaleAnimation.value * 0.14;
                return Transform.scale(
                  scale: springScale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: sel ? accentGrad : null,
                      color: sel ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: sel ? [
                        BoxShadow(color: _electric.withOpacity(0.50), blurRadius: 20),
                        BoxShadow(color: _violet.withOpacity(0.22), blurRadius: 36, spreadRadius: 4),
                      ] : null,
                    ),
                    child: Icon(
                      sel ? item.$1 : item.$2,
                      color: sel ? Colors.white : Colors.white.withOpacity(0.22),
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: GoogleFonts.dmSans(
                color: sel ? _electricBright : Colors.white.withOpacity(0.20),
                fontSize: 9.5,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: sel ? 0.3 : 0,
              ),
              child: Text(item.$3),
            ),
            AnimatedBuilder(
              animation: scaleAnimation,
              builder: (_, __) {
                final op = scaleAnimation.value.clamp(0.0, 1.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(top: 3),
                  width: sel ? 18 * op : 0,
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _electric.withOpacity(op),
                        _electricBright.withOpacity(op),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: sel ? [
                      BoxShadow(color: _electric.withOpacity(0.65 * op), blurRadius: 8),
                    ] : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _coreCtrl, _ringCtrl, _textCtrl, _tagCtrl;

  @override
  void initState() {
    super.initState();
    _coreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _tagCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _coreCtrl.forward();
    Future.delayed(const Duration(milliseconds: 700), _textCtrl.forward);
    Future.delayed(const Duration(milliseconds: 1000), _tagCtrl.forward);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const Shell(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 900),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _coreCtrl.dispose(); _ringCtrl.dispose();
    _textCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coreScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _coreCtrl, curve: Curves.elasticOut));
    final coreFade  = CurvedAnimation(parent: _coreCtrl, curve: Curves.easeOut);
    final textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    final textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutExpo));
    final tagFade   = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);

    return Scaffold(
      backgroundColor: _bg0,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: _bgGrad)),
          const NebulaBackground(),
          const StarField(),
          Opacity(opacity: 0.012, child: const NoiseOverlay()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: coreFade,
                  child: ScaleTransition(
                    scale: coreScale,
                    child: SizedBox(
                      width: 190, height: 1.05,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient glow pulse
                          AnimatedBuilder(
                            animation: _ringCtrl,
                            builder: (_, __) => Container(
                              width: 190, height: 1.05,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _electric.withOpacity(
                                        0.12 + 0.10 * math.sin(_ringCtrl.value * math.pi * 2)),
                                    blurRadius: 70, spreadRadius: 22,
                                  ),
                                  BoxShadow(
                                    color: _violet.withOpacity(
                                        0.06 + 0.05 * math.cos(_ringCtrl.value * math.pi * 2)),
                                    blurRadius: 100, spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _ringCtrl,
                            builder: (_, __) => Transform.rotate(
                              angle: _ringCtrl.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(175, 175),
                                painter: _ArcRingPainter(
                                  primaryColor: _electric, secondaryColor: _violet,
                                  count: 3, strokeWidth: 1.8,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _ringCtrl,
                            builder: (_, __) => Transform.rotate(
                              angle: -_ringCtrl.value * 2 * math.pi * 0.7,
                              child: CustomPaint(
                                size: const Size(132, 132),
                                painter: _ArcRingPainter(
                                  primaryColor: _rose, secondaryColor: _amber,
                                  count: 5, strokeWidth: 1.1,
                                ),
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _ringCtrl,
                            builder: (_, __) => Transform.rotate(
                              angle: _ringCtrl.value * 2 * math.pi * 0.4,
                              child: CustomPaint(
                                size: const Size(98, 98),
                                painter: _DottedRingPainter(color: _teal.withOpacity(0.55), dots: 14),
                              ),
                            ),
                          ),
                          Container(
                            width: 78, height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_electricBright, _electric, _violet, _violetDeep],
                                stops: [0.0, 0.35, 0.7, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(color: _electric.withOpacity(0.65), blurRadius: 44, spreadRadius: 10),
                                BoxShadow(color: _violet.withOpacity(0.42), blurRadius: 80, spreadRadius: 18),
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                SlideTransition(
                  position: textSlide,
                  child: FadeTransition(
                    opacity: textFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [_glow, _electricBright, _electric],
                          ).createShader(b),
                          child: Text(
                            'NOVA',
                            style: GoogleFonts.spaceMono(
                              fontSize: 58, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FadeTransition(
                          opacity: tagFade,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: _electric.withOpacity(0.35), width: 0.6),
                              borderRadius: BorderRadius.circular(32),
                              color: _electric.withOpacity(0.07),
                            ),
                            child: Text(
                              'AI CREATIVE STUDIO',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10, color: _electric.withOpacity(0.9),
                                letterSpacing: 7, fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 76),
                FadeTransition(
                  opacity: tagFade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withOpacity(0.04),
                            valueColor: AlwaysStoppedAnimation(_electric.withOpacity(0.75)),
                            minHeight: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Initializing…',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.18), fontSize: 9, letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color primaryColor, secondaryColor;
  final int count;
  final double strokeWidth;
  _ArcRingPainter({required this.primaryColor, required this.secondaryColor,
    required this.count, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep  = (math.pi * 2 / count) * 0.55;
    for (int i = 0; i < count; i++) {
      final start = (math.pi * 2 / count) * i;
      final t     = i / count;
      final color = Color.lerp(primaryColor, secondaryColor, t)!;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start, endAngle: start + sweep,
          colors: [color.withOpacity(0.0), color.withOpacity(0.9), color.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        start, sweep, false, paint,
      );
    }
  }

  @override bool shouldRepaint(_) => false;
}

class _DottedRingPainter extends CustomPainter {
  final Color color;
  final int dots;
  _DottedRingPainter({required this.color, required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint  = Paint()..color = color;
    for (int i = 0; i < dots; i++) {
      final angle = (math.pi * 2 / dots) * i;
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
        1.6, paint,
      );
    }
  }

  @override bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// FADE SLIDE WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class _FadeSlide extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeSlide({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
          .animate(animation),
      child: child,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3, height: 11,
        decoration: BoxDecoration(gradient: accentGrad, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: GoogleFonts.spaceMono(
          color: Colors.white.withOpacity(0.22),
          fontSize: 9.5, letterSpacing: 3.5, fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          height: 0.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white.withOpacity(0.08), Colors.transparent]),
          ),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME SCREEN — Dynamic stats, live feed, recent generations
// ═══════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final ValueNotifier<double> scrollNotifier;

  const HomeScreen({super.key, required this.onNavigate, required this.scrollNotifier});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _staggerCtrl, _pulseCtrl, _liveCtrl;
  final _scrollCtrl = ScrollController();
  final _storage = LocalStorageService();
  final _api     = ApiService();

  List<GenerationItem> _recentItems = [];
  Map<String, int> _stats = {'images': 0, 'videos': 0, 'total': 0};
  bool _apiHealthy = false;
  bool _checkingHealth = true;
  int _liveActivityCount = 0;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseCtrl   = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _liveCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    Future.delayed(const Duration(milliseconds: 80), _staggerCtrl.forward);

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) widget.scrollNotifier.value = _scrollCtrl.offset;
    });

    _loadData();
    _simulateLiveActivity();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose(); _pulseCtrl.dispose(); _liveCtrl.dispose();
    _scrollCtrl.dispose(); _liveTimer?.cancel(); _api.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final items = await _storage.loadGallery();
    final stats = await _storage.loadStats();
    final healthy = await _api.checkHealth();
    if (mounted) {
      setState(() {
        _recentItems     = items.take(5).toList();
        _stats           = stats;
        _apiHealthy      = healthy;
        _checkingHealth  = false;
      });
    }
  }

  void _simulateLiveActivity() {
    _liveTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _liveActivityCount++);
      _liveCtrl.forward(from: 0);
    });
  }

  Animation<double> _s(int i) => CurvedAnimation(
    parent: _staggerCtrl,
    curve: Interval(i * 0.09, math.min(i * 0.09 + 0.5, 1.0), curve: Curves.easeOutExpo),
  );

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning'
        : now.hour < 18 ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NovaAppBar(
        title: 'NOVA',
        scrollNotifier: widget.scrollNotifier,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => widget.onNavigate(4),
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: accentGrad,
                    boxShadow: [
                      BoxShadow(
                        color: _electric.withOpacity(0.20 + _pulseCtrl.value * 0.18),
                        blurRadius: 14 + _pulseCtrl.value * 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: _electric,
        backgroundColor: _bg2,
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Greeting ────────────────────────────────────────────
                _FadeSlide(
                  animation: _s(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(greeting, style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.35), fontSize: 14, letterSpacing: 0.3,
                      )),
                      const SizedBox(height: 4),
                      RichText(text: TextSpan(children: [
                        TextSpan(
                          text: 'Create ',
                          style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: 'something\nremarkable.',
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withOpacity(0.28), fontSize: 32,
                            fontWeight: FontWeight.w300, height: 1.1,
                          ),
                        ),
                      ])),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── API Status ───────────────────────────────────────────
                _FadeSlide(
                  animation: _s(1),
                  child: _ApiStatusBar(
                    healthy: _apiHealthy,
                    checking: _checkingHealth,
                    pulseCtrl: _pulseCtrl,
                    onRetry: _loadData,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Live Activity Feed ───────────────────────────────────
                _FadeSlide(
                  animation: _s(1),
                  child: _LiveActivityBanner(
                    count: _liveActivityCount,
                    animCtrl: _liveCtrl,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Dynamic Stats ────────────────────────────────────────
                _FadeSlide(animation: _s(2), child: const _SectionLabel('YOUR STATS')),
                const SizedBox(height: 12),
                _FadeSlide(
                  animation: _s(2),
                  child: _StatsRow(stats: _stats),
                ),

                const SizedBox(height: 28),

                // ── Quick Create ─────────────────────────────────────────
                _FadeSlide(animation: _s(3), child: const _SectionLabel('QUICK CREATE')),
                const SizedBox(height: 14),
                _FadeSlide(
                  animation: _s(3),
                  child: _HeroCard(
                    label: 'IMAGE', title: 'Generate\nPhoto', subtitle: 'Stability SDXL',
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF1C0F52), Color(0xFF0E0830), Color(0xFF060520)],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    accentColor: _electric, accentGradient: accentGrad,
                    icon: Icons.image_rounded, onTap: () => widget.onNavigate(1),
                  ),
                ),
                const SizedBox(height: 12),
                _FadeSlide(
                  animation: _s(4),
                  child: _HeroCard(
                    label: 'VIDEO', title: 'Generate\nVideo', subtitle: 'Zeroscope v2 XL',
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF3A0B1A), Color(0xFF200810), Color(0xFF110408)],
                      stops: [0.0, 0.6, 1.0],
                    ),
                    accentColor: _rose, accentGradient: _roseGrad,
                    icon: Icons.videocam_rounded, onTap: () => widget.onNavigate(1),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Recent Creations ─────────────────────────────────────
                if (_recentItems.isNotEmpty) ...[
                  _FadeSlide(animation: _s(5), child: Row(
                    children: [
                      const _SectionLabel('RECENT'),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => widget.onNavigate(3),
                        child: Text(
                          'See all →',
                          style: GoogleFonts.dmSans(
                            color: _electric.withOpacity(0.6), fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(height: 14),
                  _FadeSlide(
                    animation: _s(5),
                    child: _RecentStrip(items: _recentItems, onTapAll: () => widget.onNavigate(3)),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Platform ─────────────────────────────────────────────
                _FadeSlide(animation: _s(6), child: const _SectionLabel('PLATFORM')),
                const SizedBox(height: 14),
                _FadeSlide(
                  animation: _s(6),
                  child: Row(
                    children: [
                      Expanded(child: _MiniStatCard('Models', '2', Icons.memory_rounded, _electric)),
                      const SizedBox(width: 10),
                      Expanded(child: _MiniStatCard('Quality', '4K', Icons.hd_rounded, _teal)),
                      const SizedBox(width: 10),
                      Expanded(child: _MiniStatCard('Speed', 'Fast', Icons.bolt_rounded, _amber)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Discover ─────────────────────────────────────────────
                _FadeSlide(animation: _s(7), child: const _SectionLabel('DISCOVER')),
                const SizedBox(height: 14),
                _FadeSlide(
                  animation: _s(7),
                  child: GestureDetector(
                    onTap: () => widget.onNavigate(2),
                    child: GlassBorderPane(
                      borderGradient: _tealGrad,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              gradient: _tealGrad, borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: _teal.withOpacity(0.35), blurRadius: 16)],
                            ),
                            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Explore AI Styles', style: GoogleFonts.dmSans(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                                )),
                                Text('Browse trending prompts & techniques', style: GoogleFonts.dmSans(
                                  color: Colors.white.withOpacity(0.38), fontSize: 12,
                                )),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.north_east_rounded, color: _teal, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── API Status Bar ──────────────────────────────────────────────────────────
class _ApiStatusBar extends StatelessWidget {
  final bool healthy, checking;
  final AnimationController pulseCtrl;
  final VoidCallback onRetry;

  const _ApiStatusBar({
    required this.healthy, required this.checking,
    required this.pulseCtrl, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = checking ? _amber : (healthy ? _emerald : _rose);
    final statusLabel = checking ? 'Checking…' : (healthy ? 'Connected' : 'Offline');

    return GlassPane(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      radius: 18,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: statusColor, shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(checking ? 0.5 : 0.6 + pulseCtrl.value * 0.35),
                    blurRadius: 7 + pulseCtrl.value * 5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('Replicate API', style: GoogleFonts.dmSans(
            color: Colors.white.withOpacity(0.50), fontSize: 12, fontWeight: FontWeight.w500,
          )),
          const SizedBox(width: 6),
          Text('·', style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 14)),
          const SizedBox(width: 6),
          Text(statusLabel, style: GoogleFonts.dmSans(
            color: healthy ? _emeraldBright : statusColor,
            fontSize: 12, fontWeight: FontWeight.w700,
          )),
          const Spacer(),
          if (!checking && !healthy)
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _rose.withOpacity(0.25), width: 0.5),
                ),
                child: Text('Retry', style: GoogleFonts.dmSans(color: _rose, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _electric.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _electric.withOpacity(0.15), width: 0.5),
              ),
              child: Text('SDXL · Zeroscope', style: GoogleFonts.spaceMono(
                color: Colors.white.withOpacity(0.25), fontSize: 9,
              )),
            ),
        ],
      ),
    );
  }
}

// ── Live Activity Banner ─────────────────────────────────────────────────────
class _LiveActivityBanner extends StatelessWidget {
  final int count;
  final AnimationController animCtrl;

  const _LiveActivityBanner({required this.count, required this.animCtrl});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final activities = [
      'New image generated · Neon Noir style',
      'Video created · Golden Hour prompt',
      'Image saved to gallery · Portrait style',
      'Quantum Dreams generated',
      'Bioluminescent scene created',
    ];
    final msg = activities[count % activities.length];

    return FadeTransition(
      opacity: CurvedAnimation(parent: animCtrl, curve: Curves.easeOut),
      child: GlassPane(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        radius: 14,
        tint: _emerald.withOpacity(0.04),
        borderColor: _emerald.withOpacity(0.15),
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _emerald, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _emerald.withOpacity(0.6), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 10),
            Text('LIVE', style: GoogleFonts.spaceMono(
              color: _emerald, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2,
            )),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.45), fontSize: 11,
            ), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(
          label: 'Images', value: '${stats['images'] ?? 0}',
          icon: Icons.image_rounded, color: _electric,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(
          label: 'Videos', value: '${stats['videos'] ?? 0}',
          icon: Icons.videocam_rounded, color: _rose,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(
          label: 'Total', value: '${stats['total'] ?? 0}',
          icon: Icons.auto_awesome_rounded, color: _amber,
        )),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => GlassPane(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.spaceMono(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.30), fontSize: 11)),
      ],
    ),
  );
}

// ── Recent Strip ───────────────────────────────────────────────────────────
class _RecentStrip extends StatelessWidget {
  final List<GenerationItem> items;
  final VoidCallback onTapAll;

  const _RecentStrip({required this.items, required this.onTapAll});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.05,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.type == 'image'
                      ? Image.network(item.url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _glass1,
                        child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
                      ))
                      : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A0510), Color(0xFF080210)],
                      ),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white24, size: 28),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6, left: 6, right: 6,
                    child: Text(
                      item.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.65), fontSize: 8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Mini Stat Card ─────────────────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => GlassPane(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.spaceMono(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.30), fontSize: 11)),
      ],
    ),
  );
}

// ── Hero Card ──────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final String label, title, subtitle;
  final LinearGradient gradient;
  final Color accentColor;
  final LinearGradient accentGradient;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroCard({
    required this.label, required this.title, required this.subtitle,
    required this.gradient, required this.accentColor, required this.accentGradient,
    required this.icon, required this.onTap,
  });

  @override State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180)); }
  @override void dispose()   { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
    onTapCancel: () => _ctrl.reverse(),
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: 1.0 - _ctrl.value * 0.025,
        child: Container(
          height: 1.05,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.accentColor.withOpacity(0.20 + _ctrl.value * 0.15), width: 0.6),
            boxShadow: [
              BoxShadow(color: widget.accentColor.withOpacity(0.22 - _ctrl.value * 0.05), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -28, top: -28,
                  child: Container(
                    width: 165, height: 165,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [widget.accentColor.withOpacity(0.10), Colors.transparent]),
                    ),
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0,
                  child: Container(
                    height: 0.6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent, widget.accentColor.withOpacity(0.35), Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    widget.accentColor.withOpacity(0.20),
                                    widget.accentColor.withOpacity(0.08),
                                  ]),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(color: widget.accentColor.withOpacity(0.32), width: 0.5),
                                ),
                                child: Text(widget.label, style: GoogleFonts.spaceMono(
                                  color: widget.accentColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2,
                                )),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.05)),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(widget.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          gradient: widget.accentGradient, borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: widget.accentColor.withOpacity(0.38), blurRadius: 20)],
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// GENERATOR SCREEN — Full state machine, cancel, regenerate, AI core anim
// ═══════════════════════════════════════════════════════════════════════════
enum GenType { image, video }

class GeneratorScreen extends StatefulWidget {
  final ValueNotifier<double> scrollNotifier;
  const GeneratorScreen({super.key, required this.scrollNotifier});
  @override State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with TickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _storage    = LocalStorageService();
  final _api        = ApiService();

  GenType _type = GenType.image;
  GenerationState _state = GenerationState.idle;
  String _statusText = '';
  String? _resultUrl, _error;
  late AnimationController _pulseCtrl, _coreCtrl, _orbitalCtrl;
  VideoPlayerController? _vpCtrl;
  double _guidanceScale = 7.5;
  int _steps = 30;
  bool _showAdvanced = false;

  List<String> _promptHistory = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _coreCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _orbitalCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) widget.scrollNotifier.value = _scrollCtrl.offset;
    });

    _loadPromptHistory();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose(); _coreCtrl.dispose(); _orbitalCtrl.dispose();
    _promptCtrl.dispose(); _scrollCtrl.dispose();
    _vpCtrl?.dispose(); _api.dispose();
    super.dispose();
  }

  Future<void> _loadPromptHistory() async {
    final h = await _storage.loadPromptHistory();
    if (mounted) setState(() => _promptHistory = h);
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Please enter a prompt to generate');
      return;
    }

    _api.reset();
    setState(() {
      _state      = GenerationState.queued;
      _statusText = 'Queued…';
      _resultUrl  = null;
      _error      = null;
    });

    await _storage.addPromptToHistory(prompt);
    await _loadPromptHistory();

    try {
      final modelVersion = _type == GenType.image
          ? ApiConfig.imageVersion
          : ApiConfig.videoVersion;

      final extraInput = _type == GenType.image
          ? {'guidance_scale': _guidanceScale, 'num_inference_steps': _steps}
          : <String, dynamic>{};

      setState(() { _state = GenerationState.queued; _statusText = 'Creating prediction…'; });

      final pollUrl = await _api.createPrediction(
        prompt: prompt,
        modelVersion: modelVersion,
        extraInput: extraInput,
      );

      setState(() { _state = GenerationState.processing; _statusText = 'Processing…'; });

      final resultUrl = await _api.pollUntilDone(
        pollUrl,
        onStatus: (s) {
          if (mounted) setState(() { _statusText = s; });
        },
      );

      if (_type == GenType.image) {
        setState(() { _state = GenerationState.succeeded; _resultUrl = resultUrl; });
      } else {
        await _initVideo(resultUrl);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('cancelled')) {
        setState(() { _state = GenerationState.cancelled; _error = null; });
      } else {
        setState(() { _state = GenerationState.failed; _error = msg.replaceFirst('Exception: ', ''); });
      }
    }
  }

  void _cancel() {
    _api.cancel();
    setState(() {
      _state      = GenerationState.cancelled;
      _statusText = 'Cancelled';
      _error      = null;
    });
  }

  void _regenerate() {
    _api.reset();
    _generate();
  }

  void _reset() {
    setState(() {
      _state     = GenerationState.idle;
      _resultUrl = null;
      _error     = null;
      _statusText = '';
    });
    _vpCtrl?.dispose();
    _vpCtrl = null;
  }

  Future<void> _initVideo(String url) async {
    _vpCtrl?.dispose();
    _vpCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _vpCtrl!.initialize();
    await _vpCtrl!.setLooping(true);
    await _vpCtrl!.play();
    if (mounted) setState(() { _state = GenerationState.succeeded; _resultUrl = url; });
  }

  Future<void> _save() async {
    if (_resultUrl == null) return;
    final item = GenerationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: _resultUrl!,
      type: _type == GenType.image ? 'image' : 'video',
      prompt: _promptCtrl.text,
      createdAt: DateTime.now(),
    );
    await _storage.saveItem(item);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Text('Saved to Gallery', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF2A2050),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NovaAppBar(title: 'CREATE', scrollNotifier: widget.scrollNotifier),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Type toggle ───────────────────────────────────────────
              GlassPane(
                padding: const EdgeInsets.all(5),
                radius: 20,
                child: Row(children: [
                  _typeBtn(GenType.image, Icons.image_rounded, 'Photo', _electric, accentGrad),
                  _typeBtn(GenType.video, Icons.videocam_rounded, 'Video', _rose, _roseGrad),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Prompt field ──────────────────────────────────────────
              GlassPane(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('PROMPT', style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.22), fontSize: 9, letterSpacing: 2,
                        )),
                        const Spacer(),
                        // History toggle
                        if (_promptHistory.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _showHistory = !_showHistory),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _violet.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _violet.withOpacity(0.22), width: 0.5),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.history_rounded, color: _violet, size: 11),
                                const SizedBox(width: 4),
                                Text('History', style: GoogleFonts.dmSans(
                                  color: _violet, fontSize: 11, fontWeight: FontWeight.w600,
                                )),
                              ]),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_type == GenType.image ? _electric : _rose).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_type == GenType.image ? _electric : _rose).withOpacity(0.22),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _type == GenType.image ? 'Image Mode' : 'Video Mode',
                            style: GoogleFonts.dmSans(
                              color: _type == GenType.image ? _electric : _rose,
                              fontSize: 11, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // History dropdown
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: _showHistory && _promptHistory.isNotEmpty
                          ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          ...(_promptHistory.take(5).map((h) => GestureDetector(
                            onTap: () {
                              _promptCtrl.text = h;
                              setState(() => _showHistory = false);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: _glass2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border2, width: 0.5),
                              ),
                              child: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                            ),
                          ))),
                        ],
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptCtrl,
                      maxLines: 4,
                      enabled: !_state.isActive,
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, height: 1.55),
                      decoration: InputDecoration(
                        hintText: _type == GenType.image
                            ? 'A futuristic city at sunset, cinematic 8K…'
                            : 'Ocean waves at golden hour, timelapse…',
                        hintStyle: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.16), fontSize: 13,
                        ),
                        border: InputBorder.none,
                      ),
                    ),

                    // Char count
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_promptCtrl.text.length} chars',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.12), fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Advanced settings ─────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: GlassPane(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  radius: 16,
                  child: Row(children: [
                    Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.4), size: 16),
                    const SizedBox(width: 10),
                    Text('Advanced Settings', style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.50), fontSize: 13, fontWeight: FontWeight.w500,
                    )),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _showAdvanced ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.25), size: 18),
                    ),
                  ]),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _showAdvanced
                    ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GlassPane(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _SliderRow(
                        label: 'Guidance Scale', value: _guidanceScale,
                        min: 1, max: 20, divisions: 38, color: _electric,
                        displayValue: _guidanceScale.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _guidanceScale = v),
                      ),
                      const SizedBox(height: 14),
                      _SliderRow(
                        label: 'Inference Steps', value: _steps.toDouble(),
                        min: 10, max: 50, divisions: 40, color: _teal,
                        displayValue: '$_steps',
                        onChanged: (v) => setState(() => _steps = v.round()),
                      ),
                    ]),
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 14),

              // ── AI Core animation (shown during processing) ───────────
              if (_state.isActive) ...[
                _AiCoreAnimation(
                  state: _state,
                  statusText: _statusText,
                  coreCtrl: _coreCtrl,
                  orbitalCtrl: _orbitalCtrl,
                  pulseCtrl: _pulseCtrl,
                  type: _type,
                ),
                const SizedBox(height: 14),
              ],

              // ── Generate / Cancel / Regenerate buttons ────────────────
              _ActionButtons(
                state: _state,
                type: _type,
                onGenerate: _generate,
                onCancel: _cancel,
                onRegenerate: _regenerate,
                onReset: _reset,
              ),

              // ── Error ─────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                GlassPane(
                  tint: _rose.withOpacity(0.07),
                  borderColor: _rose.withOpacity(0.22),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: _rose, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: GoogleFonts.dmSans(color: _rose, fontSize: 12))),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: Icon(Icons.close_rounded, color: _rose.withOpacity(0.5), size: 16),
                    ),
                  ]),
                ),
              ],

              // ── Cancelled state ───────────────────────────────────────
              if (_state == GenerationState.cancelled) ...[
                const SizedBox(height: 14),
                GlassPane(
                  tint: _amber.withOpacity(0.05),
                  borderColor: _amber.withOpacity(0.18),
                  child: Row(children: [
                    Icon(Icons.cancel_outlined, color: _amber, size: 18),
                    const SizedBox(width: 10),
                    Text('Generation cancelled', style: GoogleFonts.dmSans(color: _amber, fontSize: 12)),
                  ]),
                ),
              ],

              // ── Result ────────────────────────────────────────────────
              if (_state == GenerationState.succeeded && _resultUrl != null) ...[
                const SizedBox(height: 22),
                _ResultBar(
                  onSave: _save,
                  accentColor: _type == GenType.image ? _electric : _rose,
                  accentGradient: _type == GenType.image ? accentGrad : _roseGrad,
                ),
                const SizedBox(height: 12),
                if (_type == GenType.image)
                  Hero(
                    tag: 'result_image',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.network(
                        _resultUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                          height: 300,
                          decoration: BoxDecoration(color: _glass1, borderRadius: BorderRadius.circular(22)),
                          child: Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: _electric, strokeWidth: 1.5),
                              const SizedBox(height: 14),
                              Text('Loading image…', style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12)),
                            ],
                          )),
                        ),
                      ),
                    ),
                  )
                else if (_vpCtrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: _vpCtrl!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_vpCtrl!),
                          GestureDetector(
                            onTap: () => setState(() {
                              _vpCtrl!.value.isPlaying ? _vpCtrl!.pause() : _vpCtrl!.play();
                            }),
                            child: AnimatedOpacity(
                              opacity: _vpCtrl!.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, gradient: _roseGrad,
                                  boxShadow: [BoxShadow(color: _rose.withOpacity(0.4), blurRadius: 20)],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(GenType t, IconData icon, String label, Color color, LinearGradient grad) {
    final sel = _type == t;
    return Expanded(
      child: GestureDetector(
        onTap: () { if (!_state.isActive) setState(() => _type = t); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: sel ? grad : null,
            borderRadius: BorderRadius.circular(15),
            boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.32), blurRadius: 14)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? Colors.white : Colors.white.withOpacity(0.22), size: 17),
              const SizedBox(width: 7),
              Text(label, style: GoogleFonts.dmSans(
                color: sel ? Colors.white : Colors.white.withOpacity(0.22),
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: 14,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI Core Animation ────────────────────────────────────────────────────────
class _AiCoreAnimation extends StatelessWidget {
  final GenerationState state;
  final String statusText;
  final AnimationController coreCtrl, orbitalCtrl, pulseCtrl;
  final GenType type;

  const _AiCoreAnimation({
    required this.state, required this.statusText,
    required this.coreCtrl, required this.orbitalCtrl,
    required this.pulseCtrl, required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type == GenType.image ? _electric : _rose;

    return GlassPane(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated core orb
          SizedBox(
            width: 120, height: 1.05,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) => Container(
                    width: 120, height: 1.05,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.12 + pulseCtrl.value * 0.12),
                          blurRadius: 50 + pulseCtrl.value * 20,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                // Orbital ring 1
                AnimatedBuilder(
                  animation: orbitalCtrl,
                  builder: (_, __) => Transform.rotate(
                    angle: orbitalCtrl.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(110, 110),
                      painter: _ArcRingPainter(
                        primaryColor: accent, secondaryColor: _violet,
                        count: 3, strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ),
                // Orbital ring 2 (counter)
                AnimatedBuilder(
                  animation: orbitalCtrl,
                  builder: (_, __) => Transform.rotate(
                    angle: -orbitalCtrl.value * math.pi * 2 * 0.65,
                    child: CustomPaint(
                      size: const Size(80, 80),
                      painter: _ArcRingPainter(
                        primaryColor: _violet, secondaryColor: accent,
                        count: 5, strokeWidth: 1.0,
                      ),
                    ),
                  ),
                ),
                // Core sphere
                AnimatedBuilder(
                  animation: coreCtrl,
                  builder: (_, __) {
                    final scale = 0.88 + 0.12 * math.sin(coreCtrl.value * math.pi * 2);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent.withOpacity(0.9), _violet, _violetDeep],
                          ),
                          boxShadow: [
                            BoxShadow(color: accent.withOpacity(0.6), blurRadius: 24, spreadRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // State label
          Text(
            state.label,
            style: GoogleFonts.spaceMono(
              color: accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.35), fontSize: 12),
          ),

          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: coreCtrl,
              builder: (_, __) {
                final progress = state == GenerationState.queued
                    ? (coreCtrl.value * 0.3).clamp(0.0, 0.3)
                    : (0.3 + coreCtrl.value * 0.7).clamp(0.0, 1.0);
                return LinearProgressIndicator(
                  value: null, // indeterminate
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation(accent.withOpacity(0.8)),
                  minHeight: 2,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final GenerationState state;
  final GenType type;
  final VoidCallback onGenerate, onCancel, onRegenerate, onReset;

  const _ActionButtons({
    required this.state, required this.type,
    required this.onGenerate, required this.onCancel,
    required this.onRegenerate, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type == GenType.image ? _electric : _rose;
    final grad   = type == GenType.image ? accentGrad : _roseGrad;

    if (state.isActive) {
      // Cancel button
      return GestureDetector(
        onTap: onCancel,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF180810),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _rose.withOpacity(0.35), width: 0.6),
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stop_rounded, color: _rose, size: 18),
              const SizedBox(width: 10),
              Text('Cancel Generation', style: GoogleFonts.dmSans(
                color: _rose, fontWeight: FontWeight.w700, fontSize: 15,
              )),
            ]),
          ),
        ),
      );
    }

    if (state == GenerationState.succeeded) {
      return Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onRegenerate,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: grad,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Regenerate', style: GoogleFonts.dmSans(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                )),
              ])),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onReset,
          child: Container(
            height: 56, width: 56,
            decoration: BoxDecoration(
              color: _glass1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border1, width: 0.6),
            ),
            child: Center(child: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.4), size: 20)),
          ),
        ),
      ]);
    }

    // Idle / failed / cancelled — show Generate
    return GestureDetector(
      onTap: onGenerate,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.40), blurRadius: 28, offset: const Offset(0, 10))],
        ),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            state == GenerationState.failed ? Icons.refresh_rounded : Icons.rocket_launch_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            state == GenerationState.failed ? 'Try Again' : 'Generate',
            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
          ),
        ])),
      ),
    );
  }
}

// ── Slider Row ─────────────────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label, displayValue;
  final double value, min, max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label, required this.value, required this.min,
    required this.max, required this.divisions, required this.color,
    required this.displayValue, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(children: [
        Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(displayValue, style: GoogleFonts.spaceMono(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color,
          inactiveTrackColor: Colors.white.withOpacity(0.07),
          thumbColor: color,
          overlayColor: color.withOpacity(0.12),
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ),
    ],
  );
}

// ── Result Bar ──────────────────────────────────────────────────────────────
class _ResultBar extends StatelessWidget {
  final VoidCallback onSave;
  final Color accentColor;
  final LinearGradient accentGradient;

  const _ResultBar({required this.onSave, required this.accentColor, required this.accentGradient});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Container(
          width: 3, height: 10,
          decoration: BoxDecoration(gradient: accentGradient, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text('RESULT', style: GoogleFonts.spaceMono(
          color: Colors.white.withOpacity(0.22), fontSize: 9.5, letterSpacing: 3,
        )),
      ]),
      GestureDetector(
        onTap: onSave,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accentColor.withOpacity(0.18), accentColor.withOpacity(0.08)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.28), width: 0.6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bookmark_rounded, color: accentColor, size: 13),
            const SizedBox(width: 6),
            Text('Save to Gallery', style: GoogleFonts.dmSans(
              color: accentColor, fontSize: 12, fontWeight: FontWeight.w700,
            )),
          ]),
        ),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PLACEHOLDER SCREENS (replaced in PART 2)
// ═══════════════════════════════════════════════════════════════════════════


// NOVA AI STUDIO — PART 2
// Explore + Gallery + Profile
// Replace the placeholder screens in Part 1 with these full implementations
// ═══════════════════════════════════════════════════════════════════════════
//
// HOW TO USE:
// 1. In Part 1, delete the 3 placeholder classes at the bottom:
//    ExploreScreen, GalleryScreen, ProfileScreen
// 2. Paste this entire file after the _ResultBar class in Part 1
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// EXPLORE SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ExploreScreen extends StatefulWidget {
  final ValueNotifier<double> scrollNotifier;
  const ExploreScreen({super.key, required this.scrollNotifier});
  @override State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late TabController _tabCtrl;
  int _selectedCategory = 0;
  String? _expandedPrompt;
  final _scrollCtrl = ScrollController();

  final _categories = ['All', 'Cinematic', 'Abstract', 'Portrait', 'Landscape', 'Sci-Fi'];

  final _styles = [
    _StyleCard(
      title: 'Neon Noir',
      tag: 'CINEMATIC', tagColor: _violet,
      prompt: 'A rain-soaked cyberpunk alley at midnight, neon signs reflected in puddles, cinematic lighting, hyper-detailed, 8K',
      mood: 'Dark · Atmospheric', uses: '12.4K', trending: true,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF180830), Color(0xFF080415)]),
      accentColor: _violet,
    ),
    _StyleCard(
      title: 'Golden Hour',
      tag: 'LANDSCAPE', tagColor: _amber,
      prompt: 'Epic mountain vista at golden hour, god rays through clouds, photorealistic, dramatic sky, f/2.8 bokeh, award-winning photography',
      mood: 'Warm · Epic', uses: '8.9K', trending: false,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2A1400), Color(0xFF160A00)]),
      accentColor: _amber,
    ),
    _StyleCard(
      title: 'Quantum Dreams',
      tag: 'ABSTRACT', tagColor: _teal,
      prompt: 'Fractal geometry meets quantum physics, iridescent sacred geometry, chromatic aberration, surreal dreamscape, ultra-detailed',
      mood: 'Ethereal · Surreal', uses: '6.7K', trending: true,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF001818), Color(0xFF000C0C)]),
      accentColor: _teal,
    ),
    _StyleCard(
      title: 'Studio Portrait',
      tag: 'PORTRAIT', tagColor: _rose,
      prompt: 'Ethereal female portrait, soft studio lighting, silk fabric, cinematic depth of field, Rembrandt lighting, fashion editorial',
      mood: 'Elegant · Refined', uses: '15.2K', trending: true,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF180510), Color(0xFF0A0208)]),
      accentColor: _rose,
    ),
    _StyleCard(
      title: 'Orbital Station',
      tag: 'SCI-FI', tagColor: _electric,
      prompt: 'Massive space station orbiting an alien gas giant, hard sci-fi aesthetic, specular reflections, extreme detail, NASA concept art',
      mood: 'Grand · Technical', uses: '9.3K', trending: false,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF060022), Color(0xFF020010)]),
      accentColor: _electric,
    ),
    _StyleCard(
      title: 'Bioluminescent',
      tag: 'ABSTRACT', tagColor: _emerald,
      prompt: 'Deep ocean bioluminescent creatures, dark water, glowing tendrils, marine biology meets abstract art, otherworldly beauty',
      mood: 'Mysterious · Beautiful', uses: '7.1K', trending: false,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF001808), Color(0xFF000D04)]),
      accentColor: _emerald,
    ),
  ];

  final _techniques = [
    _TechniqueItem('Negative Prompting', 'Use "negative_prompt" to exclude unwanted elements from your image', Icons.remove_circle_outline_rounded, _rose),
    _TechniqueItem('Seed Control', 'Fix seed value for perfectly reproducible results every time', Icons.fingerprint_rounded, _teal),
    _TechniqueItem('CFG Scale', 'Higher = more literal interpretation. 7–12 is the sweet spot for most styles', Icons.tune_rounded, _amber),
    _TechniqueItem('Img2Img', 'Use existing images as structural guides for more controlled outputs', Icons.transform_rounded, _electric),
  ];

  // Callback to auto-fill generator prompt
  void Function(String)? _onUsePrompt;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _tabCtrl     = TabController(length: 2, vsync: this);
    Future.delayed(const Duration(milliseconds: 100), _staggerCtrl.forward);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) widget.scrollNotifier.value = _scrollCtrl.offset;
    });
  }

  @override
  void dispose() { _staggerCtrl.dispose(); _tabCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  List<_StyleCard> get _filteredStyles {
    if (_selectedCategory == 0) return _styles;
    final cat = _categories[_selectedCategory].toUpperCase();
    return _styles.where((s) => s.tag == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NovaAppBar(title: 'EXPLORE', scrollNotifier: widget.scrollNotifier),
      body: NestedScrollView(
        controller: _scrollCtrl,
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FadeSlide(
                    animation: CurvedAnimation(parent: _staggerCtrl, curve: const Interval(0, 0.5)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFCCC8FF)],
                          ).createShader(b),
                          child: Text('Inspiration\nHub', style: GoogleFonts.dmSans(
                            color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.05,
                          )),
                        ),
                        const SizedBox(height: 7),
                        Text('Curated prompts · Techniques · Style guides',
                            style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.28), fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  _FadeSlide(
                    animation: CurvedAnimation(parent: _staggerCtrl, curve: const Interval(0.1, 0.6)),
                    child: Row(children: [
                      _StatPill('${_styles.length}', 'Styles', _electric),
                      const SizedBox(width: 10),
                      _StatPill('${_techniques.length}', 'Tips', _teal),
                      const SizedBox(width: 10),
                      _StatPill('50K+', 'Uses', _amber),
                      const SizedBox(width: 10),
                      _StatPill('${_styles.where((s) => s.trending).length}', 'Trending', _rose),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  _FadeSlide(
                    animation: CurvedAnimation(parent: _staggerCtrl, curve: const Interval(0.15, 0.65)),
                    child: GlassPane(
                      padding: const EdgeInsets.all(4),
                      radius: 18,
                      child: TabBar(
                        controller: _tabCtrl,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          gradient: accentGrad,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: _electric.withOpacity(0.38), blurRadius: 14)],
                        ),
                        labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withOpacity(0.35),
                        tabs: const [Tab(text: 'Style Prompts'), Tab(text: 'Techniques')],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _StylesTab(
              styles: _filteredStyles,
              categories: _categories,
              selectedCategory: _selectedCategory,
              onCategoryChanged: (i) => setState(() => _selectedCategory = i),
              expandedPrompt: _expandedPrompt,
              onExpandPrompt: (title) => setState(() {
                _expandedPrompt = _expandedPrompt == title ? null : title;
              }),
              onUseStyle: (prompt) {
                // Navigate to Generator and pre-fill prompt
                // This is handled via Navigator if needed, or show snackbar
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Prompt copied to clipboard!')),
                  ]),
                  backgroundColor: const Color(0xFF1A1040),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  margin: const EdgeInsets.all(16),
                  action: SnackBarAction(
                    label: 'Go Create',
                    textColor: _electricBright,
                    onPressed: () {},
                  ),
                ));
                Clipboard.setData(ClipboardData(text: prompt));
              },
            ),
            _TechniquesTab(techniques: _techniques),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.18), width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: GoogleFonts.spaceMono(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.35), fontSize: 11)),
    ]),
  );
}

class _StylesTab extends StatelessWidget {
  final List<_StyleCard> styles;
  final List<String> categories;
  final int selectedCategory;
  final Function(int) onCategoryChanged;
  final String? expandedPrompt;
  final Function(String) onExpandPrompt;
  final Function(String) onUseStyle;

  const _StylesTab({
    required this.styles, required this.categories,
    required this.selectedCategory, required this.onCategoryChanged,
    required this.expandedPrompt, required this.onExpandPrompt,
    required this.onUseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 0, 16),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sel = selectedCategory == i;
                  return GestureDetector(
                    onTap: () => onCategoryChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: sel ? accentGrad : null,
                        color: sel ? null : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: sel ? Colors.transparent : Colors.white.withOpacity(0.08),
                          width: 0.5,
                        ),
                        boxShadow: sel ? [BoxShadow(color: _electric.withOpacity(0.28), blurRadius: 12)] : null,
                      ),
                      child: Text(categories[i], style: GoogleFonts.dmSans(
                        color: sel ? Colors.white : Colors.white.withOpacity(0.35),
                        fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final style     = styles[i];
                final isExpanded = expandedPrompt == style.title;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExploreStyleCard(
                    style: style, isExpanded: isExpanded,
                    onTap: () => onExpandPrompt(style.title),
                    onUseStyle: () => onUseStyle(style.prompt),
                  ),
                );
              },
              childCount: styles.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreStyleCard extends StatefulWidget {
  final _StyleCard style;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onUseStyle;

  const _ExploreStyleCard({
    required this.style, required this.isExpanded,
    required this.onTap, required this.onUseStyle,
  });

  @override State<_ExploreStyleCard> createState() => _ExploreStyleCardState();
}

class _ExploreStyleCardState extends State<_ExploreStyleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandCtrl;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
    if (widget.isExpanded) _expandCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_ExploreStyleCard old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      widget.isExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
    }
  }

  @override void dispose() { _expandCtrl.dispose(); super.dispose(); }

  void _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: widget.style.prompt));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _expandCtrl,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: s.gradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: s.accentColor.withOpacity(0.18 + _expandCtrl.value * 0.14),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: s.accentColor.withOpacity(0.06 + _expandCtrl.value * 0.12),
                blurRadius: 26, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            s.accentColor.withOpacity(0.24),
                            s.accentColor.withOpacity(0.09),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: s.accentColor.withOpacity(0.26), width: 0.5),
                        ),
                        child: Center(
                          child: Text(s.title[0], style: GoogleFonts.spaceMono(
                            color: s.accentColor, fontSize: 20, fontWeight: FontWeight.w700,
                          )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: s.accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: s.accentColor.withOpacity(0.26), width: 0.5),
                                ),
                                child: Text(s.tag, style: GoogleFonts.spaceMono(
                                  color: s.accentColor, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                                )),
                              ),
                              const SizedBox(width: 6),
                              // Trending badge
                              if (s.trending)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: _roseGrad,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [BoxShadow(color: _rose.withOpacity(0.35), blurRadius: 6)],
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 9),
                                    const SizedBox(width: 2),
                                    Text('HOT', style: GoogleFonts.spaceMono(
                                      color: Colors.white, fontSize: 7, fontWeight: FontWeight.w700,
                                    )),
                                  ]),
                                ),
                              const SizedBox(width: 6),
                              Text('${s.uses} uses', style: GoogleFonts.dmSans(
                                color: Colors.white.withOpacity(0.22), fontSize: 11,
                              )),
                            ]),
                            const SizedBox(height: 5),
                            Text(s.title, style: GoogleFonts.dmSans(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16,
                            )),
                            Text(s.mood, style: GoogleFonts.dmSans(
                              color: Colors.white.withOpacity(0.35), fontSize: 11,
                            )),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 340),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withOpacity(0.22), size: 22),
                      ),
                    ],
                  ),
                ),
                // Expanded content
                SizeTransition(
                  sizeFactor: CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 0.5, color: Colors.white.withOpacity(0.05)),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Text('PROMPT', style: GoogleFonts.spaceMono(
                                color: Colors.white.withOpacity(0.22), fontSize: 9, letterSpacing: 2,
                              )),
                              const Spacer(),
                              GestureDetector(
                                onTap: _copyPrompt,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _copied ? _emerald.withOpacity(0.12) : s.accentColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _copied ? _emerald.withOpacity(0.38) : s.accentColor.withOpacity(0.22),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(
                                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                                      color: _copied ? _emerald : s.accentColor, size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(_copied ? 'Copied!' : 'Copy', style: GoogleFonts.dmSans(
                                      color: _copied ? _emerald : s.accentColor,
                                      fontSize: 11, fontWeight: FontWeight.w600,
                                    )),
                                  ]),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.38),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
                              ),
                              child: Text(s.prompt, style: GoogleFonts.dmSans(
                                color: Colors.white.withOpacity(0.72), fontSize: 13, height: 1.55,
                              )),
                            ),
                            const SizedBox(height: 14),
                            // "Use This Style" button
                            GestureDetector(
                              onTap: widget.onUseStyle,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    s.accentColor.withOpacity(0.22),
                                    s.accentColor.withOpacity(0.10),
                                  ]),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: s.accentColor.withOpacity(0.30), width: 0.6),
                                  boxShadow: [BoxShadow(color: s.accentColor.withOpacity(0.15), blurRadius: 14)],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_fix_high_rounded, color: s.accentColor, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Use This Style', style: GoogleFonts.dmSans(
                                      color: s.accentColor, fontWeight: FontWeight.w700, fontSize: 14,
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechniquesTab extends StatelessWidget {
  final List<_TechniqueItem> techniques;
  const _TechniquesTab({required this.techniques});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          sliver: SliverToBoxAdapter(
            child: GlassBorderPane(
              borderGradient: accentGrad,
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    gradient: accentGrad, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _electric.withOpacity(0.38), blurRadius: 14)],
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pro Tips', style: GoogleFonts.dmSans(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                    )),
                    Text('Master parameters for perfect results', style: GoogleFonts.dmSans(
                      color: Colors.white.withOpacity(0.35), fontSize: 11,
                    )),
                  ],
                )),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TechniqueCard(technique: techniques[i]),
              ),
              childCount: techniques.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SectionLabel('PROMPT ANATOMY'),
                const SizedBox(height: 14),
                _PromptAnatomy(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TechniqueCard extends StatefulWidget {
  final _TechniqueItem technique;
  const _TechniqueCard({required this.technique});
  @override State<_TechniqueCard> createState() => _TechniqueCardState();
}

class _TechniqueCardState extends State<_TechniqueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 160)); }
  @override void dispose()   { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.technique;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp:   (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: 1.0 - _ctrl.value * 0.012,
          child: GlassPane(
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: t.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.color.withOpacity(0.24), width: 0.5),
                ),
                child: Icon(t.icon, color: t.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.title, style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
                  )),
                  const SizedBox(height: 3),
                  Text(t.description, style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.38), fontSize: 12, height: 1.4,
                  )),
                ],
              )),
              const SizedBox(width: 8),
              Icon(Icons.north_east_rounded, color: t.color.withOpacity(0.45), size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PromptAnatomy extends StatelessWidget {
  final _parts = [
    _PromptPart('Subject',  'A lone astronaut',          _electric),
    _PromptPart('Setting',  'standing on Mars at dawn',  _teal),
    _PromptPart('Style',    'photorealistic, 8K HDR',    _amber),
    _PromptPart('Lighting', 'dramatic backlight, god rays', _rose),
    _PromptPart('Quality',  'award-winning, masterpiece', _violet),
  ];
  _PromptAnatomy();

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.42),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
            ),
            child: Wrap(
              children: _parts.map((p) => Text('${p.text} ', style: GoogleFonts.dmSans(
                color: p.color, fontSize: 13, fontWeight: FontWeight.w600,
              ))).toList(),
            ),
          ),
          const SizedBox(height: 18),
          ..._parts.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: p.color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: p.color.withOpacity(0.55), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 10),
              Text(p.label, style: GoogleFonts.spaceMono(
                color: Colors.white.withOpacity(0.22), fontSize: 9, letterSpacing: 1.5,
              )),
              const SizedBox(width: 10),
              Expanded(child: Text(p.text, style: GoogleFonts.dmSans(
                color: p.color.withOpacity(0.85), fontSize: 12,
              ))),
            ]),
          )),
        ],
      ),
    );
  }
}

class _PromptPart {
  final String label, text;
  final Color color;
  const _PromptPart(this.label, this.text, this.color);
}

class _StyleCard {
  final String title, tag, prompt, mood, uses;
  final bool trending;
  final LinearGradient gradient;
  final Color tagColor, accentColor;
  const _StyleCard({
    required this.title, required this.tag, required this.tagColor,
    required this.prompt, required this.mood, required this.uses,
    required this.gradient, required this.accentColor,
    this.trending = false,
  });
}

class _TechniqueItem {
  final String title, description;
  final IconData icon;
  final Color color;
  const _TechniqueItem(this.title, this.description, this.icon, this.color);
}

// ═══════════════════════════════════════════════════════════════════════════
// GALLERY SCREEN — Grid, metadata overlay, animated deletion, fullscreen
// ═══════════════════════════════════════════════════════════════════════════
class GalleryScreen extends StatefulWidget {
  final ValueNotifier<double> scrollNotifier;
  const GalleryScreen({super.key, required this.scrollNotifier});
  @override State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  List<GenerationItem> _items = [];
  late AnimationController _staggerCtrl;
  final _scrollCtrl = ScrollController();
  final _storage = LocalStorageService();
  final _deletingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) widget.scrollNotifier.value = _scrollCtrl.offset;
    });
  }

  @override void dispose() { _staggerCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final items = await _storage.loadGallery();
    if (mounted) setState(() => _items = items);
    _staggerCtrl.forward(from: 0);
  }

  Future<void> _delete(GenerationItem item) async {
    setState(() => _deletingIds.add(item.id));
    await Future.delayed(const Duration(milliseconds: 350));
    await _storage.deleteItem(item);
    await _load();
    if (mounted) setState(() => _deletingIds.remove(item.id));
  }

  void _open(GenerationItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _FullscreenView(item: item),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NovaAppBar(
        title: 'GALLERY',
        scrollNotifier: widget.scrollNotifier,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _load,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _glass1,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border2, width: 0.5),
                ),
                child: Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.40), size: 17),
              ),
            ),
          ),
        ],
      ),
      body: _items.isEmpty
          ? _EmptyGallery()
          : SafeArea(
        child: GridView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.76,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) {
            final item   = _items[i];
            final isVideo = item.type == 'video';
            final deleting = _deletingIds.contains(item.id);
            final delay  = (i * 0.08).clamp(0.0, 0.85);

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 320),
              opacity: deleting ? 0.0 : 1.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 320),
                scale: deleting ? 0.85 : 1.0,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _staggerCtrl,
                    curve: Interval(delay, math.min(delay + 0.4, 1.0)),
                  ),
                  child: GestureDetector(
                    onTap: () => _open(item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image or video thumbnail
                          isVideo
                              ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1A0510), Color(0xFF080210)],
                              ),
                            ),
                            child: Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white.withOpacity(0.22), size: 50),
                          )
                              : Image.network(
                            item.url, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _glass1,
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                          ),

                          // Bottom metadata overlay
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.prompt,
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white.withOpacity(0.65), fontSize: 9.5, height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatDate(item.createdAt),
                                        style: GoogleFonts.spaceMono(
                                          color: Colors.white.withOpacity(0.28), fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Delete button
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => _delete(item),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    color: Colors.black.withOpacity(0.50),
                                    child: Icon(Icons.close_rounded, color: _rose, size: 14),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Type badge
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: isVideo ? _roseGrad : accentGrad,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isVideo ? _rose : _electric).withOpacity(0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Text(
                                isVideo ? 'VIDEO' : 'IMG',
                                style: GoogleFonts.spaceMono(
                                  color: Colors.white, fontSize: 7,
                                  fontWeight: FontWeight.w700, letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Empty Gallery ──────────────────────────────────────────────────────────
class _EmptyGallery extends StatefulWidget {
  @override State<_EmptyGallery> createState() => _EmptyGalleryState();
}

class _EmptyGalleryState extends State<_EmptyGallery>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: GlassPane(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Transform.scale(
                scale: 0.92 + 0.08 * _ctrl.value,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _glass2,
                    boxShadow: [
                      BoxShadow(
                        color: _electric.withOpacity(0.05 + _ctrl.value * 0.06),
                        blurRadius: 24, spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(Icons.photo_library_outlined,
                      color: Colors.white.withOpacity(0.12), size: 34),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('No creations yet', style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.35), fontSize: 18, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 7),
            Text('Generate & save your first artwork', style: GoogleFonts.dmSans(
              color: Colors.white.withOpacity(0.18), fontSize: 13,
            )),
          ],
        ),
      ),
    ),
  );
}

// ── Fullscreen View ────────────────────────────────────────────────────────
class _FullscreenView extends StatefulWidget {
  final GenerationItem item;
  const _FullscreenView({required this.item});
  @override State<_FullscreenView> createState() => _FullscreenViewState();
}

class _FullscreenViewState extends State<_FullscreenView> {
  VideoPlayerController? _vp;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'video') {
      _vp = VideoPlayerController.networkUrl(Uri.parse(widget.item.url))
        ..initialize().then((_) {
          _vp!.setLooping(true);
          _vp!.play();
          setState(() {});
        });
    }
  }

  @override void dispose() { _vp?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.type == 'video';
    return Scaffold(
      backgroundColor: _bg0,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _glass1, shape: BoxShape.circle,
              border: Border.all(color: _border2, width: 0.5),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white.withOpacity(0.7), size: 16),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.item.prompt, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.35))),
            Text(_fullDate(widget.item.createdAt),
                style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.white.withOpacity(0.20))),
          ],
        ),
      ),
      body: Center(
        child: isVideo
            ? (_vp != null && _vp!.value.isInitialized
            ? GestureDetector(
          onTap: () => setState(() {
            _vp!.value.isPlaying ? _vp!.pause() : _vp!.play();
          }),
          child: AspectRatio(
            aspectRatio: _vp!.value.aspectRatio,
            child: VideoPlayer(_vp!),
          ),
        )
            : const CircularProgressIndicator(color: _electric, strokeWidth: 1.5))
            : InteractiveViewer(
          child: Image.network(widget.item.url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _fullDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE SCREEN — Full stats, storage, reset, glass info cards
// ═══════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  final ValueNotifier<double> scrollNotifier;
  const ProfileScreen({super.key, required this.scrollNotifier});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool _checking = false;
  String _apiStatus = 'Unknown';
  bool _connected = false;
  late AnimationController _staggerCtrl, _avatarCtrl;
  Map<String, int> _stats = {'images': 0, 'videos': 0, 'total': 0};
  int _storageBytes = 0;
  final _scrollCtrl = ScrollController();
  final _storage = LocalStorageService();
  final _api     = ApiService();

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _avatarCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    Future.delayed(const Duration(milliseconds: 80), _staggerCtrl.forward);
    _loadData();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients) widget.scrollNotifier.value = _scrollCtrl.offset;
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose(); _avatarCtrl.dispose();
    _scrollCtrl.dispose(); _api.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _checking = true; _apiStatus = 'Checking…'; });
    final stats   = await _storage.loadStats();
    final bytes   = await _storage.estimateStorageBytes();
    final healthy = await _api.checkHealth();
    if (mounted) setState(() {
      _stats = stats; _storageBytes = bytes;
      _connected = healthy; _checking = false;
      _apiStatus = healthy ? 'Connected' : 'Offline';
    });
  }

  Future<void> _clearGallery() async {
    await _showConfirmDialog(
      title: 'Clear Gallery',
      message: 'This will delete all saved creations. This action cannot be undone.',
      confirmLabel: 'Clear',
      confirmColor: _rose,
      onConfirm: () async {
        await _storage.clearGallery();
        await _loadData();
        if (mounted) _showSnack('Gallery cleared', Icons.delete_sweep_rounded, const Color(0xFF280A12));
      },
    );
  }

  Future<void> _resetStats() async {
    await _showConfirmDialog(
      title: 'Reset Statistics',
      message: 'Your generation counts will be reset to zero.',
      confirmLabel: 'Reset',
      confirmColor: _amber,
      onConfirm: () async {
        await _storage.resetStats();
        await _loadData();
        if (mounted) _showSnack('Statistics reset', Icons.refresh_rounded, const Color(0xFF1A1200));
      },
    );
  }

  Future<void> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.dmSans(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18,
              )),
              const SizedBox(height: 12),
              Text(message, style: GoogleFonts.dmSans(
                color: Colors.white.withOpacity(0.45), fontSize: 13,
              )),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _glass1, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border1, width: 0.5),
                      ),
                      child: Center(child: Text('Cancel', style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600,
                      ))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: confirmColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: confirmColor.withOpacity(0.35), width: 0.5),
                      ),
                      child: Center(child: Text(confirmLabel, style: GoogleFonts.dmSans(
                        color: confirmColor, fontWeight: FontWeight.w700,
                      ))),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await onConfirm();
  }

  void _showSnack(String msg, IconData icon, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Text(msg, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Animation<double> _s(int i) => CurvedAnimation(
    parent: _staggerCtrl,
    curve: Interval(i * 0.10, math.min(i * 0.10 + 0.55, 1.0), curve: Curves.easeOutExpo),
  );

  String _formatBytes(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / 1024 / 1024).toStringAsFixed(2)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _checking ? _amber : (_connected ? _emerald : _rose);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NovaAppBar(title: 'PROFILE', scrollNotifier: widget.scrollNotifier),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            children: [

              // ── Avatar + Name ────────────────────────────────────────
              _FadeSlide(
                animation: _s(0),
                child: GlassBorderPane(
                  borderGradient: accentGrad,
                  padding: const EdgeInsets.all(22),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: _avatarCtrl,
                      builder: (_, __) => Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            startAngle: _avatarCtrl.value * math.pi * 2,
                            colors: const [_electricBright, _violet, _rose, _teal, _electricBright],
                          ),
                          boxShadow: [BoxShadow(color: _electric.withOpacity(0.38), blurRadius: 22)],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircleAvatar(
                            backgroundColor: Color(0xFF08081A),
                            child: Icon(Icons.person_rounded, color: Colors.white70, size: 28),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Creator', style: GoogleFonts.dmSans(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22,
                        )),
                        Text('Nova AI Studio', style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.28), fontSize: 10, letterSpacing: 1.5,
                        )),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: accentGrad,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: _electric.withOpacity(0.32), blurRadius: 12)],
                      ),
                      child: Text('PRO', style: GoogleFonts.spaceMono(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2,
                      )),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 14),

              // ── Generation Stats ──────────────────────────────────────
              _FadeSlide(
                animation: _s(1),
                child: Row(children: [
                  Expanded(child: _StatCard(
                    value: '${_stats['images'] ?? 0}',
                    label: 'Images', color: _electric,
                    icon: Icons.image_rounded,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    value: '${_stats['videos'] ?? 0}',
                    label: 'Videos', color: _rose,
                    icon: Icons.videocam_rounded,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    value: '${_stats['total'] ?? 0}',
                    label: 'Total', color: _amber,
                    icon: Icons.auto_awesome_rounded,
                  )),
                ]),
              ),

              const SizedBox(height: 14),

              // ── Storage ───────────────────────────────────────────────
              _FadeSlide(
                animation: _s(1),
                child: GlassPane(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _teal.withOpacity(0.22), width: 0.5),
                      ),
                      child: Icon(Icons.storage_rounded, color: _teal, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Storage Used', style: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.45), fontSize: 12,
                        )),
                        Text(_formatBytes(_storageBytes), style: GoogleFonts.spaceMono(
                          color: _teal, fontSize: 15, fontWeight: FontWeight.w700,
                        )),
                      ],
                    )),
                    Text('(metadata)', style: GoogleFonts.spaceMono(
                      color: Colors.white.withOpacity(0.18), fontSize: 9,
                    )),
                  ]),
                ),
              ),

              const SizedBox(height: 14),

              // ── API Status ────────────────────────────────────────────
              _FadeSlide(
                animation: _s(2),
                child: GlassPane(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Text('API STATUS', style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.22), fontSize: 9, letterSpacing: 2,
                        )),
                        const Spacer(),
                        GestureDetector(
                          onTap: _checking ? null : _loadData,
                          child: _checking
                              ? SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: _electric.withOpacity(0.5)))
                              : Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.25), size: 17),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 9, height: 9,
                          decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.7), blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_apiStatus, style: GoogleFonts.dmSans(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15,
                        )),
                        const Spacer(),
                        Text('Replicate.com', style: GoogleFonts.spaceMono(
                          color: Colors.white.withOpacity(0.20), fontSize: 9,
                        )),
                      ]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── App Info ──────────────────────────────────────────────
              _FadeSlide(
                animation: _s(3),
                child: GlassPane(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InfoRow(Icons.image_rounded, 'Image Model', 'SDXL', _electric),
                      _divider(),
                      _InfoRow(Icons.videocam_rounded, 'Video Model', 'Zeroscope v2 XL', _rose),
                      _divider(),
                      _InfoRow(Icons.info_outline_rounded, 'Version', '2.1.0', Colors.white38),
                      _divider(),
                      _InfoRow(Icons.memory_rounded, 'Provider', 'Replicate', Colors.white38),
                      _divider(),
                      _InfoRow(Icons.high_quality_rounded, 'Max Quality', '4K', _teal),
                      _divider(),
                      _InfoRow(Icons.speed_rounded, 'Avg Speed', '~30s', _amber),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Reset Stats ───────────────────────────────────────────
              _FadeSlide(
                animation: _s(4),
                child: GestureDetector(
                  onTap: _resetStats,
                  child: GlassPane(
                    tint: _amber.withOpacity(0.04),
                    borderColor: _amber.withOpacity(0.14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.bar_chart_rounded, color: _amber, size: 18),
                      const SizedBox(width: 10),
                      Text('Reset Statistics', style: GoogleFonts.dmSans(
                        color: _amber, fontWeight: FontWeight.w700, fontSize: 14,
                      )),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Clear Gallery ─────────────────────────────────────────
              _FadeSlide(
                animation: _s(4),
                child: GestureDetector(
                  onTap: _clearGallery,
                  child: GlassPane(
                    tint: _rose.withOpacity(0.05),
                    borderColor: _rose.withOpacity(0.15),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.delete_outline_rounded, color: _rose, size: 18),
                      const SizedBox(width: 10),
                      Text('Clear Gallery', style: GoogleFonts.dmSans(
                        color: _rose, fontWeight: FontWeight.w700, fontSize: 14,
                      )),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
    height: 0.5, margin: const EdgeInsets.symmetric(vertical: 1),
    color: Colors.white.withOpacity(0.04),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => GlassPane(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    radius: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.spaceMono(color: color, fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.32), fontSize: 11)),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color valueColor;
  const _InfoRow(this.icon, this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: Colors.white.withOpacity(0.22), size: 16),
      const SizedBox(width: 12),
      Text(label, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.38), fontSize: 13)),
      const Spacer(),
      Text(value, style: GoogleFonts.spaceMono(color: valueColor, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}