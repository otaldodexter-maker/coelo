---
source: C0 UI normal; G2 R09 r162; ADR0034 Decisao16; production RPCs
status: verified
generated_at: 2026-09-12
---

# Pessoas — criar, editar e identificador

apps/superadmin -> Acessos -> Pessoas -> Criar/Editar/Detalhes ->
people.create, people.edit. C0 executou a fatia; G2 r162 estava completed
e seu handoff foi integrado por merge real9107f287b. Não afirmar nova
instrução entregue ou execução de G2 nesta sessão.

Pelo diretório normal, Criar pessoa abriu o resolvedor produtivo de identidade.
Consultado e-mail sintético qa-r09-pessoa-1542@example.invalid, sem correspondência.
O formulário recebeu identidade sintética e zero vínculos; revisão explicitou
rascunho sem ativação de login. Salvar criou cb989d45-6ab2-419c-9373-104bd2a01684.
Diretório buscou o registro; detalhe e reload mantiveram nome/tipo/rascunho e
@ gerado qar09.pessoasintetica. Imagens people-created e people-created-reload.
Nenhum e-mail enviado ou conta Auth criada pelo formulário.

Editar pelo detalhe -> nome de exibição QA R09 Pessoa sintetica 1542 editada
-> revisão -> Salvar -> diretório/reload: nome mantido (people-edited-reload).
Leitura SQL independente confirmou id, display_name, person_type adult,
status draft. Duas consultas iniciais de metadados falharam por colunas
inexistentes kind/auth_user_id, sem escrita; consulta corrigida passou.

O @ inicial mostrou botão desabilitado e prazo no mesmo dia, apesar de
zero trocas anteriores no ledger. O modelo comparava can_change_at com
relógio local mesmo sem last_changed_at. O servidor retorna now() nessa
situação: diferença entre relógios causava cooldown indevido.
Teste reproduziu1FAIL (outro1PASS), correção exige troca anterior para
cooldown local. Regra/autorização/trigger do servidor preservados.
Dois testes atuais PASS: disponibilidade/troca/motivo/cooldown e somente
leitura;0FAIL/0SKIP. Análise0issues. Build QA release56,2s exit0, emulações
de teclado e arquivo false; mesmo Chrome22592/servidor48684/3014.
Aviso preexistente CupertinoIcons ausente no dry-run, sem erro de build.

No novo build, Alterar @ habilitado -> qar09.pessoa1542 disponível -> motivo
sintético -> Salvar. Detalhe e reload mantêm @ e bloqueio até12/10/2026.
Imagens people-handle-available/saved/reload. Prova real complementar
people-handle-negative.py/.json:6PASS, incluindo Auth/logout próprios;
anon401, releitura200, segunda troca negada400/22023 cooldown e @ preservado.
Nenhuma sessão do navegador alterada pela sessão API própria.

BE done existente preservado: create_draft/update reais R04, lookup11/11,
person_handles22/22 (inclui pessoa sem acesso e controle de proprietário),
H28 lote59/44pgTAP e19 testes focais documentados no handoffG2. Não somar
essas execuções antigas como testes novos. Nenhuma sessão real tenant B
nova nesta fatia; negativas válidas da família reaproveitadas, com negativa
anônima/cooldown reais adicionais. Não certificar vínculo inexistente.

Observação de composição: a etapa Vínculos contextuais informa que a busca
de adultos/crianças está indisponível e a mantém desabilitada. Nenhum vínculo
criado nesta fatia; não atribuir prova nova a people.links/H28. A correção
focal de consumidores de vínculos continua pendência independente.

FE e E2E de people.create/edit aceitos pela identidade/rascunho, edição e @
produtivos com persistência/reload e autorização. Sem crescimento de BE/SQL
ou aprovação visual. Sintético cb989d45 e @ qar09.pessoa1542 retidos;
nenhum segredo, mídia, chave de serviço ou login novo.
Memória: coelo-handles.md já define geração inicial e troca30dias; ajuste
restaura contrato aprovado, sem nova regra de produto.
