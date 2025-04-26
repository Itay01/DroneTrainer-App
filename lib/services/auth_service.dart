// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';

const _serverUrl = 'wss://192.168.1.50:8765'; // ⟵ adjust for prod
const _storage = FlutterSecureStorage(); // Android / iOS secure‑store

// ----------  Secure WebSocket  ----------
class SecureWS {
  SecureWS._(this._chan, this._aes, this._sharedKey, this._decryptedBroadcast);

  final IOWebSocketChannel _chan;
  final AesGcm _aes;
  final SecretKey _sharedKey;
  final Stream<Map<String, dynamic>> _decryptedBroadcast;

  /// Opens a TLS WebSocket, performs DH key exchange, and returns a SecureWS.
  static Future<SecureWS> connect() async {
    // 1. Open raw TLS WebSocket and make it broadcast-capable
    final chan = IOWebSocketChannel.connect(Uri.parse(_serverUrl));
    final raw = chan.stream.asBroadcastStream();

    // 2. X25519 Diffie-Hellman handshake
    final dh = X25519();
    final privKey = await dh.newKeyPair();
    final pubBytes = await privKey.extractPublicKey().then((k) => k.bytes);
    chan.sink.add(
      jsonEncode({
        'action': 'dh_key_exchange',
        'client_public_key': base64Encode(pubBytes),
      }),
    );

    // Receive server's public key
    final serverMsg = jsonDecode(await raw.first) as Map<String, dynamic>;
    final serverPubKey = SimplePublicKey(
      base64Decode(serverMsg['server_public_key'] as String),
      type: KeyPairType.x25519,
    );
    final shared = await dh.sharedSecretKey(
      keyPair: privKey,
      remotePublicKey: serverPubKey,
    );

    // 3. Set up decryption pipeline
    final aes = AesGcm.with256bits();
    final decrypted = raw.asyncMap<Map<String, dynamic>>((rawMsg) async {
      final data = jsonDecode(rawMsg) as Map<String, dynamic>;
      // If unencrypted, forward directly
      if (data['nonce'] == null || data['ciphertext'] == null) {
        return data;
      }
      final nonce = base64Decode(data['nonce'] as String);
      final combined = base64Decode(data['ciphertext'] as String);
      const tagLen = 16;
      final tag = combined.sublist(combined.length - tagLen);
      final cipherText = combined.sublist(0, combined.length - tagLen);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));
      final plain = await aes.decrypt(secretBox, secretKey: shared);
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    });

    // 4. Broadcast the decrypted stream so multiple listeners can subscribe
    final broadcast = decrypted.asBroadcastStream();

    return SecureWS._(chan, aes, shared, broadcast);
  }

  /// Encrypts [obj] with AES-GCM and sends over the socket.
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

  /// Returns a broadcast stream of decrypted JSON messages.
  Stream<Map<String, dynamic>> stream() => _decryptedBroadcast;

  /// Closes the underlying WebSocket connection.
  void close() => _chan.sink.close();

  static List<int> _random(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
}

