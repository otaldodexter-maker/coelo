---
source: docs/reviews/inventario-etapa-2.json; R10-fechamento.md; R10-pendencias.md
status: revisão documental pós-R10; sem nova certificação funcional
generated_at: 2026-09-13
---

# Estado por tela e subtela após R10

Recorte: Etapa 2, apps/superadmin, incluindo Coelo (Principal) hospedado. Admin, Principal independente e Site não foram auditados. Base de produto c8c38e28b; esta projeção cobre todos os 231 action_ids conhecidos, sem inventar telas fora do inventário.

Verified/done são aceites já registrados, não testes repetidos hoje. Pending-verification não significa código inexistente. Local-green significa implementação/prova local sem aceite final. As pendências de FE, BE e E2E são separadas; não somar camadas.

Avanço R10: 177/231 FE, 162/224 BE e 150/199 E2E. As ações completas aparecem com “sem pendência funcional registrada”, limitado à régua MVP e evidência histórica. Aprovação visual e revisão profunda de segurança permanecem separadas.

## Correções e ressalvas que não geram novo action_id

- Filtros Origem/Periodicidade, espaçamento, Editar atividade, abertura do detalhe, fotos inline e identidade do cabeçalho foram corrigidos. Cabeçalho provado com duas identidades/reload.
- groups.list: lista/navegação aceitas, mas contadores Alunos/Atividades do card seguem incorretos. FE: corrigir projeção/renderização; BE: conferir origem das contagens e vínculos.
- access-profiles.delete: CRUD sem atribuições aceito. Realocação com atribuições não foi exercitada; seis divergências da suíte histórica de perfis e 16 ocorrências do validador visual continuam registradas.
- Flutter foi servido localmente; push em dev não equivale a deploy público. SQL61–63 e Edge chat-media implantados.

## Resumo por família

| Família | FE aceito/ações | BE aceito/aplicável | E2E aceito/MVP aplicável | Ações com gate aberto |
|---|---:|---:|---:|---:|
| auth | 4/5 | 2/5 | 2/4 | 3 |
| shell | 4/5 | 0/0 | 0/0 | 1 |
| institutions | 6/13 | 6/13 | 6/11 | 7 |
| units | 8/13 | 8/13 | 8/10 | 5 |
| groups | 5/7 | 5/7 | 5/5 | 2 |
| people | 5/5 | 5/5 | 5/5 | 0 |
| access_profiles | 5/6 | 6/6 | 4/6 | 2 |
| access_models | 6/6 | 6/6 | 6/6 | 0 |
| invites | 4/5 | 5/5 | 4/5 | 1 |
| activities | 5/7 | 7/7 | 5/7 | 2 |
| assessments | 0/5 | 0/5 | 0/5 | 5 |
| students | 5/5 | 5/5 | 5/5 | 0 |
| attendance | 6/6 | 5/6 | 5/5 | 1 |
| daily_routine | 5/5 | 5/5 | 5/5 | 0 |
| agenda | 7/7 | 7/7 | 7/7 | 0 |
| chat | 7/8 | 7/8 | 6/8 | 2 |
| notices | 6/6 | 6/6 | 6/6 | 0 |
| forms_authoring | 7/7 | 7/7 | 7/7 | 0 |
| forms_responses | 5/6 | 5/6 | 5/6 | 1 |
| forms_files | 1/5 | 3/5 | 1/5 | 4 |
| acontece | 3/4 | 4/4 | 3/4 | 1 |
| agora | 1/4 | 1/4 | 0/4 | 4 |
| momentos | 1/4 | 1/4 | 0/4 | 4 |
| principal_profile | 2/3 | 1/3 | 1/3 | 2 |
| child_safety | 5/5 | 5/5 | 5/5 | 0 |
| health_care | 4/4 | 4/4 | 4/4 | 0 |
| medication | 5/5 | 5/5 | 5/5 | 0 |
| imports | 2/7 | 0/7 | 0/0 | 7 |
| profile_files | 2/6 | 0/6 | 0/0 | 6 |
| audit | 4/4 | 3/4 | 3/3 | 1 |
| support | 6/6 | 6/6 | 6/6 | 0 |
| account | 5/6 | 3/4 | 3/3 | 1 |
| catalog | 3/4 | 0/4 | 0/4 | 4 |
| plans | 4/5 | 4/5 | 4/5 | 1 |
| meal_plans | 6/6 | 6/6 | 6/6 | 0 |
| internal_users | 4/5 | 4/5 | 4/4 | 1 |
| error_pages | 5/6 | 0/6 | 0/6 | 6 |
| locations | 4/4 | 4/4 | 4/4 | 0 |
| circulars | 10/11 | 11/11 | 10/11 | 1 |

