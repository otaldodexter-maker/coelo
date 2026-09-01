---
source: "Plano aprovado pelo Owner Coelo em 2026-08-05; docs/product/prd-superadmin.md; docs/data/data-model.md; decisions/0016-unit-type-and-plan-inheritance.md; specs/018-profiles-permissions-superadmin.md"
status: "approved-for-local-prototype"
generated_at: "2026-08-05"
---

# Gestão de Planos do Superadmin

## Objetivo

Completar a experiência local de gestão do catálogo global de planos no
Superadmin, cobrindo diretório, criação, edição, capacidades, limites,
instituições vinculadas e revisão auditável, sem promover fixtures a contrato
produtivo.

## Escopo

- Diretório em Cards e Tabela, busca por nome ou código, filtros
  Todos/Ativos/Arquivados, paginação e estados administrativos.
- Criação em Identificação, Capacidades, Limites e Revisão.
- Edição com a etapa adicional Instituições vinculadas, somente leitura.
- Arquivar e restaurar com motivo obrigatório; nenhuma exclusão permanente.
- Dados locais determinísticos e rotas `/dev` existentes.

## Fora de escopo

- Preço, moeda, cobrança, pagamento ou assinatura automática.
- Supabase, migrations, RLS, policies, RPCs e promoção para rota produtiva.
- Enforcement de limites no cliente.
- Limite de responsáveis por criança.
- Processamento real de importação ou exportação de arquivos; as opções devem
  permanecer visíveis no diretório e comunicar indisponibilidade até existir
  gateway produtivo, sem callback vazio ou sucesso falso.

## Contrato de domínio

- Plano e entitlement descrevem oferta contratada; não autorizam pessoas.
- Permissão e escopo contextual continuam responsáveis por autorizar ações.
- Subscription vincula instituição e plano e possui status/datas próprios.
- Unidades herdam o plano institucional, salvo override explícito.
- Limites exibidos no protótipo são informativos.
- Capacidades usa composição/matriz privada orientada por catálogo; ações como
  Ver, Editar ou outras só aparecem quando forem entitlements comerciais
  canônicos. Enquanto não houver catálogo granular aprovado, exibir somente
  `Incluído no plano`, sem inventar códigos.

## UX e estados

- Instituições é a baseline de diretório, cards, tabela, toolbar e paginação.
- Criar/Editar Instituição é a baseline de formulário, steps e footer.
- Perfis e Permissões é referência apenas para hierarquia visual da matriz.
- Estados obrigatórios: loading, empty, no-results, error, unauthorized,
  conflict, saving, archived, sem instituições e plano em uso.
- Layout validado por largura disponível em 375, 768, 1024 e 1440 px,
  light/dark, texto a 200%, teclado, foco visível e reduced motion.

## Auditoria

- Criar, editar, arquivar e restaurar exigem motivo livre não vazio.
- A UI representa MFA como requisito do caminho autoritativo, sem implementá-la
  no cliente local.
- Conflitos preservam o draft e não fazem merge automático.

## Critérios de aceite

- Busca, status, visualização e paginação preservam uma consulta coerente.
- Criar e editar salvam somente na etapa Revisão.
- Código fica imutável na edição.
- Instituições vinculadas não oferecem mutação de subscription.
- As opções de arquivos são explícitas e honestamente indisponíveis enquanto o
  backend não existe; não há callback vazio, download fictício, preço ou
  autorização simulada.
- Testes, goldens e análise da feature passam sem localhost; o validador visual
  não aponta violações em arquivos de Planos.
