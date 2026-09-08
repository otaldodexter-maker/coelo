---
title: "Perfis e Modelos — autorização nas rotas de detalhe e edição"
source: "reserva nominal do Coordenador para quatro builders; regressão E2E 1"
status: "local-green; e2e-pending"
generated_at: "2026-09-08"
---

# Recorte e resultado

Quatro builders normais de detalhe/edição de Perfis/Modelos agora observam a
sessão e usam chave de identidade de rota/revisão de autorização. Callbacks,
paths, repositories, fallback e contratos de mídia permanecem intactos.
Não modifica CRUD, Auth ou regras server-side. Git agrupa os quatro builders
em três hunks; não há alteração fora deles.

Teste `access_profile_editor_authorization_test.dart`: router e repository
produtivos, SDK Supabase, HTTP sintético com resposta/status capturados antes
de cada espera. São oito casos: quatro rotas, snapshot carregado ou pendente.

- RED: 8/8 FAIL. Snapshot carregado permanecia após redução; Perfis aceitava
  resposta antiga. Models pendente já descartava pelo adapter, mas não
  recarregava sob a nova autorização.
- GREEN: 8/8 PASS; snapshot some antes da negação completar, sucesso tardio
  não reaparece e há exatamente uma nova chamada, terminando no erro esperado.
- Controle equivalente preserva a sessão, o estado e a contagem de chamadas.
- Regressão funcional conjunta: 169/169 PASS em data/domain/view-model/pages/
  detalhe Perfis, rotas normais/preview/invalidação/editor Perfis, rotas
  Usuários/detalhe, router geral e sessão.
- Analyzer router/teste: PASS. Format e diff check: PASS.
- Review independente realm_audit: sem bloqueantes, reserva e gates preservados.

## Limites

Não inclui create, troca de path A/B, save em voo, continuidade interna do
formulário, adapter multipágina/template/cache de writes, contrato catálogo
domain-only ou provas remotas. Os três goldens de Perfis continuam abertos
conforme evidência de continuidade do detalhe; masters não foram atualizados.
Sem SQL/remoto/mídia, não representa verified-e2e. Memória: restauração de
contrato existente, nenhuma regra nova; rastreadores sob autoria do Coordenador.
