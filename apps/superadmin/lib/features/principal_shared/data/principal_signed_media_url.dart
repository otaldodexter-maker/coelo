/// Validates a media URL redeemed from an authorised gateway before the client
/// ever loads it.
///
/// A redeemed ticket must come back as an absolute HTTPS URL with a host and no
/// embedded credentials. Anything else is refused: the gateway is trusted to
/// authorise, not to decide how the client transports bytes. Returns `null` when
/// the value cannot be used, so each caller maps it to its own honest state
/// instead of rendering a broken or plaintext source.
Uri? parsePrincipalSignedMediaUrl(Object? value) {
  final uri = Uri.tryParse(value?.toString().trim() ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}