## Todas as telas e subtelas

O action_id preserva o vínculo com as três matrizes e suas evidências. Responsável por implementação/prova: C0 com técnico focal. Gates de decisão: Owner. Permissão da extensão: operador do navegador; C0 executa a prova depois de liberada.

### auth

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Auth / Login — `auth.login` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Auth / Recuperar senha — `auth.recover` | verified / pending-verification / pending-verification | Aceite FE preservado. | Conferir pacote Auth vigente e provar entrega SMTP, expiração/uso único do link e nova sessão. Não reabrir trabalho de senha neste pedido documental. | Recuperar/redefinir pela rota normal com credencial sintética e sem expor tokens. |
| Auth / Redefinir senha — `auth.reset` | verified / pending-verification / pending-verification | Aceite FE preservado. | Conferir pacote Auth vigente e provar entrega SMTP, expiração/uso único do link e nova sessão. Não reabrir trabalho de senha neste pedido documental. | Recuperar/redefinir pela rota normal com credencial sintética e sem expor tokens. |
| Auth / Sair — `auth.logout` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Auth / MFA — `auth.mfa` | pending-verification / gate-formal-mvp / gate-formal-mvp | UX honesta e AAL1 vigente. | MFA adiado conforme decisão formal. | Retomar no gate formal do MVP; não fingir MFA ativo. |

### shell

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Shell / Carregamento — `shell.load` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |
| Shell / Navegação — `shell.navigate` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |
| Shell / Troca de contexto — `shell.switch-context` | pending-verification / not-applicable / flutter-only | Provar troca pela rota normal com contexto autorizado e estado recarregado. | Sem endpoint próprio; depende da sessão e do contexto. | Aceite cliente ainda pendente; não é nova implementação presumida. |
| Shell / Acesso negado — `shell.unauthorized` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |
| Shell / Recarregar — `shell.reload` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |

### institutions

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Instituições / Diretório — `institutions.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Instituições / Filtros — `institutions.filter` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Instituições / Detalhe — `institutions.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Instituição — `institutions.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Instituição — `institutions.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Instituições / Ativar-desativar — `institutions.status` | pending-verification / pending-verification / pending-verification | Ativar/desativar, cancelar e reler estado pela interface. | Validar transição autorizada, conflitos e auditoria no contrato vigente. | Estado persistido, reload e negativa de escopo. |
| Instituições / Arquivos — `institutions.files` | pending-verification / pending-verification / pending-verification | Concluir consumidor de arquivos, estados e fluxo pela interface. | Conferir gateway/R2 privado, MIME/limites, ownership, reautorização e retenção. | Upload/leitura/reload e negação real no domínio Instituições. |
| Instituições / Importar — `institutions.import` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Instituições / Exportar — `institutions.export` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Instituições / Erro e retry — `institutions.error` | pending-verification / local-green / pending-verification | Provocar erro real e provar mensagem segura, retry e ausência de sucesso falso. | Contrato já existe; conferir negativa/envelope e idempotência atuais. | Falha e recuperação pela rota normal. |
| Instituições / Acesso negado — `institutions.access-denied` | pending-verification / local-green / pending-verification | Provar acesso negado sem dados residuais ou ações indevidas. | Reutilizar negativas válidas com paridade atual de sessão/capacidade/escopo. | Rota normal/deep link negado, sem vazamento. |
| Instituições / Recarregar — `institutions.reload` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Instituição / Mapa e locais — `institutions.locations-map` | pending-verification / local-green / pending-verification | Selecionar Local autorizado, abrir mapa/detalhe e recarregar vínculo. | Contrato de Locais existente; provar associação institucional, ownership e escopo. | Não inferir da prova de Local da unidade ou turma. |

