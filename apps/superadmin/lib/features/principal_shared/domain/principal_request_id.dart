import 'dart:math';

/// Chave de idempotencia de uma intencao de escrita do Principal.
///
/// Gerar a chave dentro do repositorio, na hora da chamada, faz o cliente
/// PERDER a capacidade de repetir a MESMA intencao: cada tentativa vira uma
/// intencao nova aos olhos do servidor, e uma publicacao repetida para familias
/// e dano visivel. Quem e dono da intencao — o controlador — retem a chave
/// enquanto a intencao viver e a descarta quando ela muda.
///
/// Isto nao afirma que a RPC seja nao idempotente no servidor; afirma que o
/// cliente precisa conseguir reapresentar a mesma chave.
String newPrincipalRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}
