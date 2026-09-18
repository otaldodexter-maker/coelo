---
source: R10-fechamento.md; inventario-etapa-2.json; apontamentos Owner
status: aberto para proxima autorizacao; R10 encerrada
generated_at: 2026-09-13
---

# Pendencias apos R10

R09 preservada encerrada. R11/Etapa3 nao iniciadas. Usar origin/dev e worktree C0 daR10; nao pull/editar checkoutprincipal. Nao repetir criacao de diario/configuracao nem reaplicar61/62/63.

| Superadmin / caminho / action_ids | Primeiro gate executavel | Responsavel |
|---|---|---|
|Estrutura > Atividades > Lancar avaliacoes; assessments.entry/detail/gradebook/close/reopen|Aluno ja possui contexto/unidade/turma ativos. Conferir participante da atividade e snapshot do diario retido d2c945d8; APIinitial_students consulta activity_group_participants. Corrigir/reconciliar via fluxo canonico e provar nota/reload/negativa, fechar/reabrir sem recriar.|C0 + tecnico focal na proxima autorizacao|
|Estrutura > Atividade > Configuracao avaliativa; activities.assessment/publish|UPDATE do draftb04c879e segueSAI_INTERNAL_ERROR. Payload Dart6PASS/replay local passaram; gatewaycontexto platform valido, nao supor falta de membershipinstitucional. Capturar SQLSTATE/statement interno sanitizado por observabilidade autorizada, corrigir e salvar pelaUI no mesmoID.|C0/backend|
|Estrutura > Turmas > lista; groups.list|CardTurmaR05 mostra0alunos/0atividades; banco e secaoPessoas confirmam1. Comparar projecao/repositorycontadores; corrigir e repetir UI/reload sem duplicar vinculos.|C0/FE+BE|
|Chat > anexar; chat.attach|Habilitar pelo canal suportado acesso fileURLs da extensao (Owner indisponivel duranteprova). Depois upload fixtureMP4 real e play/pause/reload/RLS. Nao injetararquivo/sessao nem alterar seguranca global. Fotos inline eR2privado ja provados.|Owner para permissao da extensao; C0 para prova|
|Circular/Forms/Acontece/Agora/Momentos > midia|Mesmo gate picker; reutilizar recursosR08 e contratos implantados, uma fatia por vez; API isolada nao certificaUI.|C0|
|Agora > expirar; agora.expire|RecursoR08 expira13/09/2026 12:24:39BRT; conferir hora real aposisso. Nao alterar expires_at nem confundir TTLdownload.|C0 quando elegivel|
|Perfis > excluir com atribuicoes; access-profiles.delete/assign|R10 certificou exclusao sem atribuicoes, nao realocacao real de membros. Exercicio futuro com sintetico contextual e substituto permitido; sem tocar perfis de sistema.|C0/acessos|
|Padroes visuais restantes|16ocorrenciaslegadas validatorvisual; avaliar outros seletores pelo contrato (nao converter campos indiscriminadamente). Header duasidentidades, Origem, Periodicidade/gap e Editaratividade ja corrigidos.|C0/FE|
|Seguranca profunda de perfis|Seisfalhaslegadas suite88(24/38/41/42/45/47): catalogoseed/v1receiptvs v2gateway. Baselineexplicita, sem alterar criterios para obterverde.|C0/backend|
|H02/H05/H06/H13/H19/plans.assign|Decisoes de produto ainda pendentes; consultar fontes anteriores; sem escrita especulativa.|Owner|

WIP preservado: C0 e treshelpers, branches/commits/ignorados/backupsschema+data, fixtureH264. Nenhumauxiliar ativo; nenhumslotpesado/SQL em uso. Runtime3000/3016 preservado, sessaoQA R06restaurada na abaC0; outrosdrafts nao salvos continuam referenciados, conteudo persistido nao foi apagado. Cota83% na entrada de fechamento; ultimo valor efetivo fica no checkpoint final.

Historicos15branches nao ancestrais permanecemreferenciados no manifestR10; revisao porconteudo somente no dominio necessario. Nao presumir que tudo foi semanticamente auditado. Prioridades independentes nao executadas(Localinstitucional, forms.location-answer, PerfilSobre) permanecem no inventario sem aceite novo.
