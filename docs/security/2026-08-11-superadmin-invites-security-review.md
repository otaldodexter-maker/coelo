---
title: "Revisão de segurança dos Convites do Superadmin"
source: "specs/026-superadmin-invites-production.md; decisions/0020-backend-authorization-application-security.md; packages/coelo_database/migrations/20260811233609_superadmin_invites_production.sql"
status: "implementation-review"
generated_at: "2026-08-11"
---

# Revisão de segurança dos Convites do Superadmin

## Resultado executivo

O contrato local segue a direção backend-first: capacidades explícitas, MFA AAL2
para comandos, hierarquia validada no banco, token de alta entropia persistido
somente como hash, idempotência, versão otimista, locks e auditoria minimizada.
A migration compilou e seus 60 checks pgTAP passaram no projeto remoto dentro de
`BEGIN/ROLLBACK`; nada foi persistido. Contratos estáticos, secret scan e
sincronização/hash canônico da migration também passaram.

A revisão inicial encontrou acesso residual do emissor e execução direta de
implementações privadas. Ambos foram corrigidos: a policy direta é exclusiva do
destinatário e as funções `app_private` não são executáveis por roles do
browser. Permanecem pendentes a infraestrutura segura de entrega por e-mail, a
rota de aceite, uma política operacional de antiabuso, auditoria durável de
negações e execução local completa quando Docker/Podman estiver disponível.

## Escopo, método e evidências

- Revisão somente leitura da spec 026, migration local e teste pgTAP de Convites.
- Consulta remota, em 2026-08-11, apenas a catálogos de schema/RLS/RPC/capability;
  nenhum DDL ou dado de negócio foi alterado.
- OWASP ASVS 5.0.0 L2 como baseline e L3 para administração privilegiada,
  autorização, concorrência, auditoria e segredos.
- Estados abaixo usam **verificado em rollback** para evidência executada sem
  persistência, **verificado remoto atual** para o schema produtivo e **pendente**
  quando falta controle ou evidência suficiente.

## Estado remoto atual versus migration local

| Área | Projeto remoto em 2026-08-11 | Migration local proposta |
| --- | --- | --- |
| `public.invitations` | 21 colunas legadas; sem `target_kind`, `profile_id`, `channels`, `version`, `validity_hours` e `updated_at` | adiciona os seis campos, FK de perfil, checks de alvo/canal/escopo/ciclo de vida e índices de diretório |
| RLS | habilitada, não forçada; policy legada lê por destinatário ou emissor | habilita `FORCE RLS`, restringe SELECT direto ao destinatário e revoga DML direto |
| Comandos | nenhuma RPC `superadmin_invite_*` | seis gateways públicos mínimos, seis implementações privadas revogadas e read model privado `security_invoker` |
| Capacidades | nenhuma `platform.invites.*` | `platform.invites.read` e `platform.invites.manage`; Owner recebe ambas e manage exige AAL2 |
| Estado privado | nenhuma tabela `superadmin_invite_*` em `app_private` | recibos idempotentes e outbox de e-mail hash-only |
| Entrega | não existe contrato produtivo | link retornado uma vez por origem privada revisada; job de e-mail permanece `pending`, sem worker/provedor |

O snapshot de Advisors consultado é o do schema remoto anterior à migration e
contém achados globais de outros domínios. Ele não valida nem reprova os objetos
locais de Convites, pois esses objetos ainda não existem no projeto remoto.
O teste isolado em rollback prova compilação e comportamento, não substitui
Advisors pós-deployment nem a decisão de aplicar a migration.

## Matriz OWASP ASVS 5.0.0

