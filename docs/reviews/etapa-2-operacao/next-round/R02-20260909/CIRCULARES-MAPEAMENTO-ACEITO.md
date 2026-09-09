---
title: "R02 Circulares — mapeamento reconciliado D00 r1"
source: "specs/037-principal-circulars.md; prompts/D00.md; proposta L01 de 2026-09-09"
status: "accepted-mapping-not-product-certification"
generated_at: "2026-09-09"
---

D00 recebeu a proposta L01 observada às13:03 e reconciliou a cobertura exigida pelo Owner. Escopo funcional já aprovado na spec037; não cria nova função nem autorização remota.

IDs aceitos: `circulars.list`, `circulars.filter`, `circulars.create`, `circulars.edit`, `circulars.detail`, `circulars.schedule`, `circulars.publish`, `circulars.close`, `circulars.delete`, `circulars.respond`, `circulars.attach`.

`circulars.happens-card` é subaceite obrigatório de `acontece.feed`, sem ID adicional: projeção única, autorizada, ordem por publicação e abertura do detalhe. L01 mantém contrato e composição do feed. A aba Circulares, prévia contextual e abertura no Perfil permanecem subaceites de `principal.profile-view` (L03 consumidor; L01 contrato). `circulars.error`, `access-denied` e `reload` ficam estados/aceites das ações de diretório/filtro/detalhe, sem contagem autônoma. Não retirar esses testes do plano.

Seleção:136→147 IDs;120→131 MVP E2E. L01:12→23. Global:219→230 IDs;187→198 E2E ativos; FE2/230,BE0/223,E2E0/198 certificados. Restante fora da seleção continua83 IDs/67 E2E. Todos os11 novos IDs nascem pending-verification. Home continua lacuna sem ID/dono; granularidade das subtelas e duas superfícies Chat continua obrigação explícita. Baseline de abertura preservada; novo denominador mede cobertura, não regressão.

As dependências de decisão da proposta são corrigidas: R2 privado para mídia nova já aprovado; shell preservado web/mobile no Superadmin; editor Principal próprio já aprovado. Paridade local de gateway e composição pertencem à execução autorizada, com reservas pontuais de compartilhados. Operação remota continua exigindo pacote nominal. Exclusão deve preservar histórico e auditoria conforme spec; qualquer lacuna de regra real deve ser descrita pontualmente, sem bloquear trabalho independente.

Fonte da proposta: C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-l01-publicacoes/docs/reviews/etapa-2-operacao/next-round/R02-20260909/propostas/L01-circulares-mapeamento.md
SHA256: db41ccba27a41c81df774e7379ad46b7441b7c3e9750a0693b9dacbc848acb65
A proposta original pode evoluir; este recibo é a decisão da versão observada. Inventário, escopo e três matrizes atualizados juntos.
