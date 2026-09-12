---
source: C0 R09 fechamento; inventario-etapa-2.json; bloqueios observados; Owner
status: pendencias-preservadas-sem-nova-rodada
generated_at: 2026-09-12
---

# R09 — primeiros gates pendentes

Round1542 encerrado, T015:42:18 preservado. Esta fila nao libera nova fatia
nem inicia R10/Etapa3. Base entregue tem175FE/161BE/148E2E;51E2E ativos
abertos. Inventario e tres rastreadores sao o universo completo vigente;
R09-backlog e historico da abertura, nao deve reabrir aceites atuais.

| Responsavel | Caminho / action_ids | Primeiro gate executavel ou dependencia concreta |
| --- | --- | --- |
| C0/G7 | Superadmin -> cabecalho -> shell.load | Avatar OC e nome Owner Coelo estaticos: consumir identidade autenticada/foto autorizada, iniciais quando sem foto, invalidar na troca/logout e provar com duas identidades/reload. Owner pediu posteriormente. Nao certificado dinamico. |
| G1/G5 | Estrutura -> Turmas -> Pessoas / groups.members | Consumidor nao pode enviar guardian/student/professional/admin como institution_roles inexistentes. Profissionais exigem perfil institucional real; alunos/responsaveis exigem cadeia propria. Resolver contrato/repository e provar vinculo normal/reload/negativa, sem mapear responsavel para professor. |
| G1/G3/G5 | Estrutura -> Avaliacoes / assessments.detail, assessments.entry, assessments.gradebook | Diario d2c945d8-3809-4d84-b836-2bc6da7c381d tem zero alunos elegiveis. Encadear activity_group_participants, child_group_links, child_unit_links, child_contexts e people ativos pela rota autorizada; /students atual so leitura, formulario gerencial sem entrada normal. Nao recriar diario/configuracao para mascarar bloqueio. |
| G2/G5 | Acessos -> Perfis e permissoes / access-profiles.edit, access-profiles.assign, access-profiles.delete | Fechar primeiro gate aberto no inventario com catalogo/escopo real; UI de edicao de usuario preserva perfil existente, nao prova atribuicao arbitraria. Modelos editar/duplicar ja aceitos. |
| G3/G0 | Formularios -> midia / forms.upload, forms.resolve-file | BE aceito; falta upload/consumo pela UI normal. Seletor de arquivo suportado precisa funcionar; extensao recusou setFiles com Allow file URLs desativado. Nao injetar arquivo/sessao ou mudar configuracao global para certificar. Camera fisica separada e nao provada. |
| G3 | Formularios -> questao/resposta / forms.location-answer | Reaproveitar form_save_draft e Local aplicados; demonstrar resposta real e reload na hierarquia autorizada. H19/H20 e residual de acessibilidade permanecem no inventario; nao somar como concluidos. |
| G4 | Coelo -> Chat / chat.create-group, chat.attach | Correcao de erro/troca de contexto3PASS integrada; falta criar grupo/anexar pela UI, persistencia/reload e autorizacao. Nao repetir apenas testes de erro verdes. |
| G4 | Coelo -> Perfil -> Editar / principal.profile-edit | Provar Sobre nao vazio/save/reload no sujeito autorizado usando parser R08 integrado. H02 dado oficial segue decisao nominal; leitura vazia aceita nao certifica edicao. |
| G6/G0 | Coelo -> Circulares -> anexo / circulars.attach | Mesmo bloqueio concreto do picker. Fixture nova nominal proposta nao foi criada. Preservar recurso do incidente; usar novo sintetico somente no proximo recorte autorizado com canal suportado. |
| G4/G6 | Coelo -> Agora / agora.expire | Aguardar expiracao natural13/09/2026 12:24:39BRT do recurso retido e verificar cron/consumidor; nao alterar expires_at nem confundir TTL da URL com expiracao da publicacao. R2 master permanece. |
| G6 | Coelo -> Momentos/Agora e Agenda | Reaproveitar provas API/recursos R08; arquivo UI bloqueado nao concede FE/E2E. Seis decisoes visuais sem recorte nominal continuam abertas e nao impedem outros gates. |
| G7 | Operacao -> Planos / plans.assign | spec051 atual e de leitura; falta contrato aprovado de mutacao/destino. Nao inventar escrita. account.sessions ja aceito anteriormente, nao recertificar sem regressao. |
| G8/C0 | Base integrada -> suites | Censo completo nao executado; testes focais atuais e logs por pacote no fechamento. Na proxima alteracao, executar somente testes materialmente afetados e reservar unico slot; memoria tem1SKIP por symlink do host. |
| C0 | Publicacao frontend | Codigo em dev e build QA3014 comprovado contra Supabase; nao houve novo deploy publico nesta R09. Proximo deploy requer reconciliar autorizacao vigente, artefato e prova funcional no destino; nao tratar push como deploy. |
| C0 | SQL -> fila | Ultimo lote60 aplicado uma vez e corpo confirmado; proximo61 sem candidato. Espelho, pgTAP, backup/preflight, ordem real e consumidor permanecem obrigatorios. Nao ordenar somente pelos nomes de migration. |

Todas as nove branches entregues foram integradas por merge. Worktrees,
ignorados e sinteticos preservados; antigo checkpoint1534d2ed31572 fora de
dev mantido como historico. Nenhuma senha, credencial antiga, endurecimento
amplo, importacao/exportacao geral ou outro app foi incluido. Ferramenta de
mensagem entre conversas indisponivel: fila Git nao equivale a instrucao
recebida, nem autoriza reativacao automatica.