| Controle | Nível | Decisão e evidência | Estado |
| --- | --- | --- | --- |
| `v5.0.0-2.1.1`, `v5.0.0-2.1.2` | L2 | A spec define formato, cardinalidade e consistência de canal, alvo, validade, escopo e perfil. | verificado em rollback |
| `v5.0.0-2.2.1`, `v5.0.0-2.2.2`, `v5.0.0-2.2.3` | L2 | RPCs e trigger usam allowlists, tipos, limites e relações instituição → unidade → turma; Flutter não é controle. | verificado em rollback |
| `v5.0.0-2.3.3`, `v5.0.0-2.3.4` | L2 | Comandos são transacionais; advisory lock serializa chave/identidade de convite e `FOR UPDATE` protege reenvio/revogação. | estrutura verificada; corrida simultânea não simulada |
| `v5.0.0-2.4.1` | L2 | Há limite local de vinte recibos por ator/minuto. Não há política distribuída, configuração por risco, alerta ou limite do worker. | parcial |
| `v5.0.0-7.5.3` | L3 | Emitir, reenviar e revogar revalidam AAL2 no servidor. | verificado em rollback, inclusive negação AAL1 |
| `v5.0.0-8.1.1`, `v5.0.0-8.1.2` | L2 | A spec documenta capacidade, recurso, campos minimizados, estados e transições. | verificado em rollback |
| `v5.0.0-8.2.1`, `v5.0.0-8.2.2`, `v5.0.0-8.2.3` | L2/L3 | Gateways exigem capability; IDs e perfil são validados; JSON omite hash e contato completo; SELECT direto é apenas do destinatário. | verificado em rollback |
| `v5.0.0-8.3.1` | L2 | Autorização reside em função server-side; funções privadas recalculam ator/capability/AAL e não têm grant para browser. | verificado em rollback |
| `v5.0.0-8.3.2` | L3 | Revogar membership invalida imediatamente o detalhe RPC; emissor não lê diretamente por RLS. | verificado em rollback |
| `v5.0.0-8.4.1` | L2/L3 | Trigger rejeita pais/filhos e perfil de instituições diferentes; pgTAP cobre unidade, turma e perfil trocados. | verificado para Owner global; papel institucional restrito não se aplica a esta capability |
| `v5.0.0-13.3.1`, `v5.0.0-13.3.2` | L2/L3 | SQL guarda somente SHA-256 e máscara; static secret scan passou. Secret manager do futuro worker ainda precisa de desenho. | parcial |
| `v5.0.0-14.2.6`, `v5.0.0-15.3.1` | L3/L2 | Read model minimiza campos; contato fica mascarado; replay nunca recompõe o link. | verificado em rollback |
| `v5.0.0-15.4.2` | L3 | Checagem de versão, estado e alteração ocorre sob lock na mesma transação. | estrutura verificada; corrida simultânea não simulada |
| `v5.0.0-16.2.1`, `v5.0.0-16.2.5` | L2/L3 | Issue, resend e revoke registram ator, objeto, escopo, AAL e before/after sem token ou contato integral. | verificado em rollback |
| `v5.0.0-16.3.2`, `v5.0.0-16.3.3` | L3 | L3 requer decisões de autorização e tentativas de bypass. A migration registra apenas comandos bem-sucedidos. | **não atendido** |
| `v5.0.0-16.5.1`, `v5.0.0-16.5.3` | L2 | Comandos falham fechados; após capability revogada, ID existente e desconhecido retornam a mesma negação. | verificado em rollback |

## Threat model curto

| Ameaça | Controle esperado | Evidência atual | Lacuna |
| --- | --- | --- | --- |
| IDOR/BOLA por convite ou pai/filho trocado | localizar o objeto dentro do conjunto autorizado e validar toda a cadeia | checks/trigger; unidade, turma e perfil divergentes; revogação imediata; RLS target-only | ampliar equivalência de ID inexistente/fora de escopo a cada comando |
| Elevação de função | capabilities opt-in, AAL2 e gateway mínimo | `platform.invites.read/manage`; AAL2; privadas sem grant; wrappers mínimos com `search_path` vazio | Advisor pós-deployment deve registrar a justificativa dos gateways `SECURITY DEFINER` |
| Replay e duplo submit | request UUID, hash do payload, lock e resultado sem segredo | receipts, advisory lock, conflito de payload e replay sem link | falta execução concorrente real e política de retenção dos recibos |
| Roubo/reuso de link | CSPRNG, hash em repouso, expiração, rotação e revogação | 32 bytes aleatórios; SHA-256; reenvio troca hash/versão; origem privada não aceita input do cliente | aceite/consumo atômico e proteção de Referer/log ainda não existem |
| Enumeração | erros e contagens equivalentes, filtros server-side | filtros/paginação server-side; ID existente/desconhecido equivalentes sem capability | faltam comparações para ator parcialmente autorizado, filtros e offset |
| Abuso de emissão | limite por ator, provedor com quota/backoff e alertas | limite local 20/min | limite distribuído/por destinatário/escopo, telemetria e worker pendentes |
| Vazamento de contato ou segredo | minimização, destino protegido e secret manager | hash e máscara no banco/outbox; link omitido no replay | outbox não contém destino recuperável de forma segura para entregar e-mail |
| Auditoria incompleta | before/after e todas as decisões privilegiadas | sucesso de issue/resend/revoke | negações e bypasses não persistem em trilha separada |

