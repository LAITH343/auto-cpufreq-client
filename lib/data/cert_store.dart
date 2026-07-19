import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// A certificate that has been picked and parsed but not yet trusted. The
/// [fingerprint] is shown to the user for the compare-and-trust step before it
/// is saved.
class PickedCert {
  final String sourceName;

  /// Normalised PEM text (a DER input is re-wrapped as PEM so the saved file is
  /// always PEM, which both the trust store and pinning read back uniformly).
  final String pem;

  /// SHA-256 of the DER, upper-case hex, colon separated.
  final String fingerprint;

  const PickedCert({
    required this.sourceName,
    required this.pem,
    required this.fingerprint,
  });
}

/// Raised when a picked file is not a parseable X.509 certificate.
class InvalidCertException implements Exception {
  final String message;
  InvalidCertException(this.message);
  @override
  String toString() => message;
}

/// Picks certificates via the platform file picker and persists trusted ones in
/// the app's support directory so a stable, app-owned path can be linked to a
/// connection (the picker's own path is temporary on mobile).
class CertStore {
  static const _dirName = 'certs';

  /// Opens the platform picker (all desktop + mobile platforms) and parses the
  /// selection. Returns null if the user cancels. Throws [InvalidCertException]
  /// if the file is not a certificate.
  static Future<PickedCert?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem', 'crt', 'cer', 'der'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      throw InvalidCertException('Could not read the selected file.');
    }
    return _parse(file.name, bytes);
  }

  /// Writes [cert] into app storage and returns the stable file path to link to
  /// the connection.
  static Future<String> save(PickedCert cert) =>
      _write(cert.pem, cert.fingerprint);

  /// Persists a certificate captured live during a TLS handshake (its raw DER),
  /// returning the stable file path to link to the connection.
  static Future<String> saveDer(List<int> der) => _write(pemOf(der), fingerprintOf(der));

  /// SHA-256 of a DER certificate, upper-case hex, colon separated.
  static String fingerprintOf(List<int> der) => sha256
      .convert(der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(':')
      .toUpperCase();

  static String pemOf(List<int> der) => _toPem(der);

  static Future<String> _write(String pem, String fingerprint) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = fingerprint.replaceAll(':', '').toLowerCase();
    final path = '${dir.path}/$safe.pem';
    await File(path).writeAsString(pem);
    return path;
  }

  static PickedCert _parse(String name, List<int> bytes) {
    final List<int> der;
    final text = _asText(bytes);
    if (text != null && text.contains('BEGIN CERTIFICATE')) {
      final b64 = RegExp(r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----')
          .firstMatch(text)
          ?.group(1)
          ?.replaceAll(RegExp(r'\s'), '');
      if (b64 == null || b64.isEmpty) {
        throw InvalidCertException('No certificate found in the file.');
      }
      try {
        der = base64.decode(b64);
      } catch (_) {
        throw InvalidCertException('The certificate is not valid base64.');
      }
    } else {
      // Assume a raw DER (.der / .cer) file.
      der = bytes;
    }
    // Validate that dart:io can parse it as an X.509 certificate.
    try {
      SecurityContext().setTrustedCertificatesBytes(_toPem(der).codeUnits);
    } catch (_) {
      throw InvalidCertException('The file is not a valid X.509 certificate.');
    }
    return PickedCert(sourceName: name, pem: _toPem(der), fingerprint: fingerprintOf(der));
  }

  static String? _asText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static String _toPem(List<int> der) {
    final b64 = base64.encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    return '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n-----END CERTIFICATE-----\n';
  }
}
