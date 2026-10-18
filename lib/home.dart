import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'clay.dart';
import 'icons.dart';
import 'theme.dart';
import 'turnstile.dart';

const kDashboard = 'https://agrisense-1-0.onrender.com/';

String _fmt(double? v, String unit, [int d = 0]) => v == null ? '–' : '${v.toStringAsFixed(d)}$unit';

String _ago(DateTime? t) {
  if (t == null) return '–';
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return 'just now';
  if (s < 3600) return '${s ~/ 60} min ago';
  if (s < 86400) return '${s ~/ 3600} h ago';
  return '${s ~/ 86400} d ago';
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Reading? _r;
  String? _error;
  bool _ready = false, _signedIn = false, _live = true, _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    final live = await Api.isLive();
    final signed = await Api.hasSession();
    if (!mounted) return;
    setState(() {
      _live = live;
      _signedIn = signed;
      _ready = true;
    });
    if (signed) {
      _poll();
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_signedIn) {
        _poll();
        _startTimer();
      }
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  // Realtime: the dashboard polls every 8 s, here it is every 5 s while the app is open.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_busy || !_signedIn) return;
    _busy = true;
    try {
      final r = await Api.status();
      if (mounted) setState(() { _r = r; _error = null; });
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        _timer?.cancel();
        setState(() { _signedIn = false; _r = null; _error = null; });
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _afterLogin() async {
    setState(() { _signedIn = true; _error = null; });
    _poll();
    _startTimer();
    try {
      if (_live && await Api.widgetCount() > 0) await Api.setLive(true);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    _timer?.cancel();
    await Api.logout();
    if (mounted) setState(() { _signedIn = false; _r = null; _error = null; });
  }

  Future<void> _openDashboard() async {
    final ok = await launchUrl(Uri.parse(kDashboard), mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open the dashboard.');
  }

  Future<void> _toggleLive(bool v) async {
    setState(() => _live = v);
    try {
      await Api.setLive(v);
    } catch (_) {}
  }

  Future<void> _check() async {
    String r;
    try {
      r = await Api.diagnose();
    } catch (e) {
      r = 'Check failed: $e';
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.cardTop,
        title: Text('Widget check', style: nunito(18, w: FontWeight.w800, color: C.matchaInk)),
        content: SingleChildScrollView(child: SelectableText(r, style: nunito(13, w: FontWeight.w500, color: C.ink, height: 1.4))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: nunito(14, w: FontWeight.w700, color: C.matchaDeep)))],
      ),
    );
  }

  Future<void> _pin() async {
    bool done = false;
    try {
      done = await Api.pinWidget();
    } catch (_) {}
    if (!done && mounted) _toast('Long-press your home screen, tap Widgets, then pick AgriSense.');
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: nunito(14, color: Colors.white)), backgroundColor: C.matchaInk, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final online = r?.online ?? false;
    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        const Positioned.fill(child: FieldBackdrop()),
        SafeArea(
          child: !_ready
              ? const Center(child: CircularProgressIndicator(color: C.matchaDark))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      children: [
                        Row(children: [
                          const Sprout(size: 36),
                          const SizedBox(width: 8),
                          Text('AgriSense', style: nunito(22, w: FontWeight.w800, color: C.matchaInk, spacing: -0.4)),
                          const Spacer(),
                          if (_signedIn && r != null) Pill(online ? 'Online' : 'Offline', online ? C.ok : C.bad),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          _signedIn
                              ? '${_greeting()}. ${r == null ? '' : (online ? 'Everything is reporting in.' : 'The device has gone quiet.')}'
                              : '${_greeting()}. Sign in to see your field.',
                          style: nunito(14, w: FontWeight.w500, color: C.mute),
                        ),
                        const SizedBox(height: 18),
                        if (!_signedIn) _LoginCard(onDone: _afterLogin) else ..._readings(r),
                        const SizedBox(height: 16),
                        ClayButton(
                          label: 'Go to AgriSense Dashboard',
                          icon: const AgriIcon('gauge', size: 21, color: Colors.white),
                          onTap: _openDashboard,
                        ),
                        const SizedBox(height: 16),
                        _WidgetCard(live: _live, onLive: _toggleLive, onPin: _pin, onCheck: _check),
                        if (_signedIn) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: _signOut,
                              icon: const AgriIcon('logout', size: 18, color: C.mute),
                              label: Text('Sign out', style: nunito(13.5, w: FontWeight.w700, color: C.mute)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  List<Widget> _readings(Reading? r) {
    return [
      if (_error != null && r == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Clay(radius: 20, padding: const EdgeInsets.all(14), child: Row(children: [
            const AgriIcon('alert', size: 20, color: C.bad),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!, style: nunito(14, color: C.bad))),
          ])),
        ),
      Clay(
        radius: 30,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Ring(
            size: 128,
            stroke: 15,
            value: r?.soil ?? 0,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: r?.soil == null ? '–' : r!.soil!.toStringAsFixed(0), style: nunito(30, w: FontWeight.w800, color: C.matchaInk, spacing: -1)),
              TextSpan(text: '%', style: nunito(15, color: C.mute)),
            ])),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const AgriIcon('leaf', size: 17, color: C.soil),
                const SizedBox(width: 6),
                Text('Soil moisture', style: nunito(13, w: FontWeight.w700, color: C.mute)),
              ]),
              const SizedBox(height: 4),
              Text(r?.soilState ?? '…', style: nunito(21, w: FontWeight.w800, color: C.matchaInk)),
              const SizedBox(height: 8),
              Row(children: [
                const AgriIcon('clock', size: 15, color: C.mute),
                const SizedBox(width: 6),
                Expanded(child: Text(r == null ? 'Connecting…' : 'Updated ${_ago(r.updatedAt ?? r.fetchedAt)}', style: nunito(12.5, w: FontWeight.w500, color: C.mute))),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Tile(icon: 'thermo', color: C.temp, label: 'Temperature', value: _fmt(r?.temp, '°', 1))),
        const SizedBox(width: 14),
        Expanded(child: _Tile(icon: 'drop', color: C.hum, label: 'Humidity', value: _fmt(r?.hum, '%'))),
      ]),
      const SizedBox(height: 14),
      Clay(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          AgriIcon('wifi', size: 20, color: r == null ? C.faint : (r.online ? C.ok : C.bad)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Device', style: nunito(13, w: FontWeight.w700, color: C.mute)),
          ),
          Text(r == null ? '–' : (r.online ? 'Online' : 'Offline'),
              style: nunito(17, w: FontWeight.w800, color: r == null ? C.faint : (r.online ? C.ok : C.bad))),
        ]),
      ),
    ];
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.label, required this.value});
  final String icon, label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Clay(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AgriIcon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: nunito(12.5, w: FontWeight.w700, color: C.mute), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: nunito(30, w: FontWeight.w800, spacing: -0.5))),
      ]),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.live, required this.onLive, required this.onPin, required this.onCheck});
  final bool live;
  final ValueChanged<bool> onLive;
  final VoidCallback onPin;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Clay(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Sprout(size: 24),
          const SizedBox(width: 8),
          Text('Home & lock screen widget', style: nunito(15.5, w: FontWeight.w800, color: C.matchaInk)),
        ]),
        const SizedBox(height: 6),
        Text('Resize it to any shape. It switches layout to fit and shows temperature, humidity, soil moisture and device status.',
            style: nunito(13, w: FontWeight.w500, color: C.mute, height: 1.35)),
        const SizedBox(height: 14),
        ClayButton(label: 'Add widget', primary: false, icon: const AgriIcon('plus', size: 20, color: C.matchaInk), onTap: onPin),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live updates', style: nunito(14.5, w: FontWeight.w700)),
              Text('Refresh every few seconds while the screen is on. Shows a quiet notification.',
                  style: nunito(12, w: FontWeight.w500, color: C.mute, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 12),
          _Toggle(value: live, onChanged: onLive),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onCheck,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: Text('Check widget', style: nunito(13, w: FontWeight.w700, color: C.matchaDeep)),
          ),
        ),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 32,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value ? null : C.well,
          gradient: value ? const LinearGradient(colors: [C.matchaLight, C.matchaDark]) : null,
          border: Border.all(color: const Color(0xCCFFFFFF), width: 1.5),
        ),
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))]),
        ),
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard({required this.onDone});
  final Future<void> Function() onDone;
  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _email = TextEditingController(), _pw = TextEditingController();
  final _cap = GlobalKey<TurnstileState>();
  String? _token, _err;
  bool _show = false, _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) return setState(() => _err = 'Enter your email and password.');
    if (_token == null) return setState(() => _err = 'Complete the security check first.');
    setState(() { _busy = true; _err = null; });
    try {
      await Api.login(_email.text, _pw.text, _token!);
      await widget.onDone();
    } on ApiError catch (e) {
      _cap.currentState?.reset(); // a token only works once
      final code = e.data['code'];
      setState(() {
        _busy = false;
        _err = code == 'captcha'
            ? 'The security check failed. Please try it again.'
            : code == 'captcha_unavailable'
                ? 'The security check is unavailable right now. Try again in a moment.'
                : e.status == 429
                    ? 'Too many attempts. Try again in ${((e.data['retry_in'] as num?) ?? 900) ~/ 60 + 1} min.'
                    : e.status == 401
                        ? 'Email or password is wrong.'
                        : e.message;
      });
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: nunito(15, w: FontWeight.w500, color: C.faint),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x3858703A), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.matcha, width: 1.5)),
      );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(t, style: nunito(12.5, w: FontWeight.w700, color: C.mute)));

  @override
  Widget build(BuildContext context) {
    return Clay(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AgriIcon('shield', size: 20, color: C.matchaDeep),
          const SizedBox(width: 8),
          Text('Sign in once', style: nunito(18, w: FontWeight.w800, color: C.matchaInk)),
        ]),
        const SizedBox(height: 4),
        Text('Use your AgriSense dashboard account. The widget keeps itself signed in.', style: nunito(13, w: FontWeight.w500, color: C.mute, height: 1.35)),
        const SizedBox(height: 16),
        _label('Email'),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          style: nunito(16, color: C.ink),
          decoration: _dec('you@example.com'),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        TextField(
          controller: _pw,
          obscureText: !_show,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _go(),
          style: nunito(16, color: C.ink),
          decoration: _dec('Your password',
              suffix: IconButton(onPressed: () => setState(() => _show = !_show), icon: AgriIcon(_show ? 'eyeoff' : 'eye', size: 20, color: C.mute))),
        ),
        const SizedBox(height: 14),
        Turnstile(key: _cap, siteKey: kSiteKey, baseUrl: kBase, onToken: (t) => _token = t),
        if (_err != null)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_err!, style: nunito(13, w: FontWeight.w600, color: C.bad))),
        ClayButton(label: 'Sign in', busy: _busy, onTap: _go),
      ]),
    );
  }
}
