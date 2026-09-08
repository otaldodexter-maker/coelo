---
title: "Locais — contrato puro de seleção compartilhada"
source: "desenho aprovado de Locais em2026-09-02; escopo E2E2 do Owner; crosswalk local"
status: "proposed-local-package; awaiting-coordinator-reservation"
generated_at: "2026-09-07"
---

# Objetivo

Fornecer vocabulário Dart puro para a seleção de local pelos consumidores,
sem duplicar catálogo ou vincular o domínio a Flutter/Supabase. Este pacote é
um incremento da fundação Locais; não implementa os sete fluxos nem os certifica.

## Alternativas

1. Contrato compartilhado mínimo e barrel próprio: recomendado, sem disputar
   coelo_domain.dart com Formulários e sem acoplar o domínio a uma UI.
2. DTO separado em cada app/consumidor: permitiria avançar isoladamente, mas
   duplicaria significado de escopo e catalogado/pontual.
3. Reutilizar activity_locations: rejeitado para este pacote, pois a estrutura
   existente é unit-only e não constitui catálogo institucional independente.

## Contrato proposto

- LocationScope representa instituição ou unidade de maneira explícita;
  escopo da unidade inclui institutionId e unitId, sem inferir parentesco.
- LocationKind distingue interno/externo.
- LocationReferenceSnapshot é imutável: id estável, scope, kind e label.
- LocationSelection distingue referência catalogada de texto pontual.
  Pontual não recebe id fictício nem participação automática no catálogo.
- Nenhum método confere capability, decide visibilidade, resolve tenant,
  reserva horário, grava vínculo ou promove texto pontual ao catálogo.
- Nenhum parse/serializer de RPC, caminho de objeto, URL, R2 ou segredo.
- Sem política nova de UUID, tamanho, normalização ou endereço: constraints
  server-side ficam no contrato de cadastro a aprovar nominalmente.

## Arquivos e ownership

Somente packages/coelo_domain/lib/locations.dart,
packages/coelo_domain/lib/src/locations/location_selection.dart e
packages/coelo_domain/test/locations/location_selection_test.dart, além deste
design/plano/evidência. Nenhum arquivo existente precisa de modificação.
Sem migrations/ledger/router/UI/Forms/Activities/Eventos/reservas/Gateway.

## Testes e aceite local

Testes Dart distinguem os dois escopos, conservam IDs e rótulo do snapshot,
representam catalogado/pontual sem conversão implícita e comprovam que um
snapshot continua independente de substituições posteriores pelo consumidor.
Analyzer e suíte do pacote não podem ganhar falhas. Review independente antes
do handoff. Contratos de produção e E2E seguem abertos.

## Self-review

Recorte sem dependência remota ou decisão de público/permissão. Não cria um
catálogo paralelo, não renomeia tabela existente e não concede acesso a partir
do tipo Dart. Endereço e proveniência pertencem ao cadastro/detalhe futuro,
não a esta referência mínima de seleção. A reserva nominal precede código.
