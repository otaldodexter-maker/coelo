---
source: C0 UI normal; internal-user-create v4; productive RPCs; SQL mirror
status: verified-create-and-suspend
generated_at: 2026-09-12
---

# Usuario interno: criar com escopo e suspender

apps/superadmin -> Acessos -> Usuarios internos -> criar/detalhe/acoes ->
internal-users.create/internal-users.suspend. Continuidade da correcao de
rota4deb35a6e, sem nova tarefa ou agente. C0 executou a fatia nominal G2/G5.

Criacao estava bloqueada pelo catalogo de instituicoes nunca composto.
Agora a rota carrega paginas autorizadas do repository de Instituicoes;
nao trunca o catalogo silenciosamente (falha se incompleto, pagina vazia com
hasNext ou limite operacional de100paginas). Formulario carrega perfis reais
e usa UUID do perfil selecionado, em vez do ID demonstrativo operations.
Resposta atrasada e descartada ao trocar/revogar contexto. Falha tem retry;
catalogo vazio continua indisponivel. Edicao preserva o acesso existente
quando seu catalogo nao esta composto; nao certificar access-profiles.assign.
Texto inicial corrigido conforme isolamento interno e ponte service-person
ja aprovados: nao afirma mais que o backend deixa de criar @/Pessoa.

Teste focal inicial1FAIL; primeira execucao conjunta30PASS/1FAIL porque o
oraculo procurava titulo de loading que o componente substitui por skeleton.
Corrigido para exigir ausencia do formulario enquanto carrega. Final19/19
contexto, mais3pages e10rotas PASS na execucao conjunta anterior:32casos
unicos pertinentes, sem somar reruns. Novo teste cobre IDs reais enviados e
outro descarta resposta tardia apos revogacao. Analyze3arquivos0issues.
Build55.6s PASS; QA emulacoes false, hash local/servido igual, mesmo Chrome.

Preflight remoto:zero identidades/CPFs/Auths correspondentes ao novo
sintetico. UI criou QA R09 Interno sintetico1542 (nome com espaco antes
de1542), email qa-r09-interno-1542@coelo.me, CPF sintetico terminado76,
sem nascimento/foto/endereco. Perfil Support,2capacidades, alcance limitado
somente a d0c40000-0000-4000-8000-000000000001 (QA R04 Cuidado).
Revisao previa, criar, recibo Link seguro de definicao de senha, Concluir,
detalhe e reload passaram. Link nao copiado, aberto, registrado ou entregue;
SMTP nao enviado. Criacao bem-sucedida pela Edge v4 existente; nao houve
deploy, senha definida ou nova geracao de link fora dessa unica criacao.

Identidade3429b381-6e3e-414f-ab12-be3326144ac4; Auth
b0179937-0c3b-4222-886f-752fa319b93a. SQL apos criar:version1, support,
membership/auth-link active, scope_kind institution, uma unica instituicao.
Depois Acoes -> Suspender acesso -> Confirmar acao; reload -> Acoes mostrou
Reativar acesso. SQL confirmou membership/auth-link suspended, timestamps
preenchidos, version2 e auditoria superadmin.internal-users.suspend success.
reason_code do audit e null; nao alegar justificativa digitada pelo operador.
Sintetico mantido suspenso; nao revogado, reativado ou removido.

Sonda6checksPASS:anoncreate/detail401, Auth normal do operador200, leitura
persistida suspended/blocked/v2, perfil Support/escopo limitado preservados,
logout local204. RLS/escopo: reutilizados45/45 usuarios internos e9/9criacao
da mesma base, com cross-tenant, escalada negada, auth-link suspenso/revogado
negado e ultimo Owner protegido;17corpos/policies iguais a producao conforme
internal-users-parity-result.json. Nao foi criada senha nem uma sessao do
novo alvo: nao alegar prova de logout concorrente real ou de primeiro login.

FE/BE/E2E de create e suspend aceitos pelo gate MVP de cada acao; nao
certificar entrega SMTP, primeiro login ou definicao de senha. Nenhuma nova
migration, recurso Cloudflare ou chave de API. Fotos/links externos fora da
prova. Memoria: regra existente preservada; gate65artigos PASS. pwsh nao
instalado; gate executado pelo PowerShell da sessao, sem reconfigurar tools.
