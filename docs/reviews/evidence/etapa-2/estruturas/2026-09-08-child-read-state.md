---
title: "CHILD-READSTATE01 — página e cursor com invalidação local"
source: "autorização da coordenação; docs/superpowers/plans/2026-09-08-child-read-state.md"
status: "local-verified-no-ui-no-wiring-not-e2e"
generated_at: "2026-09-08"
---

# Recorte entregue

Controller conserva somente uma página. Sessão, instituição/filtro, revisão ou
reader diferentes limpam página/cursor e invalidam operações antigas. Reload
reinicia sem cursor. NextPage usa cursor opaco somente no estado ready e não
duplica chamada enquanto loading. Sem cache acumulado, retry automático ou UI.

Generation e snapshot do reader/request antes de notifyListeners impedem
dispatch antigo reentrante. Sucesso/erro atrasado e completions após dispose
não publicam dados. Falha ou negativa atual deixa página nula. Instituição
malformada não aciona transporte; resposta com instituição divergente não
aparece. Esses controles cliente não são autorização remota.

## Verificação

- RED inicial por ausência do controller/tipos; depois12 PASS, ampliados a16.
- Regressão Children+Locais:123 PASS, sem atualizar goldens.
- Revisão readonly sem P1/P2. Sugestão de fidelidade das fixtures aplicada:
  página com cursor tem20 itens e último context_id correspondente;16 testes
  focais PASS novamente após essa mudança somente de fixture.
- Analyzer nominal: zero issues antes da alteração de fixture; validação final
  repetida no fechamento. Memória: ambos os gates PASS; projeção no-op.

Testes: gate de sessão, default indisponível, primeira/próxima página, chamada
duplicada, reload, filtro removido, instituição errada, revisão/reader/sessão
alterados durante espera, negativa atual/antiga, dispose e listeners reentrantes.

Nenhum controller conectado à aplicação, tela, rota ou DI. SQL, capabilities,
grants, hierarquia completa, busca, comandos e detalhe046 permanecem intactos.
No próximo gate, integração deve ligar revisão/sessão reais e provar o ciclo
inteiro; mock ou estes testes não certificam E2E. Checkpoint03:20 preservado.
