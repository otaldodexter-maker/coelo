---
source: "Owner: manter R01; divisão por aplicativos foi ideia para análise, não decisão; protocolo R01; AGENTS.md"
status: "R01-timing-confirmed;R02-allocation-under-analysis;completion-first"
generated_at: "2026-09-08T16:43:19-03:00"
timezone: "America/Sao_Paulo"
---

# R02 — distribuição e fechamento recuperável

Retificação C00 2026-09-08T16:44:55-03:00: o Owner confirmou manter a R01 até o fechamento, mas esclareceu que usar mais Claude/separar Front-end e Back-end por aplicativo foi uma **ideia para aconselhamento**, não preferência ou distribuição aprovada. A finalidade é concluir o Superadmin e os critérios da Etapa2 nos três rastreadores. Consumo de tokens é restrição operacional secundária; não mede avanço nem define ownership.

R02 será organizada a partir dos bloqueios e trabalho residual comprovados. A hipótese Claude/Front-end e Codex/Back-end é candidata, não regra rígida. Antes de definir sessões, avaliar: contratos Auth/permissões que bloqueiam rotas normais; catálogo/gateway/writer/decoder de mídia e Forms; fila de código já produzido sem integração; consumidores normais; provas FE/BE/E2E faltantes. Preservar conhecimento dos executores e transferir somente lotes claros quando houver ganho real, sem separar uma cadeia de responsabilidades a ponto de aumentar espera.

Recomendação atual C00: manter R01; priorizar desbloqueio e integração do que já foi produzido; R02 atribuir lotes pequenos com critério de saída verificável, dono/arquivos/contratos explícitos e prioridade aos fluxos que faltam funcionar. Distribuição final entre aplicativos/modelos depende desses lotes e das capacidades efetivamente disponíveis. Não existe aprovação para mover todo Front-end para Claude nem para criar novas sessões automaticamente. C00 continua único integrador/escritor dos três rastreadores.

## Horários confirmados

08/09: executores17:30, relatório Owner17:40, continuidade dos lotes.09/09: fechamento seguro05:30, handoffs finais/nenhuma nova atribuição R01 a partir06:00; consolidação e prompts R02 até07:40, mesmo com bloqueios. Meta global16/09 12:20 permanece.07:40 não autoriza certificar funcionalidade faltante.

## Verificações do fechamento

1. Ler entregas finais pelos cinco caminhos absolutos registrados, incluindo C04/C05 Claude. Fixar revisão, última instrução recebida, timestamp, SHA do handoff, código e evidências; registrar ausência como última evidência conhecida. Não confundir cron configurado, sessão ativa e handoff efetivamente recebido.
2. Conferir commits e push na branch de cada executor; separar lotes aptos de WIP preservado. Comparar patch-id/diff ao recuperar trabalho, sem importar rastreadores dos executores ou duplicar patches.
3. Revisar/integrar lotes aptos incrementalmente e executar checks proporcionais. SQL, Auth, RLS, mídia e contratos públicos mantêm revisão nominal; remoto só pacote autorizado pelo Owner. Resultados RED/GREEN/abort de ferramenta separados.
4. Reconciliar linhas/IDs dos três rastreadores e inventário com evidências até a revisão declarada. Implementação, verificação, integração, push e produção são estados distintos. Medidas com IDs, denominador/classificação e critérios; auditoria parcial não é percentual de produto pronto.
5. Verificar cada worktree por status Git, branch/SHAs, commits únicos e sessão/ferramenta ativa. Fazer commits apenas dos arquivos próprios/revisados; preservar WIP alheio. Remover somente worktrees R01 limpas, sem sessão ativa e com preservação/integracao/arquivamento comprovados; sem force, reset--hard, clean, stash global ou branch única apagada. Se faltar um critério, preservar a worktree e explicar o motivo: limpeza aparente não vale perda de trabalho.
6. Registrar recursos locais de teste e leases. Encerrar somente recursos nominais próprios depois de preservar evidência/dados necessários. Sem parar container AutoRemove com trabalho ainda não preservado para aparentar limpeza.
7. Publicar integração/documentação no destino dev autorizado, conferir remoto e registrar recibo; sem presumir deploy. Manter checkout original dirty preservado.
8. Gerar prompts completos R02 com nome, modelo/nível verificado, cwd/worktree/branch, baseline real, ações residuais, arquivos reservados, dependências entre FE/BE, critérios e comandos exatos de retomada. Cada ação terá responsável nominal; contribuições de outra camada serão reservas explícitas para evitar dois escritores no mesmo arquivo. Não abrir sessões automaticamente.
9. Prompts frontend usam coelo-frontend + coelo-ui; backend usa coelo-backend + skills oficiais pertinentes; integração usa coelo-frontend-backend e cruza os três rastreadores. Manter coelo-knowledge e demais regras aplicáveis sem carregar todas as referências a cada checkpoint. Forms inclui mídia; Principal é menu do Superadmin.
10. Renovar coordenador somente com transferência explícita do papel de único escritor, confirmação do sucessor e desativação das automações antigas que poderiam continuar escrevendo. Até essa confirmação, autoridade permanece C00 atual.

## Critério para entrega ao Owner

Apresentar o estado comprovado e o que ficou aberto, sem promessa de perfeição não verificada. Prompts finais dependem dos SHAs e evidências do fechamento; este documento registra o objetivo e os critérios de decisão, sem simular baseline futuro ou alocação já aprovada.
