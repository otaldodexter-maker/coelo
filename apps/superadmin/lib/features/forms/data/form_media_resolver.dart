import 'forms_backend_gateway.dart';

final class FormMediaDownloadTicket {
  const FormMediaDownloadTicket({required this.signedUrl, required this.expiresAt});

  final Uri signedUrl;
  final DateTime expiresAt;
}

final class FormMediaResolutionException implements Exception {
  const FormMediaResolutionException(this.message);

  final String message;

  @override
  String toString() => 'FormMediaResolutionException: $message';
}

final class FormMediaResolver {
  FormMediaResolver({
    required FormsBackendGateway backend,
    required String Function() requestIdFactory,
    DateTime Function()? now,
  }) : _backend = backend,
       _requestIdFactory = requestIdFactory,
       _now = now ?? DateTime.now;

  final FormsBackendGateway _backend;
  final String Function() _requestIdFactory;
  final DateTime Function() _now;

  Future<FormMediaDownloadTicket> resolve({required String assetId, String? editSecret}) async {
    try {
      final raw = await _backend.media({
        'action': 'download',
        'request_id': _requestIdFactory(),
        'expected_version': 0,
        'payload': {'asset_id': assetId, 'edit_secret': editSecret},
      });
      if (raw is! Map) throw const FormatException('invalid media response');
      final payload = Map<String, Object?>.from(raw);
      final signedUrl = Uri.tryParse(payload['signed_url'] as String? ?? '');
      final expiresIn = payload['expires_in'];
      if (signedUrl == null || !signedUrl.hasScheme || expiresIn is! num || expiresIn <= 0) {
        throw const FormatException('invalid media response');
      }
      return FormMediaDownloadTicket(
        signedUrl: signedUrl,
        expiresAt: _now().add(Duration(seconds: expiresIn.toInt())),
      );
    } catch (_) {
      throw const FormMediaResolutionException('Mídia indisponível.');
    }
  }
}