### units

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Unidades / Diretório — `units.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Unidades / Filtrar — `units.filter` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Unidade — `units.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Unidade — `units.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Unidades / Status — `units.status` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Unidades / Importar — `units.import` | local-green / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Unidades / Exportar — `units.export` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Unidades / Erro — `units.error` | pending-verification / local-green / pending-verification | Provocar erro real e provar mensagem segura, retry e ausência de sucesso falso. | Contrato já existe; conferir negativa/envelope e idempotência atuais. | Falha e recuperação pela rota normal. |
| Unidades / Acesso negado — `units.access-denied` | pending-verification / local-green / pending-verification | Provar acesso negado sem dados residuais ou ações indevidas. | Reutilizar negativas válidas com paridade atual de sessão/capacidade/escopo. | Rota normal/deep link negado, sem vazamento. |
| Unidades / Recarregar — `units.reload` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Unidade / Pessoas / Exportar — `units.people-export` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Unidade / Mapa e locais — `units.locations-map` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Unidade / Copiar local — `units.copy-institution-location` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### groups

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Turmas / Diretório — `groups.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Turma — `groups.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Turmas / Detalhe-editar — `groups.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Turmas / Membros — `groups.members` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Turmas / Importar — `groups.import` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Turmas / Exportar — `groups.export` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Turma / Local — `groups.location` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### people

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Pessoas / Diretório — `people.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Pessoa — `people.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Pessoa — `people.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Pessoas / Vínculos — `people.links` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Pessoas / Recarregar — `people.reload` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### access_profiles

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Perfis de acesso / Lista — `access-profiles.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar perfil de acesso — `access-profiles.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Perfil de acesso / Detalhe — `access-profiles.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar perfil de acesso — `access-profiles.edit` | verified / done / pending-verification | Aceite FE preservado. | Aceite BE preservado. | Salvar edição pela UI, reler e conferir negativa pertinente. |
| Perfis de acesso / Atribuir — `access-profiles.assign` | pending-verification / done / pending-verification | Atribuir perfil no fluxo de usuário interno e reler o resultado. | Aceite BE existente; atribuição usa profile_id do comando de usuário interno. | Prova própria de atribuição; listagem não basta. |
| Perfis de acesso / Excluir — `access-profiles.delete` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### access_models

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Modelos de acesso / Lista — `access-models.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Modelos de acesso / Filtrar — `access-models.filter` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar modelo de acesso — `access-models.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Modelo de acesso / Detalhe — `access-models.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar modelo de acesso — `access-models.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Duplicar modelo de acesso — `access-models.duplicate` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### invites

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Convites / Lista — `invites.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Convite — `invites.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Convite / Detalhe — `invites.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Convite / Reenviar — `invites.resend` | pending-verification / done / pending-verification | Reenviar convite expirado pela UI e conferir resultado/reload. | Contrato aceita expirado, não convite pending vigente; preparar contexto sintético válido. | Recibo de reenvio sem divulgar link ou token. |
| Convite / Revogar — `invites.revoke` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### activities

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Atividades / Diretório — `activities.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Atividade / Wizard — `activities.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Atividade / Detalhe — `activities.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Atividade — `activities.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Atividade / Publicar — `activities.publish` | local-green / done / pending-verification | Provar salvar/publicar no estado correto, sem travar retry ou rascunho. | Publicação já provada no BE; conferir paridade do contrato existente. | Publicar pela UI normal e reler estado ativo. |
| Atividade / Avaliar — `activities.assessment` | pending-verification / done / pending-verification | Layout/read-by-id corrigidos; salvar UPDATE do mesmo draft ainda falha. | Diagnosticar SAI_INTERNAL_ERROR em produção com dados sanitizados; payload/replay local passaram. Aceite BE histórico não certifica esse UPDATE. | Salvar e recarregar o draft retido; não criar outro para contornar. |
| Atividade / Local — `activities.location` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### assessments

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Avaliações / Lançamento — `assessments.entry` | local-green / local-green / pending-verification | Exibir aluno elegível, lançar resultado e abrir detalhe/diário com reload. | Reconciliar activity_group_participants e snapshot do diário retido. Contexto/unidade/turma já estão ativos. | Nota persistida pelo repository real, escopo negado e reload; sem recriar diário/configuração. |
| Avaliações / Diário — `assessments.gradebook` | pending-verification / local-green / pending-verification | Exibir aluno elegível, lançar resultado e abrir detalhe/diário com reload. | Reconciliar activity_group_participants e snapshot do diário retido. Contexto/unidade/turma já estão ativos. | Nota persistida pelo repository real, escopo negado e reload; sem recriar diário/configuração. |
| Avaliações / Fechar — `assessments.close` | pending-verification / local-green / pending-verification | Executar fechamento e reabertura após diário válido. | Provar transições, versão, autorização e auditoria no diário existente. | Depende de participante e nota persistida; ainda não executado. |
| Avaliações / Reabrir — `assessments.reopen` | pending-verification / local-green / pending-verification | Executar fechamento e reabertura após diário válido. | Provar transições, versão, autorização e auditoria no diário existente. | Depende de participante e nota persistida; ainda não executado. |
| Avaliação / Detalhe — `assessments.detail` | pending-verification / local-green / pending-verification | Exibir aluno elegível, lançar resultado e abrir detalhe/diário com reload. | Reconciliar activity_group_participants e snapshot do diário retido. Contexto/unidade/turma já estão ativos. | Nota persistida pelo repository real, escopo negado e reload; sem recriar diário/configuração. |

### students

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Alunos / Acompanhamento — `students.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Alunos / Vincular — `students.link` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Alunos / Transferir — `students.transfer` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Alunos / Editar — `students.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Alunos / Revogar — `students.revoke` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### attendance

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Assiduidade / Dashboard — `attendance.dashboard` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Assiduidade / Nova chamada — `attendance.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Assiduidade / Marcar — `attendance.mark` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Assiduidade / Corrigir — `attendance.correct` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Assiduidade / Concluir — `attendance.finish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Assiduidade / Exportar — `attendance.export` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |

### daily_routine

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Rotina diária / Diretório — `daily-routine.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Rotina — `daily-routine.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Rotina — `daily-routine.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Rotina / Aplicar — `daily-routine.apply` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Rotina / Publicar — `daily-routine.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### agenda

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Agenda / Calendário — `agenda.view` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Agenda / Criar evento — `agenda.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Agenda / Detalhe — `agenda.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Agenda / Editar — `agenda.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Agenda / Solicitar — `agenda.request` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Agenda / Permissões — `agenda.permissions` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Evento / Local — `agenda.location` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### chat

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Chat / Conversas — `chat.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Chat / Abrir conversa — `chat.open` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Chat / Enviar mensagem — `chat.send` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Chat / Criar grupo — `chat.create-group` | verified / done / pending-verification | Aceite FE preservado. | Aceite BE preservado. | Criar grupo pela UI e confirmar membros, lista/reload e escopo. |
| Chat / Editar mensagem — `chat.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Chat / Anexar arquivo — `chat.attach` | local-green / local-green / pending-verification | Fotos inline provadas; falta upload MP4 real e play/pause/reload pela UI. | SQL61 e Edge implantados, R2 privado confirmado; completar prova MP4 da cadeia de mídia e negativas. | Desbloquear picker pelo canal suportado; não injetar arquivos nem alterar segurança global. |
| Chat / Recibos — `chat.receipts` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Chat / Revogar-remover — `chat.revoke` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### notices

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Avisos / Diretório — `notices.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Aviso — `notices.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Aviso — `notices.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Avisos / Agendar — `notices.schedule` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Avisos / Publicar — `notices.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Avisos / Arquivar — `notices.archive` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### forms_authoring

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Formulários / Diretório — `forms.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Formulário — `forms.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Visão geral — `forms.overview` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Editar — `forms.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Publicar — `forms.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Testar — `forms.test` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Pergunta Local interno — `forms.location-question` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### forms_responses

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Respostas / Monitor — `forms.monitor` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Responder Formulário — `forms.respond` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Respostas / Lista — `forms.responses` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Resposta / Detalhe — `forms.response-detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Exportar respostas — `forms.responses.export` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Formulário / Responder Local interno — `forms.location-answer` | local-green / pending-verification / pending-verification | Responder item Local publicado em ocorrência válida e recarregar. | Provar Local autorizado, participação/ocorrência, persistência e negativa de escopo. | Decisão de Local já resolvida; não aguarda nova decisão do Owner. |

### forms_files

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Arquivos de Formulários / Upload — `forms.upload` | local-green / done / pending-verification | Upload/download/reabertura pela UI; cobrir os modos Foto/câmera e anônimo pertinentes. | BE done com cadeia e lote60; preservar prova de ownership/reautorização/TTL. | Picker e consumidor real ainda pendentes; API isolada não fecha UI. |
| Arquivos de Formulários / Resolver — `forms.resolve-file` | local-green / done / pending-verification | Upload/download/reabertura pela UI; cobrir os modos Foto/câmera e anônimo pertinentes. | BE done com cadeia e lote60; preservar prova de ownership/reautorização/TTL. | Picker e consumidor real ainda pendentes; API isolada não fecha UI. |
| Arquivos de Formulários / Baixar — `forms.download` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Arquivos de Formulários / Expirar — `forms.expire-file` | pending-verification / local-green / pending-verification | Mostrar expiração/remoção e impedir acesso após reload. | Verificar execução vigente de expiração e limpeza física R2, retenção e auditoria; não reaplicar lotes existentes. | Estado terminal e arquivo indisponível pela UI, sem órfão acessível. |
| Arquivos de Formulários / Excluir — `forms.delete-file` | pending-verification / local-green / pending-verification | Mostrar expiração/remoção e impedir acesso após reload. | Verificar execução vigente de expiração e limpeza física R2, retenção e auditoria; não reaplicar lotes existentes. | Estado terminal e arquivo indisponível pela UI, sem órfão acessível. |

### acontece

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Acontece / Feed — `acontece.feed` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Acontece / Criar — `acontece.create` | local-green / done / pending-verification | Criar com mídia na tela reconstruída e recarregar. | BE done; reutilizar cadeia vigente de mídia e escopo. | Prova nova do compositor atual; aprovação do compositor antigo não basta. |
| Acontece / Publicar — `acontece.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Acontece / Remover — `acontece.remove` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### agora

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Agora / Visualizar — `agora.view` | verified / done / pending-verification | Aceite FE preservado. | Aceite BE preservado. | Visualizar publicação real com mídia/contexto no host atual e reload. |
| Agora / Criar — `agora.create` | local-green / local-green / pending-verification | Criar/publicar com mídia privada no compositor atual e recarregar. | Fundação existente; confirmar implantação vigente, ativo real, autorização e consumidor. Não redeployar só por nota histórica. | Picker suportado e cadeia real completa; mocks não certificam publicação. |
| Agora / Publicar — `agora.publish` | pending-verification / local-green / pending-verification | Criar/publicar com mídia privada no compositor atual e recarregar. | Fundação existente; confirmar implantação vigente, ativo real, autorização e consumidor. Não redeployar só por nota histórica. | Picker suportado e cadeia real completa; mocks não certificam publicação. |
| Agora / Expirar — `agora.expire` | pending-verification / local-green / pending-verification | Provar desaparecimento/estado expirado após reload. | Cron já registrado; verificar execução e transição real. Recurso retido vence 13/09/2026 12:24:39 BRT. | Conferir relógio na retomada; nunca antecipar expires_at nem usar TTL da URL como prova. |

