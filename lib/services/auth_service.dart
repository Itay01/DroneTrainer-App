import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';

/// Service URL for secure WebSocket connection.
const _serverUrl = 'wss://192.168.69.96:8765'; // ⟵ adjust for prod

/// Secure storage for tokens and session IDs.
const _storage = FlutterSecureStorage();

// ─────────────────────── Secure WebSocket ───────────────────────────
/// Wraps an [IOWebSocketChannel] to perform Diffie–Hellman key exchange
/// and AES-GCM encryption/decryption for all messages.
class SecureWS {
  SecureWS._(this._chan, this._aes, this._sharedKey, this._decryptedBroadcast);

  final IOWebSocketChannel _chan;
  final AesGcm _aes;
  final SecretKey _sharedKey;
  final Stream<Map<String, dynamic>> _decryptedBroadcast;

  /// Establishes a TLS WebSocket connection and performs X25519 DH handshake.
  /// Returns a [SecureWS] instance with encryption context.
  static Future<SecureWS> connect() async {
    // 1. Open raw TLS WebSocket
    final chan = IOWebSocketChannel.connect(Uri.parse(_serverUrl));
    final raw = chan.stream.asBroadcastStream();

    // 2. Generate ephemeral X25519 key pair and send client public key
    final dh = X25519();
    final privKey = await dh.newKeyPair();
    final pubBytes = await privKey.extractPublicKey().then((k) => k.bytes);
    chan.sink.add(
      jsonEncode({
        'action': 'dh_key_exchange',
        'client_public_key': base64Encode(pubBytes),
      }),
    );

    // 3. Receive server public key and compute shared secret
    final serverMsg = jsonDecode(await raw.first) as Map<String, dynamic>;
    final serverPubKey = SimplePublicKey(
      base64Decode(serverMsg['server_public_key'] as String),
      type: KeyPairType.x25519,
    );
    final shared = await dh.sharedSecretKey(
      keyPair: privKey,
      remotePublicKey: serverPubKey,
    );

    // 4. Set up AES-GCM for encryption/decryption
    final aes = AesGcm.with256bits();
    final decrypted = raw.asyncMap<Map<String, dynamic>>((rawMsg) async {
      final data = jsonDecode(rawMsg) as Map<String, dynamic>;
      // If message is plain JSON (no encryption), forward as-is
      if (data['nonce'] == null || data['ciphertext'] == null) {
        return data;
      }
      // Otherwise decrypt AES-GCM
      final nonce = base64Decode(data['nonce'] as String);
      final combined = base64Decode(data['ciphertext'] as String);
      const tagLen = 16;
      final tag = combined.sublist(combined.length - tagLen);
      final cipherText = combined.sublist(0, combined.length - tagLen);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));
      final plain = await aes.decrypt(secretBox, secretKey: shared);
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    });

    // Broadcast decrypted stream so multiple listeners can subscribe
    final broadcast = decrypted.asBroadcastStream();
    return SecureWS._(chan, aes, shared, broadcast);
  }

  /// Encrypts [obj] with AES-GCM and sends it over the socket.
  Future<void> send(Map<String, dynamic> obj) async {
    final nonce = _random(12);
    final secretBox = await _aes.encrypt(
      utf8.encode(jsonEncode(obj)),
      secretKey: _sharedKey,
      nonce: nonce,
    );
    final combined = <int>[...secretBox.cipherText, ...secretBox.mac.bytes];
    _chan.sink.add(
      jsonEncode({
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(combined),
      }),
    );
  }

  /// Provides a broadcast stream of decrypted JSON messages.
  Stream<Map<String, dynamic>> stream() => _decryptedBroadcast;

  /// Closes the underlying WebSocket connection.
  void close() => _chan.sink.close();

  /// Generates a secure random list of bytes of given [length].
  static List<int> _random(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
}

