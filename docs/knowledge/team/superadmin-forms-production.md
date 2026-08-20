---
title: Formulários produtivos do Superadmin
knowledge_id: superadmin-forms-production
source: docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md
status: validated
generated_at: 2026-08-13
audience: team
surfaces: [superadmin, forms, permissions, storage, exports]
visibility: internal
review_owner: Coelo Product
---

# Formulários produtivos do Superadmin

Formulários e Enquetes rápidas compartilham um domínio relacional e neutro de
frontend. A identidade do formulário é estável; cada publicação congela uma
versão imutável. Editar algo publicado cria uma working version, preserva
ocorrências abertas ou concluídas e atualiza somente ocorrências futuras ainda
não abertas quando a nova versão é publicada. O modo identificado ou anônimo
fica imutável após a primeira publicação.

Uma Enquete rápida usa o mesmo motor, mas a publicação exige uma intenção curta
na descrição (1 a 280 caracteres após trim) e exatamente uma pergunta
respondível. O editor pode manter rascunhos incompletos durante o autosave; o
pré-publish e a RPC de publicação rejeitam a versão inválida.

Audiências, exclusões, aplicações, agendas, lembretes, participações, respostas
e opções são linhas normalizadas. Todas as leituras e mutações passam por RPCs
que validam ator, capability, tenant, hierarquia, payload allowlisted,
`request_id` e versão esperada. Tabelas públicas forçam RLS e não concedem
acesso direto ao cliente. Listagens usam cursor opaco, sem paginação profunda
por `OFFSET`.

Capabilities no Flutter servem somente para apresentar a interface; o backend
reautoriza toda leitura, mutação, mídia e job. `FormMediaResolver` não acessa o
bucket nem conserva URL permanente: ele envia `asset_id` e, quando aplicável,
o segredo opaco anônimo para `form-media`, que revalida o ator e devolve apenas
um ticket assinado de curta duração.

No diretório, situação operacional não substitui o ciclo de vida persistido:
`FormStatus` continua em rascunho/publicado/arquivado. A projeção autorizada
calcula rascunho, programado, ativo, encerrado ou arquivado a partir das janelas
das ocorrências; arquivado e rascunho prevalecem, uma ocorrência aberta torna o
formulário ativo e, na ausência dela, uma ocorrência futura o torna programado.
Ocorrências canceladas não contam e ativo prevalece quando coexistir com
programado.

O monitoramento materializa métricas por ocorrência e avança somente na cadeia
instituição → unidade → turma → atividade → perfil. A RPC de hierarquia exige
`forms.monitor`, cursor opaco e um `scope_id` pertencente ao mesmo formulário e
tenant antes de abrir o nível seguinte.

Uma resposta anônima não persiste `person_id`, `participation_id` nem outra
chave compartilhada com a participação. O dispositivo gera um segredo opaco de
32 bytes; somente o hash bcrypt é persistido no backend e a edição é
irrecuperável se o segredo local for perdido. A consulta nominal excepcional de
participação anônima exige Owner, capability específica, justificativa
auditável e nunca expõe um identificador ou horário que permita correlacionar a
pessoa com uma resposta.

Photo captura pela câmera e Gallery escolhe imagens existentes. JPEG, PNG e
WebP de até 10 MB usam o bucket privado `coelo-forms-private`: o backend cria
path opaco e URL assinada curta, o cliente envia sem credencial privilegiada, e a
finalização verifica tamanho, MIME e checksum. Downloads passam pela rota
protegida de mídia e reautorizam cada acesso. Exportações CSV, XLSX e ZIP são
jobs privados, idempotentes e auditados; perguntas multivaloradas expandem em
grupos independentes, sem produto cartesiano, e valores são neutralizados
contra fórmulas.