### momentos

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Momentos / Visualizar — `momentos.view` | verified / done / pending-verification | Aceite FE preservado. | Aceite BE preservado. | Visualizar publicação real com mídia/contexto no host atual e reload. |
| Momentos / Criar — `momentos.create` | local-green / local-green / blocked-environment | Criar/publicar com mídia privada no compositor atual e recarregar. | Fundação existente; confirmar implantação vigente, ativo real, autorização e consumidor. Não redeployar só por nota histórica. | Picker suportado e cadeia real completa; mocks não certificam publicação. |
| Momentos / Publicar — `momentos.publish` | pending-verification / local-green / pending-verification | Criar/publicar com mídia privada no compositor atual e recarregar. | Fundação existente; confirmar implantação vigente, ativo real, autorização e consumidor. Não redeployar só por nota histórica. | Picker suportado e cadeia real completa; mocks não certificam publicação. |
| Momentos / Remover — `momentos.remove` | pending-verification / local-green / pending-verification | Retirar publicação real e reler feed/estado. | Correção lote58 já aplicada; provar consumidor e negativa pertinente, sem reaplicar. | Autor autorizado, retirada persistida e reload no host atual. |

### principal_profile

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Principal / Para Você — `principal.for-you` | verified / blocked-decision / pending-verification | Aceite FE preservado; CTA depende do contrato. | Conciliar pendência H13 de Comunicação com a ponte de contexto existente. | Provar conteúdo autorizado após decisão, sem refazer P17/P35. |
| Principal / Perfil-circulares — `principal.profile-view` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Principal / Editar perfil — `principal.profile-edit` | local-green / blocked-decision / pending-verification | Salvar Sobre e recarregar no sujeito/contexto autorizado. | Provar escrita de Sobre; H02 de dados oficiais exige decisão nominal. | Sobre é gate independente; não bloquear por toda a decisão H02. |

