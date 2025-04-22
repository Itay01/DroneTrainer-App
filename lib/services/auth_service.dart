// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';

const _serverUrl = 'wss://192.168.1.50:8765'; // ⟵ adjust for prod
const _storage = FlutterSecureStorage(); // Android / iOS secure‑store

// ----------  Secure WebSocket  ----------
class SecureWS {
  SecureWS._(this._chan, this._aes, this._sharedKey, this._raw);
  final IOWebSocketChannel _chan;
  final AesGcm _aes;
  final SecretKey _sharedKey;
  final Stream<dynamic> _raw; // broadcast stream

  /// Opens a TLS WebSocket, does DH key‑exchange, and returns a SecureWS.
  static Future<SecureWS> connect() async {
    // 1. open raw TLS WS
    final chan = IOWebSocketChannel.connect(Uri.parse(_serverUrl));
    // 1a. convert to broadcast so we can subscribe more than once
    final raw = chan.stream.asBroadcastStream();

    // 2. X25519 DH handshake
    final dh = X25519();
    final priv = await dh.newKeyPair();
    final pubBytes = await priv.extractPublicKey().then((k) => k.bytes);
    chan.sink.add(
      jsonEncode({
        'action': 'dh_key_exchange',
        'client_public_key': base64Encode(pubBytes),
      }),
    );

    // receive server public key
    final srvMsg = jsonDecode(await raw.first) as Map;
    final srvPub = SimplePublicKey(
      base64Decode(srvMsg['server_public_key']),
      type: KeyPairType.x25519,
    );
    final shared = await dh.sharedSecretKey(
      keyPair: priv,
      remotePublicKey: srvPub,
    );

    return SecureWS._(chan, AesGcm.with256bits(), shared, raw);
  }

  /// Encrypts [obj] with AES‑GCM and sends over the socket.
  Future<void> send(Map<String, dynamic> obj) async {
    final nonce = _random(12);
    final secretBox = await _aes.encrypt(
      utf8.encode(jsonEncode(obj)),
      secretKey: _sharedKey,
      nonce: nonce,
    );
    // ◀ combine ciphertext + tag
    final combined = <int>[
      ...secretBox.cipherText,
      ...secretBox.mac.bytes, // ← include the 16‑byte tag
    ];
    _chan.sink.add(
      jsonEncode({
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(combined),
      }),
    );
  }

  /// Returns a stream of decrypted JSON messages.
  Stream<Map<String, dynamic>> stream() async* {
    await for (final rawMsg in _raw) {
      final data = jsonDecode(rawMsg) as Map<String, dynamic>;

      // If there's no nonce/ciphertext, just forward the raw payload
      if (data['nonce'] == null || data['ciphertext'] == null) {
        yield data;
        continue;
      }

      // decrypt as before
      final nonce = base64Decode(data['nonce'] as String);
      final combined = base64Decode(data['ciphertext'] as String);
      const tagLen = 16;
      final tag = combined.sublist(combined.length - tagLen);
      final cipherText = combined.sublist(0, combined.length - tagLen);

      final plain = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: _sharedKey,
      );

      yield jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    }
  }

  List<int> _random(int n) =>
      List<int>.generate(n, (_) => Random.secure().nextInt(256));

  void close() => _chan.sink.close();
}

// ----------  AuthService singleton  ----------
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  late SecureWS _ws;
  String? _access;
  String? _refresh;

  /// Call on app startup. Returns true if we had valid tokens.
  Future<bool> init() async {
    _access = await _storage.read(key: 'access');
    _refresh = await _storage.read(key: 'refresh');

    _ws = await SecureWS.connect();

    // No tokens → not logged in
    if (_access == null || _refresh == null) {
      return false;
    }

    // Try to refresh
    await _ws.send({'action': 'refresh_token', 'refresh_token': _refresh});
    final resp = await _ws.stream().first;

    if (resp['error'] != null) {
      await logout();
      return false;
    }

    _saveTokensChecked(resp);
    return true;
  }

  /// Login with email + password
  Future<void> login(String email, String pw) async {
    await _ws.send({'action': 'login', 'email': email, 'password': pw});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    _saveTokensChecked(resp);
  }

  /// Register a new user
  Future<void> register(String name, String email, String pw) async {
    await _ws.send({
      'action': 'register',
      'username': name,
      'email': email,
      'password': pw,
    });

    final resp = await _ws.stream().first;
    // DEBUG: print the full response so you can see what keys you actually got
    print('🔐 register response: $resp');

    // If server sent an error field that’s non-null, throw it
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }

    // Save tokens, but first check for null
    _saveTokensChecked(resp);
  }

  /// Clear stored tokens
  Future<void> logout() async {
    await _storage.deleteAll();
    _access = _refresh = null;
  }

  /// Extracts and saves tokens, throwing if any are missing or null.
  void _saveTokensChecked(Map<String, dynamic> resp) {
    final access = resp['access_token'] as String?;
    final refresh = resp['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw Exception('Missing token(s) in server response: $resp');
    }
    _access = access;
    _refresh = refresh;
    // These writes now definitely get non-null Strings
    _storage.write(key: 'access', value: _access!);
    _storage.write(key: 'refresh', value: _refresh!);
  }

  /// Current access token (throws if null)
  String get token {
    if (_access == null) {
      throw Exception('Not authenticated');
    }
    return _access!;
  }
}
