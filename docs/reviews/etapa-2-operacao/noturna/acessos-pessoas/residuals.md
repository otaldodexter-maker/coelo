---
source: "TRABALHO-ATUAL; coordenacao.json r9; R02 D04-delta-matrix at375e0a62a; base d784462c1; night artifacts in this directory"
status: "checkpoint; executor proposal for central writer; no-new-certification"
generated_at: "2026-09-09"
---

# Residuais de Acessos e Pessoas

Recorte único `apps/superadmin`,38 IDs:31 ativos,6 adiados,1 gate MFA.
Revisita focal dos residuais R02, reaproveitando implementação e evidência;
não é nova auditoria integral. Base de código materializada `d784462c1`.
Duplicação `82f08af50` e confinamento de Convites `444e03ccb` já estavam
integrados em `d019c109a`: o antigo gate de integração desses sucessores está
superado. Permanecem suas provas normais de runtime.

Menu Acessos, exceto Convites em Comunicação. Nenhuma linha abaixo promove
certificado FE/BE/E2E. O histórico FE2/38 (import/export indisponíveis) permanece
separado; ativos FE0/31, BE0/31, E2E0/31. Geral conhecido R02:FE7/230,
BE0/223,E2E0/198, histórico e não recontado nesta rodada.

| action_id | Estado/subtela e delta local | Primeiro gate restante |
| --- | --- | --- |
| people.list | Diretório; lifecycle R02 preservado; golden8renders/1P reconciliado; alvo48 corrigido99a66fd2e com4P+200%1P | Contrato interno de listagem/filtros server-side; legado não atende spec046 |
| people.create | Formulário; recibo R02 preservado; visual e alcancefooter2P c76a0eb23 | Write interno aprovado e identity repository |
| people.edit | Formulário; receipt/retry R02 preservados; visual2P compartilhados c76a0eb23 | Write interno, persistência e recarga autorizadas |
| people.links | Vínculos minimizados; detalhe2P sintetico c0e4fc47d | Contrato interno e negativas de escopo; consulta v2 não libera edição |
| people.reload | Consulta por pessoa e diretório são contratos distintos; detalhe2P c0e4fc47d | Runtime interno com reautorização; não certificar diretório pela spec046 |
| access-profiles.list | Catálogo; lifecycle R02 preservado; hover1P e diretorio1P/16renders reconciliados | Decisão de visibilidade institucional global e ACL/helpers |
| access-profiles.create | Formulário compartilhado; recibo confirmado preservado,18P e goldenF1 reconciliado | Write interno e personas; callback não deve repetir comando confirmado |
| access-profiles.detail | Detalhe com rota, sem chamador UI identificado na base6aa | Reader autorizado do perfil real e ponto de entrada deliberado |
| access-profiles.edit | Formulário compartilhado; recibo confirmado preservado,18P e goldenF1 reconciliado | Persistência/recarga autorizada por ator |
| access-profiles.assign | Atribuição | Contrato interno, hierarquia e negativas de escopo |
| access-profiles.delete | Exclusão/reassign | Dependências, negativas e comando interno autorizado |
| access-models.list | Pacote nominal95P local | Revisão e autorização nominal remota; HTTP/UI normal |
| access-models.filter | CSV union preservado; pacote95P inclui filtro15 | Aplicação nominal antes de qualificar cliente CSV |
| access-models.create | Recibo coerente HTTP; rollback tardio6P; formulário17P, sem reenvio após navegação falha | Concorrência local, produção nominal e persistência real |
| access-models.detail | Sem contagem fictícia de vínculos; read local no pacote95; detalhe sem chamador UI identificado | Runtime autorizado, visual e ponto de entrada deliberado |
| access-models.edit | Recibo confere alvo/domínio/versão | Reautorização de replay após lock e recarga real |
| access-models.duplicate | R02 integrado; recibo confere nova identidade; conclusão preservada e24P, incluindo9 rotas | Reautorização de replay e persistência/negações reais |
| invites.list | R02 confinement/lifecycle integrado; visual5P/9renders compartilhados | Diretório normal com persona qualificada |
| invites.create | Wizard e contexto R02 preservados | Persona/SMTP e envio nominal autorizado |
| invites.detail | Link restrito/contexto R02 integrado | Runtime normal autorizado |
| invites.resend | Receipt tardio/revisão descartados no R02 | Envio real nominal e composição normal |
| invites.revoke | Overlay/revisão R02 preservados | Revogação e recarga reais com autorização nominal |
| child-safety.list | Golden reconciliado; composição89P; reflow4P integrado; diretrizes2P4F emshared | SQL interno43, legado63, guard2; perfil53 reservado e publicado; sequência SQL pendente; depois runtime normal |
| child-safety.child | Reader interno41P; resposta sem autorizacoes recusada; comandos explicitamente bloqueados | SQL nominal e HTTP/UI autorizado, sem ativar escrita |
| child-safety.create | Wizard indisponível em adapters reais, confirmado localmente | Lookup adulto minimizado e contrato de ator/receipt interno |
| child-safety.edit | Somente pending; transporte não qualificado bloqueia ação | Contrato interno e persistência/recarga; UUID People não representa ator interno |
| child-safety.suspend | Composição bloqueia despacho em transporte não qualificado | Contrato de realm/receipt e prova real de suspensão |
| internal-users.list | Navegação normal R02 integrada, parser preservado; visual4P/23renders, hover acionável não provado | Runtime read-only com persona qualificada |
| internal-users.create | Receipt/escopo R02 preservados, sem catálogo fictício | Contrato nominal de criação/convite |
| internal-users.edit | Negativa limpa editor; escopo R02 preservado | Rota normal de escrita segue bloqueada |
| internal-users.suspend | Confirmação/releitura/negativas R02 preservadas | Contrato e prova real; não liberar por repository existente |
| internal-users.mfa | Gate adiado; AAL1 vigente preservado | Decisão formal de MFA; nenhuma implementação AAL2 nova |
| profile-files.import | Adiado, indisponibilidade FE histórica preservada | Decisão pós-MVP |
| profile-files.preview | Adiado, sem operação real | Decisão pós-MVP |
| profile-files.confirm | Adiado, sem operação real | Decisão pós-MVP |
| profile-files.status | Adiado, sem operação real | Decisão pós-MVP |
| profile-files.export | Adiado, indisponibilidade FE histórica preservada | Decisão pós-MVP |
| profile-files.download | Adiado, sem operação real | Decisão pós-MVP |