// ----------  AuthService singleton  ----------
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  late SecureWS _ws;
  String? _access;
  String? _refresh;
  String? sessionId;

  /// Call on app startup. Returns true if we had valid tokens.
  Future<bool> init() async {
    _access = await _storage.read(key: 'access');
    _refresh = await _storage.read(key: 'refresh');
    sessionId = await _storage.read(key: 'session_id');

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

  /// Register a new user
  Future<void> register(String name, String email, String pw) async {
    await _ws.send({
      'action': 'register',
      'username': name,
      'email': email.toLowerCase(),
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
    _access = _refresh = sessionId = null;
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

  Future<List> getDroneList() async {
    // 1. send the request
    await _ws.send({'action': 'list_registered_drones', 'token': token});
    // 2. get the (decrypted) response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    // server returns {"drones": [{...}]}
    return resp['drones'] as List;
  }

  /// Registers a new drone on the server under the current user.
  Future<void> registerDrone(String name, String ip) async {
    // 1. send the request
    await _ws.send({
      'action': 'register_drone',
      'drone_name': name,
      'drone_ip': ip,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    // if you expect any data back (e.g. drone_id), you can parse it here.
  }

  /// Connects to a drone.
  Future<void> connectDrone(String droneName) async {
    // 1. send the request
    await _ws.send({
      'action': 'connect',
      'drone_name': droneName,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    _storage.write(key: 'session_id', value: resp['session_id'] as String);
  }

  /// Initiates takeoff with the given height.
  Future<void> takeoff(double height) async {
    // 1. send the request
    await _ws.send({'action': 'takeoff', 'height': height, 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  /// Retrieves the overlay image for the track.
  Future<Uint8List> captureFrame({bool overlay = false}) async {
    // 1. send the request
    await _ws.send({
      'action': 'capture_frame',
      'overlay': overlay,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    return base64Decode(resp['image'] as String);
  }

  Future<void> chooseLane(double clickX, double clickY) async {
    // 1. send the request
    await _ws.send({
      'action': 'choose_lane',
      'click_x': clickX,
      'click_y': clickY,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<void> setSpeed(double speed) async {
    // convert from km/h to m/s
    double speedMs = ((speed * 1000) / 3600);

    // 1. send the request
    await _ws.send({'action': 'set_speed', 'speed': speedMs, 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<void> setAltitude(double altitude) async {
    // 1. send the request
    await _ws.send({
      'action': 'set_height',
      'height': altitude,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<void> startFly() async {
    // 1. send the request
    await _ws.send({'action': 'start_fly', 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<List<dynamic>> getCurrentSessions() async {
    // 1. send the request
    await _ws.send({'action': 'list_current_sessions', 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
    return resp['sessions'] as List;
  }

  Future<void> stopFly() async {
    // 1. send the request
    await _ws.send({'action': 'stop_fly', 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<void> land() async {
    // 1. send the request
    await _ws.send({'action': 'land', 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }

  Future<void> disconnectDrone() async {
    // 1. send the request
    await _ws.send({'action': 'disconnect', 'token': token});

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }

    // 3. clear session ID
    await _storage.delete(key: 'session_id');
  }

  /// Subscribe to live telemetry; fires every time the server pushes a telemetry event.
  Stream<Map<String, dynamic>> subscribeTelemetry() {
    return Stream<Map<String, dynamic>>.multi((controller) async {
      // 1) send the subscribe request & wait for it to flush
      try {
        await _ws.send({'action': 'subscribe_telemetry', 'token': token});
        print('📡 [AuthService] subscribe_telemetry sent');
      } catch (e, st) {
        controller.addError(e, st);
        return;
      }

      // 2) now listen for only telemetry events
      final sub = _ws
          .stream()
          .where((msg) => msg['event'] == 'telemetry')
          .listen(
            (msg) {
              controller.add(msg);
            },
            onError: controller.addError,
            onDone: controller.close,
          );

      // cancel when the controller is cancelled
      controller.onCancel = sub.cancel;
    });
  }

  Future<void> unsubscribeTelemetry() async {
    _ws.send({'action': 'unsubscribe_telemetry', 'token': token});
  }

  /// Subscribe to live video; each event is a base64‐encoded JPEG.
  Stream<List<Uint8List>> subscribeVideo({bool overlay = false}) {
    return Stream<List<Uint8List>>.multi((controller) async {
      // send subscribe request (include overlay flag if you want)
      await _ws.send({
        'action': 'subscribe_video',
        'overlay': overlay,
        'token': token,
      });
      print('📹 [AuthService] subscribe_video sent');

      // listen for only video_frame events
      final sub = _ws
          .stream()
          .where((msg) => msg['event'] == 'video_frame')
          .listen(
            (msg) {
              final b64 = msg['data']["frame"] as String;
              final b64Front = msg['data']["front_frame"] as String;
              controller.add([base64Decode(b64), base64Decode(b64Front)]);
            },
            onError: controller.addError,
            onDone: controller.close,
          );

      controller.onCancel = sub.cancel;
    });
  }

  /// Unsubscribes from the video stream.
  Future<void> unsubscribeVideo() async {
    await _ws.send({'action': 'unsubscribe_video', 'token': token});
  }

  /// Ends the session with the given ID.
  Future<void> endSession(String sessionId) async {
    // 1. send the request
    await _ws.send({
      'action': 'end_session',
      'session_id': sessionId,
      'token': token,
    });

    // 2. await the first decrypted response
    final resp = await _ws.stream().first;
    print(resp);
    if (resp['error'] != null) {
      throw Exception(resp['error']);
    }
  }
}
