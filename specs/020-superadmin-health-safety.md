---
title: "Saúde e Segurança do Superadmin"
source: "pedido aprovado em 2026-08-03; docs/product/prd-master.md; docs/data/data-model.md; docs/security/lgpd-security-media.md; specs/019-superadmin-people-directory.md; decisions/0010-private-media-r2.md; decisions/0015-contextual-people-authorizations-attendance.md"
status: "approved-for-demonstrative-ui"
generated_at: "2026-08-03"
---

# Saúde e Segurança do Superadmin

## Objetivo e problema

Entregar no Superadmin uma central demonstrativa, centrada na criança, para
consultar e representar medicamentos, alergias e restrições e Perfil de
Cuidado. A experiência deve explicar estados operacionais sensíveis sem criar
backend produtivo, ampliar autorização real ou misturar identidade global com
registros privados de um tenant.

## Escopo

- diretório com busca, filtros, cards, tabela, paginação e detalhe da criança;
- filtros globais independentes de Pessoa e Criança, intersectados com a
  hierarquia Instituição → Unidade → Grupo/Atividade;
- três seções neutras no detalhe: Medicamentos, Alergias e restrições e Perfil
  de Cuidado;
- fixtures determinísticas, repositório fake local e capacidades claramente
  rotuladas como demonstração;
- formulários locais para criação e correção excepcional do Owner;
- estados completos de carga, permissão, ciclo do medicamento, doses,
  concorrência e ciência;
- testes unitários, de widget, responsividade, acessibilidade e goldens mínimos.

## Fora de escopo

- telas, rotas ou widgets em `apps/admin` e `apps/principal`;
- banco produtivo, Supabase remoto, migration, RLS, grant, RPC ou dados reais;
- upload, download, URL assinada ou persistência de prescrição/documento;
- novos códigos no catálogo produtivo de permissões, MFA adicional ou
  reautenticação específica;
- diagnóstico automático, comparação clínica de textos livres ou exclusão
  física de histórico.

## Superfícies afetadas

- `apps/superadmin`: navegação, diretório, detalhe, formulários e testes;
- `specs/` e `docs/data/`: contrato aprovado da UI e proposta futura de dados;
- `docs/knowledge`: projeção interna/admin somente após atualização desta
  fonte canônica e passagem no gate de memória.

Os pacotes Coelo UI permanecem inalterados. Componentes administrativos são
reutilizados; composições de saúde permanecem locais à feature.

## Entidades e dados demonstrativos

`people(child)` permanece a identidade global. Cada criança pode possuir vários
`child_contexts`, mas medicamentos, alergias/restrições e Perfil de Cuidado
acompanham a criança global. A visibilidade institucional exige simultaneamente
contexto infantil ativo e autorização familiar válida para saúde.

O modelo local cobre criança, pessoa relacionada, contexto institucional,
medicamento versionado, horário exato, responsável casa/instituição, revisão
institucional, política de lembrete/tolerância/escalonamento, dose, claim,
resultado, alergia/restrição, item do Perfil de Cuidado, notificação de ciência
e evento de auditoria. IDs, relógio e rótulos são fixos e fictícios.

## Permissões e regras de tenant

Conceitos locais separados:

- leitura sensível;
- análise/aprovação de medicamento;
- recebimento de notificações;
- assumir administração;
- registrar resultado;
- configurar perfis responsáveis;
- leitura de auditoria;
- correção excepcional do Owner.

Perfis demonstrativos do Superadmin:

- Owner: lê dados sensíveis e auditoria e corrige com justificativa; não aprova,
  assume nem registra dose em nome de instituição;
- leitor sensível: detalhe somente leitura;
- operador minimizado: somente contagens, pendências e status.

Uma instituição autorizada pode ler os dados globais permitidos, mas não vê
crianças sem contexto/autorização, vínculos alheios nem operação privada de
outro tenant. A UI não é fonte de autorização produtiva.

## Regras de medicamentos

