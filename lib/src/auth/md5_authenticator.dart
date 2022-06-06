import 'dart:convert';

import 'package:buffer/buffer.dart';
import 'package:crypto/crypto.dart';

import '../../postgres.dart';
import '../client_messages.dart';
import '../connection_config.dart';
import '../server_messages.dart';
import '../utf8_backed_string.dart';
import 'auth.dart';

class MD5Authenticator extends PostgresAuthenticator {
  static final String name = 'MD5';

  MD5Authenticator(PostgreSQLConnection connection, ConnectionConfig config)
      : super(connection, config);

  @override
  void onMessage(AuthenticationMessage message) {
    final reader = ByteDataReader()..add(message.bytes);
    final salt = reader.read(4, copy: true);

    final authMessage = AuthMD5Message(
        connection.username!, connection.password!, salt, config.encoding);

    connection.socket!.add(authMessage.asBytes());
  }
}

class AuthMD5Message extends ClientMessage {
  UTF8BackedString? _hashedAuthString;

  AuthMD5Message(String username, String password, List<int> saltBytes,
      Encoding encoding) {
    final passwordHash = md5.convert('$password$username'.codeUnits).toString();
    final saltString = String.fromCharCodes(saltBytes);
    final md5Hash =
        md5.convert('$passwordHash$saltString'.codeUnits).toString();
    _hashedAuthString = UTF8BackedString('md5$md5Hash', encoding);
  }

  @override
  void applyToBuffer(ByteDataWriter buffer) {
    buffer.writeUint8(ClientMessage.PasswordIdentifier);
    final length = 5 + _hashedAuthString!.utf8Length;
    buffer.writeUint32(length);
    _hashedAuthString!.applyToBuffer(buffer);
  }
}
