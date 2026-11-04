import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/browser/domain/address.dart';

void main() {
  test('typed addresses', () {
    expect('${addressToUri('https://example.com/a')}', 'https://example.com/a');
    expect('${addressToUri('localhost:8080')}', 'http://localhost:8080');
    expect('${addressToUri('192.0.2.10:3000/x')}', 'http://192.0.2.10:3000/x');
    expect('${addressToUri('example.com')}', 'https://example.com');
    expect('${addressToUri('nas.local')}', 'http://nas.local');
    expect(addressToUri('how to exit vim').host, 'duckduckgo.com');
    expect(addressToUri('how to exit vim').queryParameters['q'], 'how to exit vim');
    expect('${forwardedPortUri(15432)}', 'http://localhost:15432/');
  });
}