### child_safety

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Segurança infantil / Lista — `child-safety.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Segurança infantil / Criança — `child-safety.child` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Segurança infantil / Criar autorização — `child-safety.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Segurança infantil / Editar autorização — `child-safety.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Segurança infantil / Suspender — `child-safety.suspend` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### health_care

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Perfis de cuidado / Lista — `health-care.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar perfil de cuidado — `health-care.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Perfil de cuidado / Detalhe — `health-care.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar perfil de cuidado — `health-care.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### medication

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Medicação / Lista — `medication.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Medicação / Criar — `medication.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Medicação / Detalhe — `medication.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Medicação / Editar — `medication.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Medicação / Evidência — `medication.evidence` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### imports

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Importações / Hub — `imports.list` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Nova — `imports.create` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Upload — `imports.upload` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Preview — `imports.preview` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Confirmar — `imports.confirm` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Status — `imports.status` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Importações / Baixar — `imports.download` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |

### profile_files

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Arquivos de perfil / Importar — `profile-files.import` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Arquivos de perfil / Preview — `profile-files.preview` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Arquivos de perfil / Confirmar — `profile-files.confirm` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Arquivos de perfil / Status — `profile-files.status` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Arquivos de perfil / Exportar — `profile-files.export` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |
| Arquivos de perfil / Baixar — `profile-files.download` | pending-verification / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |

### audit

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Auditoria / Lista — `audit.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Auditoria / Filtrar — `audit.filter` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Auditoria / Detalhe — `audit.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Auditoria / Exportar — `audit.export` | verified / deferred-post-mvp / deferred-post-mvp | Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified. | Operação real adiada; não implementar importação/exportação agora. | Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria. |

### support

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Suporte / Criar — `support.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Suporte / Tabela — `support.table` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Suporte / Kanban — `support.kanban` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Suporte / Detalhe — `support.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Suporte / Responder — `support.reply` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Suporte / Encerrar — `support.close` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### account

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Conta / Perfil — `account.profile` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Conta / Configurações — `account.settings` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |
| Conta / Tema — `account.theme` | verified / not-applicable / flutter-only | Sem pendência funcional registrada. | Não aplicável como ação própria. | Aceite registrado; ressalvas transversais acima. |
| Conta / MFA — `account.mfa` | pending-verification / gate-formal-mvp / gate-formal-mvp | UX honesta e AAL1 vigente. | MFA adiado conforme decisão formal. | Retomar no gate formal do MVP; não fingir MFA ativo. |
| Conta / Sessões — `account.sessions` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Conta / Sair — `account.logout` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### catalog

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Catálogo / Lista — `catalog.list` | verified / pending-verification / pending-verification | Conferir exemplos/índice, validação/sincronização e publicação no destino canônico; preservar aceites FE já registrados. | Definir e conferir provedor/destino, acesso e publicação. Supabase N/A não torna todo BE N/A. | Destino e contrato existentes, validação atual e prova da ação publicada; sem inventar infraestrutura. |
| Catálogo / Validar — `catalog.validate` | verified / pending-verification / pending-verification | Conferir exemplos/índice, validação/sincronização e publicação no destino canônico; preservar aceites FE já registrados. | Definir e conferir provedor/destino, acesso e publicação. Supabase N/A não torna todo BE N/A. | Destino e contrato existentes, validação atual e prova da ação publicada; sem inventar infraestrutura. |
| Catálogo / Sincronizar — `catalog.sync` | verified / pending-verification / pending-verification | Conferir exemplos/índice, validação/sincronização e publicação no destino canônico; preservar aceites FE já registrados. | Definir e conferir provedor/destino, acesso e publicação. Supabase N/A não torna todo BE N/A. | Destino e contrato existentes, validação atual e prova da ação publicada; sem inventar infraestrutura. |
| Catálogo / Publicar — `catalog.publish` | pending-verification / pending-verification / pending-verification | Conferir exemplos/índice, validação/sincronização e publicação no destino canônico; preservar aceites FE já registrados. | Definir e conferir provedor/destino, acesso e publicação. Supabase N/A não torna todo BE N/A. | Destino e contrato existentes, validação atual e prova da ação publicada; sem inventar infraestrutura. |

### plans

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Planos / Diretório — `plans.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Plano — `plans.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Plano — `plans.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Planos / Ativar — `plans.activate` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Planos / Atribuir — `plans.assign` | pending-verification / pending-verification / pending-verification | Conciliar ação com contrato aprovado; não criar atribuição por inferência. | Decisão nominal de atribuição; sem cobrança ou escrita fora da spec051. | Owner define contrato antes da implementação. |

