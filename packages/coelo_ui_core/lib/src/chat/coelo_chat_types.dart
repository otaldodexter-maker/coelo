enum CoeloNowState { none, unseen, seen }

enum CoeloChatPresence { none, available, unavailable }

enum CoeloMessageDirection { received, sent }

enum CoeloMessageDeliveryState { none, sending, sent, delivered, read, failed }

extension CoeloMessageDeliveryStateLabel on CoeloMessageDeliveryState {
  String get label => switch (this) {
    CoeloMessageDeliveryState.none => '',
    CoeloMessageDeliveryState.sending => 'Enviando',
    CoeloMessageDeliveryState.sent => 'Enviada',
    CoeloMessageDeliveryState.delivered => 'Entregue',
    CoeloMessageDeliveryState.read => 'Lida',
    CoeloMessageDeliveryState.failed => 'Falha no envio',
  };
}
