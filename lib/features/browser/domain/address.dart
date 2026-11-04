/// What the address bar opens for what was typed: a URL as is; `localhost:8080`, an IP address or a host
/// name with a dot as a site (http for local and private addresses, which forwarded ports usually are,
/// https otherwise); anything else as a web search.
Uri addressToUri(String input) {
  final text = input.trim();
  final parsed = Uri.tryParse(text);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https' || parsed.scheme == 'about')) {
    return parsed;
  }
  final host = text.split(RegExp(r'[/:?#]')).first.toLowerCase();
  final looksLikeHost = !text.contains(' ') && (host == 'localhost' || host.contains('.') || _ip.hasMatch(host));
  if (looksLikeHost) {
    final local = host == 'localhost' || _ip.hasMatch(host) || host.endsWith('.local') || host.endsWith('.lan');
    return Uri.parse('${local ? 'http' : 'https'}://$text');
  }
  return Uri.https('duckduckgo.com', '/', {'q': text});
}

final _ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// The address of a forwarded port on this device.
Uri forwardedPortUri(int port) => Uri.parse('http://localhost:$port/');