### meal_plans

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Cardápios / Diretório — `meal-plans.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Cardápio — `meal-plans.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Cardápio — `meal-plans.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Cardápios / Criar modelo — `meal-plans.model-create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Cardápios / Editar modelo — `meal-plans.model-edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Cardápios / Publicar — `meal-plans.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### internal_users

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Usuários internos / Lista — `internal-users.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar usuário interno — `internal-users.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar usuário interno — `internal-users.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Usuários internos / Suspender — `internal-users.suspend` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Usuários internos / MFA — `internal-users.mfa` | pending-verification / gate-formal-mvp / gate-formal-mvp | UX honesta e AAL1 vigente. | MFA adiado conforme decisão formal. | Retomar no gate formal do MVP; não fingir MFA ativo. |

### error_pages

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Erros / 403 — `errors.403` | verified / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |
| Erros / 404 — `errors.404` | verified / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |
| Erros / 409 — `errors.409` | local-green / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |
| Erros / 500 — `errors.500` | verified / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |
| Erros / 503 — `errors.503` | verified / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |
| Erros / Tentar novamente — `errors.retry` | verified / pending-verification / pending-verification | Aceite FE existente preservado; verificar comportamento no erro real da ação. | Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código. | Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso. |

### locations

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Locais / Diretório — `locations.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Local / Criar e editar — `locations.create-edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Local / Detalhe e vínculos — `locations.detail-links` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Locais / Agendamento — `locations.schedule` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |

### circulars

| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |
|---|---|---|---|---|
| Circulares / Diretório — `circulars.list` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circulares / Tabs, busca e filtro de contexto — `circulars.filter` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Criar Circular — `circulars.create` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Editar Circular — `circulars.edit` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circular / Detalhe — `circulars.detail` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circulares / Agendar — `circulars.schedule` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circulares / Publicar — `circulars.publish` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circulares / Encerrar respostas — `circulars.close` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circulares / Excluir — `circulars.delete` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Responder Circular — `circulars.respond` | verified / done / verified-e2e | Sem pendência funcional registrada. | Sem pendência funcional registrada. | Aceite registrado; ressalvas transversais acima. |
| Circular / Anexos — `circulars.attach` | local-green / done / pending-verification | Executar picker, upload, anexo no compositor e reload. | Cadeia R2 já possui provas; conferir paridade/negativas atuais do consumidor. | Picker bloqueado pela permissão fileURLs da extensão. |

## Fonte e atualização

Inventário e três rastreadores são a fonte de estados/certificações. Esta visão complementa os registros históricos com o primeiro gate conhecido; não apaga evidências antigas nem concede novo aceite. Sem alteração de denominadores.
