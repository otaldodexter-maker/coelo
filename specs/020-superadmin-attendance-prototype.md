---
title: "Protótipo local de Assiduidade e Chamada"
source: "plano aprovado pelo usuário em 2026-08-03"
status: "implemented-local-prototype"
generated_at: "2026-08-03"
---

# Protótipo local de Assiduidade e Chamada

## Objetivo e problema

Validar no Superadmin a leitura gerencial de assiduidade e o fluxo operacional de chamada sem backend produtivo. O protótipo separa intenção familiar de registro oficial, preserva escopo contextual e demonstra correção auditável.

## Escopo

- Dashboard e drill-down de instituição, unidade, grupo, atividade, chamada e participante.
- Nova chamada, preenchimento individual e em lote, conclusão, leitura e correção.
- Aviso familiar fictício pendente, sino navegável e confirmação profissional.
- Prévia dedicada para professor e rotas equivalentes em `/dev`.

## Fora de escopo

Supabase, persistência após recarga, envio real de notificações, motor de agenda, arquivos no Principal e APIs públicas novas dos pacotes UI.

## Superfícies afetadas

Somente `apps/superadmin`, nas rotas `/attendance`, `/attendance/new`, `/attendance/calls/:callId`, prévia do professor e espelhos `/dev`.

## Entidades e dados

Presença: não marcado, presente, ausente, atraso e saída antecipada. Justificativa: pendente, aceita e rejeitada. Chamada: não iniciada, em andamento, concluída e corrigida. Avisos familiares são intenções locais e revisões guardam antes, depois, motivo e ator.

## Permissões e tenant

Permissões são tipadas. Owner administra; administrador somente leitura não recebe ações; professor acessa apenas grupos e vínculos de atividade atribuídos. O cliente demonstrativo não amplia autorização produtiva.

## Estados de UX

Incluem chamada não exigida, nenhuma prevista, estados operacionais, vazio, filtros de período, foco em participante e leitura de chamada concluída. A navegação usa tokens e componentes Coelo, teclado, foco e semântica.

## Eventos, logs e notificações

Aviso familiar cria item local no sino com destino para chamada e participante, sem alterar KPI. Confirmação profissional cria registro oficial. Correção exige motivo e gera revisão local.

## Critérios de aceite

A presença é `(presente + atraso + saída antecipada) / registros oficiais`. Avisos pendentes, chamadas não exigidas e não previstas ficam fora do denominador. Operações em lote preservam exceções; conclusão bloqueia não marcados; correção é exclusiva do Owner.

## Testes exigidos

Testes de repositório, permissões, páginas, sino e rotas; análise estática; shell; responsividade, tema, teclado, semântica, reduced motion e texto a 200%.

## Riscos e perguntas abertas

Fixtures não validam RLS nem concorrência. A numeração `020` também é usada por Saúde e Segurança e precisa de decisão documental futura, registrada em `docs/open-questions.md`.