Provas e hashes por lote: `models/README.md`, `models/frontend-receipts.md`,
`models-concurrency/README.md`, `safety-visual/handoff.md`,
`safety-composition/handoff.md`, `safety-sql/handoff.md` e
`safety-sql/profile-proposal/README.md`. Contagens SQL, Flutter e preparação
são separadas; reruns não aumentam cobertura. Rollback tardio6P em
`models/rollback-01.txt`; formulário18P/0F em models-form-receipt/golden-reconciliation.md e duplicação24P em models/duplicate-receipts.md. Total atual430P/4F/120U: Safety108U e concorrênciaModels12U.

Produção: catálogo Supabase lido sem dados pessoais, zero mutação remota.
Ausência do Owner não autoriza pacote novo. Modelos precisa da fundação nominal
com grants import/export revogados; Safety precisa de envelope compatível e
contrato de cursor/lookup. A preparação local não elimina esses bloqueios.

Conhecimento: validator PASS com Root explícito. Nenhuma regra nova aprovada.
As projeções históricas de Perfis/Safety ainda mencionam MFA/AAL2; o escritor
central deve reconciliar suas fontes/aditivos sem alterar a política ADR0019.

Checkpoint 19:25 BRT: Claude r9 registra integração até b285a6804 por69ce62c43. Os commits9d5ce7317/cb76f5968 posteriores estão publicados para integração. A retomada do ensaio concorrente de Modelos foi rejeitada pela revisão automática por possível risco de cibersegurança;12 critérios permanecem não executados, sem contorno. Docker recuperou e o projeto anterior foi verificado sem containers/volumes/networks. Slot Models liberado; Safety108 aguarda ordem nominal após prioridade Forms I008.

Reconciliacao Formgolden: F1 substituido porP1, tres imagens com causa integrada e inspecao anterior conforme coordenacao r10. Evidencia models-form-receipt/golden-reconciliation.md; nenhum certificado completo novo.

Checkpoint visual: f60b2c2fe hoverPerfis1P, c76a0eb23 formularioPessoas2P, 5ffce5441 diretorioPessoas1P e7956dda48 diretorioPerfis1P. Inspecao por render, causas integradas e manifests nos quatro handoffs. Nenhuma certificacao nova. O censo historico tinha14 testes golden falhos nestas familias; cinco foram reconciliados em lotes focais (inclui formularioPerfis c8c8b0fba). Os nove seguintes foram resolvidos depois por5a1ed044f(Convites5P) e0dae87652(Usuarios4P); evidencia nominal em seus handoffs. Medicao ampla190F da base ecc8eae2b permanece historica separada.

Checkpoint22:03BRT: base conjunta6aa352c6a materializada por fast-forward; todos27 commits proprios anteriores integrados e publicados em origin/dev. Novos2816fbff1 (rotas2P) e c0e4fc47d (detalhe2P) publicados na branch propria. people_routes3P de153b2dbfa reutilizado sem rerun ou soma. Os tres F adicionais ainda presentes no catalogo foram reconciliados; total419P/0F/120U. Provas de diferentes bases sao explicitadas em current-results.json, sem alegar reexecucao ampla. Nenhuma promocao.

Alcance r16: ver alcance-produtivo.md. Detalhe de Pessoas usa reader mas o diretorio normal nao fornece callback para abri-lo; people.links/reload do detalhe requerem tambem ponto de entrada deliberado. Perfis/Modelos abrem EDIT pelos cards, nao DETAIL. Nao se confunde rota existente com percurso completo.

Checkpoint22:23BRT: r18Safety investigado. 8f3905819 reflow4P;571ac3cf0 transporte5P semativar mutacoes;f4dd600ffdiretrizes2P4F atuais. Menuusuario44px econtraste compartilhadostem proposta paraClaude;rotulos/carga/overflow nao reproduziramtriagem d784. Total430P4F120U comF4explicitos, sem skipoucertificacao.