## Matriz negativa IDOR/BOLA

| Vetor forjado/chamada direta | Operações que devem falhar fechadas | Evidência | Pendência |
| --- | --- | --- | --- |
| usuário anônimo | list/options/get/issue/resend/revoke e SELECT direto | pgTAP cobre diretório anônimo | ampliar para todas as operações |
| autenticado sem capability | list/options/get/issue/resend/revoke | pgTAP cobre diretório sem read | cobrir detalhe e cada comando |
| AAL1 em ação privilegiada | issue/resend/revoke | pgTAP cobre issue | cobrir resend/revoke |
| capability ou membership revogada após uma leitura | RPC seguinte e SELECT direto | membership revogada nega detalhe; emissor não lê por RLS | ampliar a options/directory/issue/resend/revoke |
| `institution_id` de B | issue/options/filtros/listagem | combinação pai/filho coberta indiretamente | ator com escopo institucional restrito não existe no teste |
| `unit_id` de B sob instituição A | options/issue/filtros | pgTAP cobre issue | cobrir options e listagem sem oracle |
| `group_id` de B sob unidade A | options/issue/filtros | pgTAP cobre issue | cobrir options e listagem sem oracle |
| `profile_id` de B | issue/filtros | pgTAP cobre issue | cobrir options e filtro |
| `target_person_id` de outro contexto ou criança | issue | trigger exige pessoa adulta ativa | falta provar vínculo/escopo autorizado quando a capability não for global |
| `invite_id` inexistente ou de escopo não autorizado | get/resend/revoke/deep link | existente/desconhecido equivalem quando capability foi revogada | cobrir ator autorizado sem relação, cada comando e variação temporal |
| status/versão adulterados | resend/revoke | versão e transição estão no SQL; revogado → resend coberto | cobrir accepted, pending não expirado, versão velha e corrida real |
| canal `sms`, canal duplicado ou vazio | issue/resend | SMS coberto; função normaliza duplicatas | cobrir vazio, excesso e combinações inválidas em ambos |
| busca, sort, filtros, datas, limit e offset maliciosos | directory/options | null array falha fechado; texto de SQL injection é tratado como texto; allowlists/limites | adicionar negativos de datas, paginação, XSS e cardinalidade |
| chamada da implementação privada | todas as funções `app_private` | ACL confirma ausência de `EXECUTE`/SELECT para browser | verificado em rollback |

## Achados e ações antes de aplicar remotamente

1. **Pendente operacional — e-mail não entregável.** A outbox guarda apenas
   hash e máscara. Definir worker/provedor e armazenamento/encaminhamento do
   destino com proteção apropriada, sem tornar o contato recuperável pelo
   Flutter. Até lá, estado deve permanecer `pending`, nunca `sent`.
2. **Alto — aceite ainda não implementado.** A origem é encapsulada em helper
   privado revisado e não aceita GUC/input do cliente, mas a rota ainda precisa
   consumir o token de forma atômica, expirável e não enumerável, com políticas
   de Referer, logs e cache.
3. **Alto — rate limiting incompleto.** Formalizar limites por ator,
   destinatário, instituição e provedor, backoff, retry máximo, alertas e
   resposta a abuso. O contador local é apenas primeira barreira.
4. **Alto — auditoria de negações ausente.** Registrar decisões negadas e
   tentativas de bypass em caminho que sobreviva ao rollback da transação, sem
   IDs ou contatos indevidos.
5. **Gate — evidência de ambiente persistente ausente.** O rollback remoto
executou 60 checks e os gates estáticos passaram. Ainda faltam reset/teste
   local quando Docker/Podman existir, corrida concorrente real, Advisors e query
   real pós-deployment, além da inspeção final do bundle antes de aplicar.

## Pendências operacionais declaradas

- Provedor/worker de e-mail, fila consumível, retry/backoff, DLQ, telemetria e
  segredo server-side.
- Política distribuída de rate limiting e antiabuso além do contador local.
- Origem pública final e implementação da rota de aceite; o token bruto não pode
  entrar em logs, analytics, screenshots ou armazenamento do Flutter.
- Retenção/limpeza de receipts, outbox, tokens expirados e eventos de auditoria.
- Execução dos negativos ainda abertos e dos gates pós-deployment.

## Referências

- OWASP ASVS 5.0.0, release estável e formato versionado de requisitos:
  https://github.com/OWASP/ASVS/tree/v5.0.0
- Supabase Database Linter:
  https://supabase.com/docs/guides/database/database-linter
