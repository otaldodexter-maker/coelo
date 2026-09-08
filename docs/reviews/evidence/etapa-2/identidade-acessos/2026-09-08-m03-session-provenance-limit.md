---
title: "M03 — limite da proveniência operacional da sessão"
source: "pedido focal do Coordenador; fontes nominais Engenheiro 2; spec 039"
status: "contract-gate-open; no-helper-implemented"
generated_at: "2026-09-08"
---

# Parecer nominal

Não há delta verificável que feche o guard de proveniência operacional.
Leitura focal integral das seções 360–445 de
`docs/reviews/evidence/etapa-2/engenheiro-2/plano-e-revisoes-2026-09-07.md` na
árvore central: fontes GoTrue 2.196.0, commit
`0204331ca41a5b49f076b6fa3dc6c0d20b996590`, default local, não versão remota.
A spec 039 mantém senha/OTP/recovery/reset fora de sua implementação.
Busca nominal nas migrations `20260901*.sql` não encontrou guard AMR/recovery.

- AAL persistido exato 1/2 é nível, não comprovação de origem operacional.
- Recovery PKCE explícito deve ser negado; MFA não muda seu propósito.
- Verify implicit/POST pode registrar OTP também para recovery. Ausência de
  `recovery`, AMR vazio ou inválido não demonstra origem operacional admitida.
- Copiar a categoria upstream IsRecovery para banir todo OTP/MagicLink
  ampliaria a política sem contrato aprovado.

Portanto E2E 3 não deve depender de um helper supostamente pronto. Permanece
aberto o contrato nominal server-side dos fluxos admitidos e sua proveniência,
com teste correspondente. Barreira users→sessions, ban/deleted_at e AAL estrito
são requisitos separados: não resolvem essa distinção por si.

Nenhum helper, migration, Auth global, regra nova, SQL, Docker ou remoto foi
alterado. Parecer de fontes/limite, não execução de GoTrue nem teste concorrente.
Gate de memória: sem decisão de produto nova; não criar projeção Knowledge.
