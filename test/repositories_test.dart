import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/data/connection_repository.dart';
import 'package:nux/features/connections/data/known_hosts_repository.dart';
import 'package:nux/features/connections/domain/host_key_check.dart';
import 'package:nux/features/identities/data/identity_repository.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_import.dart';
import 'package:nux/features/identities/domain/key_material.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late MemorySecretStore secrets;
  late ConnectionRepository connections;
  late IdentityRepository identities;
  late KnownHostsRepository known;

  setUp(() {
    db = memoryDb();
    secrets = MemorySecretStore();
    connections = ConnectionRepository(db, secrets);
    identities = IdentityRepository(db, secrets, connections);
    known = KnownHostsRepository(db);
  });
  tearDown(() => db.close());

  Future<String> addConnection({List<String> keys = const []}) => connections.save(ConnectionsCompanion.insert(
        name: 'build',
        host: 'build.example.com',
        username: 'dev',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        identityIds: Value(encodeIdentityIds(keys)),
      ));

  test('identities keep the private key out of the database', () async {
    final key = await generateKey(KeyAlgorithm.ed25519, comment: 'nux@test');
    final id = await identities.add(key, name: 'Laptop', passphrase: 'pw');
    final row = (await identities.get(id))!;
    expect(row.publicKey, key.publicLine());
    expect(row.fingerprint, sha256Fingerprint(key.publicBlob));
    expect(row.encrypted, isTrue);
    expect(secrets.values[IdentityRepository.keySecretId(id)], contains('OPENSSH PRIVATE KEY'));

    expect(() => identities.unlock(id), throwsA(isA<KeyImportException>()));
    expect((await identities.unlock(id, passphrase: 'pw')).publicLine(), key.publicLine());

    await identities.changePassphrase(id, oldPassphrase: 'pw');
    expect((await identities.get(id))!.encrypted, isFalse);
    expect((await identities.unlock(id)).publicLine(), key.publicLine());
  });

  test('deleting an identity removes it from connections and secure storage', () async {
    final a = await identities.add(await generateKey(KeyAlgorithm.ed25519), name: 'a');
    final b = await identities.add(await generateKey(KeyAlgorithm.ed25519), name: 'b');
    final c = await addConnection(keys: [a, b]);
    expect((await identities.usedBy(a)).map((c) => c.id), [c]);
    await identities.delete(a);
    expect((await connections.get(c))!.identityIdList, [b]);
    expect(await secrets.ids(prefix: 'key:'), {IdentityRepository.keySecretId(b)});
  });

  test('saved passwords live in secure storage', () async {
    final c = await addConnection();
    await connections.setSavedPassword(c, 'hunter2');
    expect((await connections.get(c))!.savePassword, isTrue);
    expect(await connections.savedPassword(c), 'hunter2');
    await connections.delete(c);
    expect(secrets.values, isEmpty);
  });

  test('preferIdentity moves a key to the front', () async {
    final c = await addConnection(keys: ['x', 'y']);
    await connections.preferIdentity(c, 'y');
    expect((await connections.get(c))!.identityIdList, ['y', 'x']);
    await connections.preferIdentity(c, 'z');
    expect((await connections.get(c))!.identityIdList, ['z', 'y', 'x']);
  });

  test('known hosts: trust on first use, then detect changes', () async {
    const host = 'Build.Example.com';
    expect(await known.check(host, 22, 'ssh-ed25519', 'SHA256:aaa'), HostKeyStatus.unknown);
    await known.trust(host, 22, 'ssh-ed25519', 'SHA256:aaa');
    expect(await known.check('build.example.com', 22, 'ssh-ed25519', 'SHA256:aaa'), HostKeyStatus.trusted);
    expect(await known.check(host, 2222, 'ssh-ed25519', 'SHA256:aaa'), HostKeyStatus.unknown);
    expect(await known.check(host, 22, 'ssh-ed25519', 'SHA256:bbb'), HostKeyStatus.changed);
    expect(await known.check(host, 22, 'ssh-rsa', 'SHA256:ccc'), HostKeyStatus.newKeyType);
    await known.trust(host, 22, 'ssh-ed25519', 'SHA256:bbb');
    expect((await known.forHost(host, 22)).single.fingerprint, 'SHA256:bbb');
  });

  test('quick connect targets', () {
    QuickTarget? p(String s) => QuickTarget.tryParse(s);
    expect(p('example.com')?.host, 'example.com');
    expect(p('dev@example.com:2222')?.username, 'dev');
    expect(p('dev@example.com:2222')?.port, 2222);
    expect(p('root@[2001:db8::1]:22')?.host, '2001:db8::1');
    expect(p('192.0.2.4')?.port, isNull);
    expect(p('a b'), isNull);
    expect(p('host:99999'), isNull);
  });
}
