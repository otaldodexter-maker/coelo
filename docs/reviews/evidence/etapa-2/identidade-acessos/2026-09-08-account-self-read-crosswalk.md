---
title: "Conta — crosswalk para leitura nominal do próprio usuário interno"
source: "reserva de design do Coordenador; design Perfil/Settings; ADR 0019; spec 039; schema Users"
status: "proposal-for-review; no-sql-or-wiring-authorized"
generated_at: "2026-09-08"
---

# Objetivo e contrato do trabalho

Desenhar uma leitura mínima de Conta no Superadmin, sem alvo escolhido pelo
cliente, sem pessoa global e sem reutilizar comando administrativo. Incluído:
fontes, alternativas, projeção proposta e matriz de fixture. Fora: edição,
MFA/senha, e-mail transacional, avatar/Media Gateway, Auth global e produção.
Ordem: crosswalk → revisão nominal → contrato aprovado → fixture/implementação
reservadas. Parada desta fatia: proposta revisável, não endpoint implementado.
Estimativa de desenho/review: 30–60 minutos; implementação/E2E depende do
contrato escolhido e da fila nominal, sem ETA de produção inventada.

## Checklist de desenho

- Contexto/fontes e histórico: lidos; nenhum contexto visual exige mockup.
- Alternativas e projeção: propostas abaixo, não aprovadas como produto.
- Questão nominal: decidir semântica de e-mail e estado de cadastro ausente.
- Revisão e aprovação da especificação: pendentes do Coordenador/Owner.
- Plano, fixture SQL executável e implementação: somente após esse gate.

## Fontes e correspondência

| Dado/ação | Fonte atual | Limite para a leitura produtiva |
|---|---|---|
| Nome/sobrenome | `superadmin_internal_profiles.first_name/last_name` | Texto cadastral interno; não buscar em people/user_metadata |
| E-mail profissional | `superadmin_internal_profiles.professional_email` | Não presumir igualdade atual com login Auth |
| E-mail de login | `auth.users.email` pelo auth_link exato | Distinto semanticamente do contato profissional; rótulo/fonte precisam estar explícitos |
| Celular cadastral | `superadmin_internal_profiles.mobile` | Não equivale a telefone verificado de autenticação |
| Papel/capacidades | Contexto interno revalidado, catálogo existente | Só leitura; não serializar de volta como draft editável |
| MFA | DTO local possui bool prototípico | AAL de sessão não equivale a enrollment MFA; não preencher bool por inferência |
| Avatar/sigla/cor | DTO local com bytes e valores de apresentação | Binário produtivo depende E2E 3; não converter em URL pública/base64 no RPC |
| Solicitação de e-mail | `EmailChangeRequest` em memória | Não existe fluxo produtivo comprovado; não mostrar aprovação local como real |

Fontes lidas: `docs/knowledge/team/superadmin-profile-settings.md` e sua fonte
`docs/superpowers/specs/2026-07-28-superadmin-profile-settings-design.md`;
`apps/superadmin/lib/features/account/domain/account_profile.dart`;
`apps/superadmin/lib/features/account/data/account_profile_repository.dart`;
`apps/superadmin/test/app/router/account_routes_test.dart`; schema das
migrations `20260901190927` e `20260901210000`; ADR 0019/spec 039 e aditivo AAL1.

`/profile` hoje permanece 503; `/dev/profile` usa InMemory. A identidade interna
base contém apenas ID/autoria/data; o cadastro textual depende da tabela Users.
Não há garantia de que todo ator provisionado já tenha linha nessa tabela.

## Alternativas

1. **Reader textual próprio (recomendado):** DTO estrito de leitura, fonte
   interna derivada no servidor, estado explícito se cadastro ausente. Menor
   exposição e permite avançar sem avatar ou allowlist de escrita.
2. Reaproveitar DTO/editor local completo: exige inventar dados de MFA,
   aprovação de e-mail e avatar; não recomendado como ponte de produção.
3. Resolver leitura e edição/contato/avatar juntos: coerente somente após
   contratos adicionais, mas acopla dependências independentes desnecessariamente.

## Proposta para revisão, não contrato aprovado

RPC nominal sem parâmetros de identidade/recurso, derivada da sessão real e
capacidade de entrada interna vigente (candidata `platform.read`, não grant
novo). Validar sessão exata, auth_link/membership ativos, realm e escopo no
servidor; rejeitar conta Admin/Principal. AAL1 conforme aditivo vigente, sem
novo requisito MFA. Nenhum resultado antes da autorização.

Primeira projeção candidata: `first_name`, `last_name`, `professional_email`
e `mobile`, com rótulos de cadastro. O e-mail de login pode ser campo separado
somente se aprovado; não usar fallback entre essas duas fontes. O resumo de
acesso continua separado do DTO cadastral e deriva do contrato Auth existente.
Sem CPF/data de nascimento/endereço/notas, IDs Auth, tokens, sessão, claims
mutáveis, bytes de avatar ou solicitação de e-mail simulada.

Cadastro ausente deve produzir estado explicitamente tipado e honesto, sem
inventar nome/contacto ou criar registro. Nome/código exato de erro e UX desse
estado precisam do contrato nominal antes da fixture executável. Reusar os
envelopes/erros internos vigentes para falhas de sessão/capacidade, sem retornar
payload parcial. Auditoria deve registrar a leitura sem valores pessoais.

## Matriz proposta de fixture

- A interno sem people recebe somente seu cadastro; B recebe somente B.
- Não existe parâmetro de ID-alvo que permita IDOR; payload contém exatamente
  allowlist aprovada e nenhum campo excedente.
- Sem sessão, sessão excluída/revogada, vínculo/membership suspensos/revogados,
  realm Admin/Principal e capacidade removida negam sem dados.
- Owner e demais atores admitidos em AAL1 conforme gate vigente; não inferir MFA.
- Cadastro textual ausente recebe o estado nominal aprovado, sem fallback.
- E-mails profissional/login divergentes preservam a fonte/rótulo contratados.
- Leitura após alteração e nova sessão/reload reflete persistência real.
  A alteração é preparação controlada da fixture, não endpoint self-edit
  implicitamente autorizado.
- Cliente descarta resposta anterior na troca de contexto; retry não ressuscita
  snapshot antigo. Nenhuma ação de salvar habilitada nesta fatia.

A matriz ainda não é pgTAP escrito/executado. Replay exige pacote nominal Eng1;
produção exige lease separado. RLS/grants existentes permanecem sem expansão.
Self-edit continua exigindo allowlist aprovada e contrato de concorrência/audit.
Memória: não promover proposta a Knowledge nem alterar fonte canônica aprovada.

Review independente account_review: sem bloqueantes como proposta; não aprova
contrato de produto. Nenhuma fixture SQL executável foi escrita ou executada.