- nome, dose/unidade, via, período e ao menos um horário são obrigatórios;
- frequência diária é derivada da quantidade de horários;
- cada horário possui exatamente um responsável: casa ou uma instituição;
- revisão pertence à versão e à instituição responsável; casa não recebe
  notificação institucional;
- fluxo: Solicitado → Em análise → Aprovado ou Recusado → Ativo → Encerrado;
- notificações institucionais começam somente após aprovação;
- recusa exige motivo;
- mudança relevante invalida aprovações, volta a Em análise, pausa doses
  institucionais futuras e preserva administrações passadas;
- claim impede duplicidade; conflito informa quem já assumiu; liberação e
  expiração seguem política institucional;
- Não administrado e Recusado exigem motivo, horário e autor;
- alergias/restrições medicamentosas ativas são destacadas, sem diagnóstico
  automático.

## Alergias, restrições e Perfil de Cuidado

Somente o nome do item de alergia/restrição é obrigatório. Alterações entram em
vigor imediatamente, geram nova ciência e mantêm histórico; excluir significa
inativar.

O Perfil de Cuidado usa catálogo central e extensível agrupado em
Neurodesenvolvimento, Desenvolvimento motor e mobilidade, Visão, Audição e
comunicação, Condições genéticas, Condições de saúde e Outro. A linguagem é de
apoio, não diagnóstico. “Outro” exige nome livre. Cada alteração gera uma única
notificação com recibo separado de ciência; não usa claim de administração.

## Estados e comportamento de UX

O diretório cobre loading, vazio inicial, nenhum resultado, erro/retry, sem
permissão, resumo minimizado, cards, tabela e paginação. O detalhe cobre somente
leitura, criação/edição, salvando, todos os estados de medicamento e dose,
conflito de claim e ciência pendente/concluída.

Instituições é a matriz de composição; Pessoas é a referência de identidade
global e filtros. O detalhe usa três seções empilhadas, sem `TabBar` ou nova
navegação. A UI usa constraints e é validada em 375, 768, 1024 e 1440 px,
light/dark, texto a 200%, teclado, mouse, toque, foco, semântica e reduced motion.

## Eventos, logs e notificações

Fixtures representam lembrete antecipado, notificação no horário, tolerância,
atraso, escalonamento, profissionais múltiplos, claim e ciência. Correções do
Owner preservam before/after, ator, horário e justificativa. Push demonstrativo
não inclui conteúdo sensível. Nenhum evento sai do processo local.

## Critérios de aceite

- Pessoa/Criança podem ser selecionadas antes de instituição e nunca são
  podadas pela hierarquia institucional;
- filtros combinados intersectam resultados e filtros filhos respeitam seus
  pais;
- criança multi-instituição e medicamento com casa e instituições distintas
  são demonstrados;
- perfis sem leitura sensível nunca recebem detalhe sensível;
- somente Owner altera registros nesta superfície e toda correção é auditada;
- Owner não executa ações operacionais institucionais;
- estados, formulários, concorrência, alergia destacada e ciência são visíveis
  e testáveis;
- nenhum dado real, segredo, schema remoto ou pacote público é criado.

## Testes exigidos

- filtros, paginação, validações, versionamento, transições, claim concorrente,
  motivos, capacidades, ciência e fixtures;
- diretório, detalhe, formulários, permissões, notificações, teclado, foco e
  semântica;
- ausência de overflow nos quatro viewports, temas, texto a 200% e reduced
  motion;
- goldens mínimos: diretório 375 light, tabela 1440 dark, detalhe 375 light e
  formulário de medicamento 1440 dark;
- regressões de Pessoas, Instituições, shell e router; análise estática e
  `git diff --check`.

## Riscos e perguntas abertas

- `OQ-003` mantém base legal, papéis jurídicos e retenção pendentes antes de
  piloto produtivo;
- a ADR 0010 e o spike R2 ainda não autorizam anexos produtivos;
- `guardian_context_permissions` concede acesso familiar ao contexto
  institucional e não deve ser reutilizada como autorização inversa de saúde;
- o schema, RLS, RPCs e concorrência produtivos exigem spec técnica e revisão
  humana próprias antes de qualquer migration.
