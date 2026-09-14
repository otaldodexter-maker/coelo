---
source: R12-prompt-unico.md; R12-pendencias.md; R12-checkpoint.md
status: preparado; não iniciado; requer abertura explícita do Owner
generated_at: 2026-09-13
---

# Continuidade dos aceites abertos da R12

Executor solicitado: Claude Opus, esforço médio. Conferir disponibilidade real
e uso na abertura; 12% era estimativa do Owner, não orçamento medido. Este
arquivo não dispara agente, supervisor ou outra rodada.

Trabalhar no checkout consolidado C:/Users/adrie/Documents/Coelo, branch dev.
Fazer fetch e conferir HEAD/origin/dev, stash/worktrees e slots. Código da
última fatia está em 63f6694e; commits documentais posteriores não alteram esse
código. Não voltar a bases antigas. Preservar R01–R13, QA e ignorados privados.

Ler AGENTS.md, RTK.md, as cinco skills pedidas pelo Owner (rtk, coelo-backend,
coelo-frontend, coelo-frontend-backend, ponytail), coelo-ui e coelo-knowledge.
Fontes: R12-pendencias.md, R12-owner-items.json, R12-checkpoint.md,
entrega-atual.json, inventário e matrizes afetadas; usar R14-plano-de-rodada.md
e R14-catalogo.md. A R12 permanece incompleta; catálogo visitado não é execução.

Primeiro gate: R12-52/chat.attach pela rota normal em build atual. O servidor
retido em 127.0.0.1:3000 ainda aponta ao build r12-focal de ba5cfd2d; não
certificar mudanças de 63f6694e contra esse runtime. Não tocar Chrome do Owner.
Não repetir testes verdes de cardápio e agenda sem mudança ou motivo material.
Se QA real estiver inacessível, registrar causa e implementar a próxima fatia
independente: R12-38, adapter de imagem ainda em Supabase Storage, precisa
reusar Media Gateway/R2 e contrato de vínculo autorizado antes de ligar a UI.

Resolver aceites e atualizar fontes no mesmo ciclo; não encerrar só com triagem.
R12-34–36/42 têm novas correções locais, sem prova integrada: seletor no modelo,
nome dinâmico, publicação com instante UTC e tabela/histórico da Agenda. Provar
salvar/reload/escopo no repositório produtivo e o instante de publicação.

Preflight remoto de 13/09 21:27 -03 confirmou PITR=false, backup_count=0,
SMTP próprio ausente e redirect local3000 fora da allowlist. Gates SQL do
prompt e conflito documentado em open-questions continuam sem exceção nova.
Não cobrar PITR, enviar mensagens a terceiros ou alterar credenciais sem a
autoridade específica. R12-53 continua condicional aos gates 46–50; não
iniciar Etapa 3 nem ampliar escopo para encerrar um número.

Aplicar deltas com apply-tracker-delta.cjs. Sincronizar ownerItems e manifesto
com sync-r12-owner-records.cjs após corrigir o catálogo; partial vira open no
manifesto de entrega, preservando o detalhamento FE/BE/E2E. Commit/push de cada
fatia e delivery_gate.py após publicação; resolver FAIL, relatar parcial com
implementação faltante e prova faltante separadas. Nenhum outro executor está
trabalhando automaticamente nesta continuidade.
