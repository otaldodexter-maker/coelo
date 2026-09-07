---
title: "Agenda — estados de leitura por canal e UI contextual"
source: "specs/050-superadmin-agenda"
status: "local-partial; sem promoção E2E"
generated_at: "2026-09-07"
---

# Recorte e resultado

Superadmin, calendário/lista e detalhe de Agenda. Estados tipados por canal
e ID distinguem idle/loading/ready/notFound/unauthorized/failure. A UI não
mostra snapshot sensível em falha/negação, nem falso not-found durante leitura.
Retry preserva período/ID; detalhe permite retorno durante carregamento.
Prototype continua restrito ao uso já existente; testes novos exercitam o
repository Supabase real com transporte HTTP simulado, não banco real.

## Evidência local

- Regressão funcional selecionada Agenda: 113/113 antes do último caso de
  clipping; suíte de estados final: 14/14, incluindo esse caso e 12 goldens.
- Repository: 34/34 após reforçar estados finais da invalidação por exclusão.
- Matriz de estados: 24 combinações de superfície, tema e largura, texto 200%.
- RED de clipping 375x800/texto 200%: botão terminava em y776 com viewport até
  y752. GREEN após reservar padding externo e altura escalada da ação.
- 12 novas imagens inspecionadas: calendário/detalhe, loading/failure/denied,
  mobile escuro texto 200% e desktop claro. Nenhum baseline antigo atualizado.
- Validador de contratos visuais passou sem mudança de allowlist.
- Goldens antigos: 28 passaram/14 falharam na suíte combinada. Sonda temporária
  com código do calendário de HEAD reproduziu 14 falhas (4 passaram), incluindo
  os mesmos 17,65%/79415 pixels no calendário dark375. Sonda removida após uso.
  As 24 superfícies adicionais passaram. Divergências antigas permanecem abertas.
- Review independente identificou clipping e ausência de garantia pelo mero
  tamanho do botão; teste agora exige retângulo visível e hit-test após scroll.

## Limites e próximo gate

Nenhuma RPC executada em banco, escrita remota, persistência/reload de sessão
real, tenant A/B ou fluxo produtivo comprovado nesta fatia. Nenhum action_id
promovido a verified/done/verified-e2e. Router, shell e design system intactos.
Concorrência entre canais que compartilham cache e demais ações da Agenda
continuam exigindo provas específicas. Item ready não garante presença no
cache: a UI oferece atualização quando não há item, sem afirmar 404.

Memória: no-op; estados concretizam contrato aprovado, sem nova regra de produto.