// ─────────────────────── AuthService Singleton ───────────────────────
/// Singleton service for authentication, token storage, and drone session management.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  late SecureWS _ws;
  String? _access;
  String? _refresh;
  String? sessionId;

  /// Initializes service: reads stored tokens and attempts refresh.
  /// Returns true if valid tokens exist and refresh succeeded.
  Future<bool> init() async {
    _access = await _storage.read(key: 'access');
    _refresh = await _storage.read(key: 'refresh');
    sessionId = await _storage.read(key: 'session_id');

    _ws = await SecureWS.connect();

    // If no tokens, user not authenticated
    if (_access == null || _refresh == null) {
      return false;
    }

    // Attempt to refresh access token
    await _ws.send({'action': 'refresh_token', 'refresh_token': _refresh});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) {
      await logout();
      return false;
    }
    _saveTokensChecked(resp);
    return true;
  }

  /// Performs login; throws on error.
  Future<void> login(String email, String pw) async {
    await _ws.send({
      'action': 'login',
      'email': email.toLowerCase(),
      'password': pw,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    _saveTokensChecked(resp);
  }

  /// Registers a new user; throws on error.
  Future<void> register(String name, String email, String pw) async {
    await _ws.send({
      'action': 'register',
      'username': name,
      'email': email.toLowerCase(),
      'password': pw,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    _saveTokensChecked(resp);
  }

  /// Clears stored tokens and session.
  Future<void> logout() async {
    await _storage.deleteAll();
    _access = _refresh = sessionId = '';
  }

  /// Extracts and persists tokens from server [resp].
  void _saveTokensChecked(Map<String, dynamic> resp) {
    final access = resp['access_token'] as String?;
    final refresh = resp['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw Exception('Missing token(s) in server response: \$resp');
    }
    _access = access;
    _refresh = refresh;
    _storage.write(key: 'access', value: access);
    _storage.write(key: 'refresh', value: refresh);
  }

  /// Returns current access token; throws if not authenticated.
  String get token {
    if (_access == null) {
      throw Exception('Not authenticated');
    }
    return _access!;
  }

  /// Requests list of registered drones; returns list data.
  Future<List> getDroneList() async {
    await _ws.send({'action': 'list_registered_drones', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
    return resp['drones'] as List;
  }

  /// Registers a new drone under the current user.
  Future<void> registerDrone(String name, String ip) async {
    await _ws.send({
      'action': 'register_drone',
      'drone_name': name,
      'drone_ip': ip,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Connects to a drone by name, storing session ID.
  Future<void> connectDrone(String droneName) async {
    await _ws.send({
      'action': 'connect',
      'drone_name': droneName,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
    sessionId = resp['session_id'] as String;
    _storage.write(key: 'session_id', value: sessionId!);
  }

  /// Commands the drone to take off to [height] meters.
  Future<void> takeoff(double height) async {
    await _ws.send({'action': 'takeoff', 'height': height, 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Captures a frame (overlay optional) and returns bytes.
  Future<Uint8List> captureFrame({bool overlay = false}) async {
    await _ws.send({
      'action': 'capture_frame',
      'overlay': overlay,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
    return base64Decode(resp['image'] as String);
  }

  /// Selects a lane at image coords (clickX, clickY).
  Future<void> chooseLane(double clickX, double clickY) async {
    await _ws.send({
      'action': 'choose_lane',
      'click_x': clickX,
      'click_y': clickY,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Sets forward speed (km/h converted to m/s internally).
  Future<void> setSpeed(double speed) async {
    final speedMs = speed * 1000 / 3600;
    await _ws.send({'action': 'set_speed', 'speed': speedMs, 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Sets target altitude (meters).
  Future<void> setAltitude(double altitude) async {
    await _ws.send({
      'action': 'set_height',
      'height': altitude,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Starts the flight loop on the server.
  Future<void> startFly() async {
    await _ws.send({'action': 'start_fly', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Retrieves current sessions for this user.
  Future<List<dynamic>> getCurrentSessions() async {
    await _ws.send({'action': 'list_current_sessions', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
    return resp['sessions'] as List;
  }

  /// Stops the flight loop on the server.
  Future<void> stopFly() async {
    await _ws.send({'action': 'stop_fly', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Commands the drone to land.
  Future<void> land() async {
    await _ws.send({'action': 'land', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }

  /// Disconnects the drone and clears session ID.
  Future<void> disconnectDrone() async {
    await _ws.send({'action': 'disconnect', 'token': token});
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
    await _storage.delete(key: 'session_id');
  }

  /// Subscribes to live telemetry events from the server.
  /// Returns a [Stream] of telemetry maps.
  Stream<Map<String, dynamic>> subscribeTelemetry() {
    return Stream<Map<String, dynamic>>.multi((controller) async {
      // Send subscribe request
      try {
        await _ws.send({'action': 'subscribe_telemetry', 'token': token});
      } catch (e, st) {
        controller.addError(e, st);
        return;
      }
      // Forward only telemetry events
      final sub = _ws
          .stream()
          .where((msg) => msg['event'] == 'telemetry')
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
      controller.onCancel = sub.cancel;
    });
  }

  /// Unsubscribes from telemetry updates.
  Future<void> unsubscribeTelemetry() async {
    _ws.send({'action': 'unsubscribe_telemetry', 'token': token});
  }

  /// Subscribes to live video frames; toggles overlay via [overlay].
  Stream<List<Uint8List>> subscribeVideo({bool overlay = false}) {
    return Stream<List<Uint8List>>.multi((controller) async {
      await _ws.send({
        'action': 'subscribe_video',
        'overlay': overlay,
        'token': token,
      });
      final sub = _ws
          .stream()
          .where((msg) => msg['event'] == 'video_frame')
          .listen(
            (msg) {
              final b0 = msg['data']['frame'] as String;
              final b1 = msg['data']['front_frame'] as String;
              controller.add([base64Decode(b0), base64Decode(b1)]);
            },
            onError: controller.addError,
            onDone: controller.close,
          );
      controller.onCancel = sub.cancel;
    });
  }

  /// Unsubscribes from video frames.
  Future<void> unsubscribeVideo() async {
    await _ws.send({'action': 'unsubscribe_video', 'token': token});
  }

  /// Ends the server session identified by [sessionId].
  Future<void> endSession(String sessionId) async {
    await _ws.send({
      'action': 'end_session',
      'session_id': sessionId,
      'token': token,
    });
    final resp = await _ws.stream().first;
    if (resp['error'] != null) throw Exception(resp['error']);
  }
}
