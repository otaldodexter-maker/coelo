---
source: C0 normal UI; productive internal-user RPC; coordinated SQL mirror
status: verified-edit
generated_at: 2026-09-12
---

# Usuario interno: edicao normal

apps/superadmin -> Acessos -> Usuarios internos -> detalhe/editar ->
internal-users.edit. A rota normal mostrava Editar desabilitado: faltava
onEdit na composicao. Ao liga-lo, o teste revelou tambem o redirect geral
que negava /internal-users/*/edit e /new mesmo com repository produtivo.
Corrigidas as duas ligacoes, mantendo repository real e as tres capacidades
member.read/update/suspend; o servidor continua reautorizando ator e alvo.

RED focal1FAIL confirmou callback null. Primeira correcao:12PASS/2FAIL no
teste de navegacao (redirect bloqueado). Correcao completa:14/14 testes de
rota PASS em800/1440, incluindo read-only, negativas server-side, retry,
troca de sessao e logout. Analyze dos dois arquivos:0issues. Build56.7s
PASS com flags de emulacao false; hash servido igual ao local.

UI abriu o sintetico R08 0ddeebc0-ee10-4565-96e0-ef11cacfc734. Editor
recebia campos completos pela RPC auditada existente; a hipotese inicial
de campos mascarados foi descartada pela inspecao do contrato. O CPF da
fixture R08 tinha digitos verificadores invalidos (sufixo51). C0 corrigiu
somente esse dado sintetico para sufixo95, sem mudar identidade/Auth/email,
e alterou o cargo para QA sintetico revisado R09. Perfil support e alcance
platform preservados. Salvar retornou ao detalhe; reload manteve cargo e
CPF protegido. Prova internal-user-edited-reload.png e sonda6checksPASS,
incluindo anon401, Auth200, version2 e preservacao de perfil/credencial.
Nao houve troca de senha, convite, envio SMTP ou geracao de link nesta fatia.

SQL45/45 usuarios internos e9/9 criacao PASS no espelho. Inicial45:
43PASS/2FAIL; um assert esperava MFA obrigatorio, anterior a ADR0034/D12,
e o outro teve texto corrompido pelo pipe PowerShell. Corrigido somente o
assert da politica vigente, medida igual em producao; reexecucao por bytes
UTF8 preservou os textos e passou45. Negativas incluem cross-tenant,
escalada de escopo e protecao do ultimo Owner.17corpos de funcoes e policies
internas iguais ao remoto. Sem nova migration nem alteracao de privilegios.

FE/E2E da edicao aceitos; BE done historico preservado. Perfil e atribuicao
de escopo nao foram alterados: catalogo de instituicoes ainda nao composto
no formulario, que preserva o acesso existente. Criar novo usuario continua
com esse gate aberto. Texto inicial do formulario ainda diz nao criar @ ou
Pessoa, incompatibilidade com a ponte service-person ja aprovada; corrigir
na proxima fatia do consumidor, sem inventar nova regra de identidade.

Dados sinteticos R08 retidos com mesmo ID; nenhuma conta QA compartilhada
foi alterada. Memoria: isolamento interno, AAL1 MVP e ponte ja documentados;
esta fatia restaura o caminho de edicao sem mudar regras duraveis.
