import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'theme.dart';

/// Cloudflare Turnstile inside a tiny WebView. `baseUrl` must be a hostname allowed on the Turnstile widget,
/// so it uses the dashboard's own host (same trick as the Expo app).
class Turnstile extends StatefulWidget {
  const Turnstile({super.key, required this.siteKey, required this.baseUrl, required this.onToken});
  final String siteKey;
  final String baseUrl;
  final ValueChanged<String?> onToken;

  @override
  State<Turnstile> createState() => TurnstileState();
}

class TurnstileState extends State<Turnstile> {
  late final WebViewController _c;
  bool _err = false;

  String get _html => '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;background:transparent;overflow:hidden}#w{width:100%}</style>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer></script></head><body><div id="w"></div>
<script>
var post=function(o){Flutter.postMessage(JSON.stringify(o))};
var id=null;
function boot(){ if(!window.turnstile){return setTimeout(boot,150)}
  id=turnstile.render('#w',{sitekey:${jsonEncode(widget.siteKey)},action:'login',theme:'light',size:'flexible',retry:'auto','refresh-expired':'auto',
   callback:function(t){post({t:t})},'expired-callback':function(){post({t:null})},'timeout-callback':function(){post({t:null})},'error-callback':function(){post({t:null,error:1})}});}
boot();
window.resetWidget=function(){try{turnstile.reset(id)}catch(e){}};
</script></body></html>''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel('Flutter', onMessageReceived: (m) {
        try {
          final d = jsonDecode(m.message) as Map<String, dynamic>;
          if (mounted) setState(() => _err = d['error'] == 1);
          widget.onToken(d['t'] as String?);
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(onWebResourceError: (_) {
        if (mounted) setState(() => _err = true);
      }))
      ..loadHtmlString(_html, baseUrl: widget.baseUrl);
  }

  /// A token only works once: call after every failed attempt.
  void reset() {
    widget.onToken(null);
    _c.runJavaScript('window.resetWidget&&window.resetWidget();');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(children: [
        WebViewWidget(controller: _c),
        if (_err) Positioned(left: 0, bottom: 0, child: Text('The security check could not load.', style: nunito(12.5, color: C.bad))),
      ]),
    );
  }
}
