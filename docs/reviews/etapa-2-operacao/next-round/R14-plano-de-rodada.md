---
source: R12-prompt-unico.md; R12-pendencias.md
status: preparado; execução não autorizada automaticamente
generated_at: 2026-09-13
---

# Ordem de continuidade

1. Reconciliar base real, instruções, slots, cota e configuração; usar somente
   checkout dev consolidado e sintéticos já retidos.
2. R12-52: build atual e prova da rota normal, mídia privada/reload/escopo.
   R12-44/45 exigem QA equivalente; reenvio só no convite sintético permitido.
3. R12-34–37/42: provar correções locais recentes no runtime, corrigir regressões
   encontradas. Wizard/serialização 58 PASS; aprovações 6 PASS; estados remotos
   22 PASS/1 FAIL (golden loading dark 375). Não regravar referências sem revisão.
4. R12-38 e 46: migrar mídia de cardápio e foto para contrato R2 com reuso do
   gateway. SupabaseMealPlanImageRepository ainda usa Storage; UI desabilitada
   é consequência conhecida, não solução. Preservar ownership/auditoria.
5. Executar o restante do catálogo 01–45 por dependência, distinguindo pedidos
   implementáveis e decisões de domínio: 23 (Principal profissional) e 33
   (eventos/destinatários de medicação) têm contratos em aberto documentados.
6. R12-51 libera aplicação SQL somente sob requisito vigente; 48–50 retomam os
   mesmos recursos sintéticos após aplicação, sem duplicar dados. 47 precisa
   prova por e-mail real/redirect permitido. 53 só abre após seus pré-requisitos.
7. Atualizar catálogo/JSONs/inventário/três matrizes/skills, memória e Git;
   executar gate após commit/push. Sem declaração de conclusão enquanto houver
   item implementável ou prova obrigatória pendente. Estimar delta após inspeção.
