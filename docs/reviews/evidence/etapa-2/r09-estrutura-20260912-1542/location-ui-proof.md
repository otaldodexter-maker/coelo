---
source: C0 r102; build integrado G1; CUA; API normal G1
status: location-ui-persistence-reload-pass-negative-pending; members-active-fixture-pending
generated_at: 2026-09-12
---

# Turmas ? prova real R09

Round E2-R09-20260912-1542. G1 coordenado exclusivamente pelo C0
01a096ed-314b-7c13-a9e0-3e64649e66fc, host local.

apps/superadmin -> Estrutura -> Turmas -> Criar -> Vinculos e aparencia -> groups.location.
Build release74.2s exit0, qa_main com TEXT_ENTRY_EMULATION=false e
SYNTHETIC_CIRCULAR_FILE=false. runtime-proof.json prova hashes local/servido
iguais. Chrome22592 existente, aba829822468 criada apos C0 fechar sua aba;
servidor15452/3014, fonte exclusivamente worktree G1. Sessao normal herdada
OC (login anterior G0/C0), sem injecao. API diagnostica usa login normal
qa-r06-estrutura, sempre logout scope=local204.

UI: Home -> Estrutura -> Turmas -> Criar. Hierarquia Escola R04 Estrutura /
Unidade Centro R04. Nome Turma R09 Estrutura 1634 digitado por teclado real.
Selecionado Sala R04 Estrutura no catalogo da unidade, sem reserva.
Busca Nome QA R04 Pessoa retornou candidato ec2a15a2-76bc-4e71-8419-94413d0c5c98
(edit_global), selecionado Responsavel; member-resolved.png.
Primeiro salvar recusado; save-rejected.png. Diagnostico sem escrita mostrou
pessoa draft (ineligivel para group_save), turma draft v1 criada pela etapa
atomica de Local e zero membros; draft-detail-proof.json. Nenhum retry cego.

Removida somente inclusao nao persistida da pessoa draft. Segundo salvar,
com payload corrigido e mesmo recibo Local, retornou a lista. Leitura normal
apos esta mutacao confirma MESMO grupo ativo v2 e MESMO Local:
location-after-save-proof.json (2 checks PASS; Auth200/logout204).
Lista apos reload mostrou o card R09 abaixo dos primeiros cards (location-list.png);
clique Abrir turma abriu a edicao normal do MESMO ID. Nenhuma falha de lista sem busca.
Detalhe produtivo /groups/1043c165-7f24-44fe-a868-5bfc6fb0b50f e reload
mostram nome, hierarquia, Ativo e Sala R04 Estrutura, Local interno Ativo.
location-reload.png e location-selection-reload.png. Nao e mock/golden.

IDs retidos:
- grupo1043c165-7f24-44fe-a868-5bfc6fb0b50f;
- instituicao190dd028-3125-452d-8502-612bfa1029de;
- unidadef5284f2f-b487-4100-bc0b-ffbcbb7d3db3;
- Locald5461295-9273-4caa-9197-8f9d8c05c4f8.

Gate restante: G5/C0 negativa real de tenant/hierarquia da familia Local e
fixture global ATIVA para groups.members. Nao alterar status da pessoa G2
sem atribuicao. Lookup edit_global permite editar um draft; nao significa
que group_save possa vincula-lo. Servidor preservado, sem flexibilizacao.
Membros continua sem prova positiva persistida. Cadastro manual UUID nao certificado.

Diagnostico adicional: directory com busca textual retornou400/22025,
invalid escape string; segunda leitura falha foi somente para capturar causa.
Sem busca, leitor retornou200 e localizou o draft; nao contados como testes
verdes da acao. C0 dono da correcao SQL; save-diagnostic-errors.json.
A leitura inicial de membro vazio nao exercitou contrato plano; preservada.
Nenhuma nota/Avaliacao alterada; cadeia R08 preservada. Sem SQL remoto,
segredos, convites enviados ou novos recursos fora da turma autorizada.
Sem E2E novo enquanto negativa real nao for anexada; deltas factuais propostos.

## Segundo gate de Membros ? 16:47 BRT

Leitor normal superadmin_people_list encontrou quatro fixtures QA ativas;
active-fixture-read.json. G1 selecionou somente QA R04 Responsavel,
9f040000-0000-4000-8000-000000000062, pela busca Nome da UI normal.
Tentativa unica de Salvar no edit do grupo1043c165 tambem foi recusada
(active-member-rejected.png). API apos tentativa: mesmo grupo ativo v2,
zero effective_access (member-after-save-proof.json). Logo nao houve inclusao
persistida; o problema nao se limita a primeira fixture draft.

Causa exata ainda depende do diagnostico do erro de group_save por C0/G5;
papel enviado pelo consumidor e guardian, fixture ativa confirmada.
Nao trocar papel/RPC nem alargar hierarquia por tentativa. Rascunho preservado
na aba829822468, /groups/1043c165-7f24-44fe-a868-5bfc6fb0b50f/edit.
C0/G5: diagnosticar role_code/constraint/grant e negativa de contexto. Local
positivo continua valido. Nenhum novo teste/golden/build necessario ate causa.
