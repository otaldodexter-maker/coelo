---
title: "Modelos, rotinas aplicadas e lancamentos de Rotina diaria"
source: "plano aprovado pelo usuario em 2026-08-11"
status: "approved"
generated_at: "2026-08-11"
supersedes: "partes de Rotina diaria em specs/024-superadmin-attendance-daily-routine-production.md"
---

# Modelos, rotinas aplicadas e lancamentos de Rotina diaria

## Objetivo

Substituir o prototipo local por tres agregados persistentes e auditaveis: `Modelo`,
`Rotina aplicada` e `Lancamento`. O Flutter coleta intencao e apresenta o resultado;
escopo, hierarquia, capabilities, transicoes, limites e valores condicionais sao
recalculados no backend em toda requisicao.

## Matriz de aplicacao

| Tema | Decisao aprovada |
|---|---|
| Aparencia | Instituicoes no diretorio; Criar/Editar Instituicao no formulario; Popup de Bug nos dialogs |
| Heranca | Instituicao para unidade e turma, com origem, herdado, efetivo e personalizacao reversivel |
| Localizacao/contato | Nao se aplica |
| Representantes | Nao se aplica |
| Admins/profissionais | Somente memberships contextuais responsaveis |
| Pessoas/perfis | Referencias a responsaveis e criancas; nao cria nem edita pessoa |
| Tipos/subtipos | Tipos fixos de campo e opcoes ordenadas locais |
| Status | Status do modelo, da rotina e do lancamento, separadamente |
| Hierarquia | Aplica a leitura, escrita, filtros, arquivos e deep links |
| Plano | Nao se aplica nesta entrega |
| Import/export | Somente configuracao XLSX v1; nunca respostas ou dados infantis |
| Midia | Fora de escopo; nenhum campo foto ou imagem de apoio |
| Perfil publico/descoberta | Nao se aplica |
| Ramificacao | Sim/nao, escolha unica e multipla, no maximo quatro niveis |

## Entidades e invariantes

`RoutineModel` possui identidade e versoes publicadas imutaveis. Secoes, campos,
opcoes e condicoes usam IDs estaveis e `sort_order`. Campos aceitam texto curto,
texto longo, numero, sim/nao, escolha unica e multipla. `initial_value` deve ter o
tipo correto; numero respeita minimo e maximo; escolhas referenciam opcoes
existentes. Opcoes sao linhas individuais, nunca CSV.

`RoutineApplication` liga uma versao do modelo a instituicao, unidade e turma.
Guarda origem, pai, modo `inherited|customized`, revisao efetiva, validade,
visibilidade, responsaveis por membership e historico. Reverter personalizacao
restaura o valor herdado sem apagar auditoria.

`RoutineLaunch` referencia uma revisao imutavel da aplicacao e o contexto de data,
instituicao, unidade, turma e atividade. Seu ciclo e `draft`, `published`,
`corrected` ou `cancelled`; correcao exige motivo e revisao before/after. Respostas
ocultas pela arvore condicional sao rejeitadas pelo backend.

Condicoes referenciam campo pai e opcao ou valor booleano. O banco rejeita campo
inexistente, opcao estrangeira, ciclo e profundidade superior a quatro. A mesma
validacao ocorre no editor apenas para feedback imediato.

## Importacao e exportacao

XLSX v1 contem as planilhas `Modelos`, `Secoes`, `Campos`, `Opcoes`, `Condicoes` e
`Aplicacoes`. O job real possui template versionado, arquivo privado temporario,
preview, validacao por linha/campo, confirmacao, progresso, erros e resultado.
Publicar, corrigir, importar e exportar exigem AAL2. Exportacao exclui lancamentos,
respostas e qualquer dado infantil.

## Permissoes e seguranca

Todo membro ativo da plataforma Superadmin recebe capability server-side de
Rotina diaria conforme a decisao desta tarefa. Isso substitui, apenas nesta
superficie, a restricao anterior do PRD que afastava o Superadmin da operacao
cotidiana; o conflito permanece registrado em `docs/open-questions.md` para
ratificacao de produto. Nenhuma permissao `Owner` constante participa do router.

ASVS nivel 2 e o piso. Controles de nivel 3 valem para dados infantis, operacao
privilegiada, AAL2, auditoria, chaves e publicacao/correcao. Cada operacao valida
ator, tenant, instituicao, unidade, turma, atividade, crianca, membership,
capability, ownership e cadeia hierarquica. A consulta parte do conjunto
autorizado; nunca busca ID global para filtrar depois.

Tabelas expostas usam grants minimos e RLS deny-by-default, com policies separadas
por operacao e `USING` mais `WITH CHECK` no update. Views sao `security_invoker`.
RPCs novas revogam EXECUTE de `PUBLIC`, `anon` e `authenticated` e concedem apenas
wrappers necessarios. Funcoes `SECURITY DEFINER`, quando indispensaveis, ficam em
schema nao exposto, usam `search_path=''` e revalidam identidade/capability/AAL2.
Comandos usam `request_id`, `expected_version`, transacao, lock e recibo
idempotente.

## Threat model curto

- IDOR/BOLA por troca de tenant, instituicao, unidade, turma, atividade, crianca,
  parent/child, UUID, slug, filtro, pagina, deep link ou path de arquivo.
- Escalada por membership revogada, JWT obsoleto, chamada direta a RPC ou UI
  adulterada.
- Corrida ou replay em publicacao, correcao, heranca e importacao.
- Injecao por texto, JSON, XLSX, formula CSV, URL, MIME, nome/path e metadados.
- Vazamento por contagem, mensagem, diferenca indevida entre 403/404, exportacao,
  log, bundle ou segredo.

Os controles sao fail-closed, parametrizados, limitados e auditados. O frontend
usa somente chave publicavel. Nenhum payload infantil, JWT ou segredo entra em
logs, fixtures, screenshots ou build web.

## UX e componentes

O diretorio usa tabs `Modelos`, `Rotinas` e `Lancamentos`; busca/filtros ficam a
esquerda e Cards/Tabela/Arquivos a direita. Formulario usa `SuperadminFormFrame`,
rail 248 em 768/1024, maximo 880 e footer canonico. Editor, cards de secao/campo,
opcoes, valor tipado, ramificacoes, heranca e resumo ficam feature-local nesta
primeira entrega. Reordenacao por ponteiro tem equivalentes Mover para cima/baixo,
alvo minimo 48 px, foco, semantica e reduced motion.

Estados obrigatorios: loading, empty, no-results, failure, unauthorized, not-found
e conflict. Criacao permanece disponivel quando autorizada. Padroes Material
default, controles cinza reprovados, mobile em duas colunas, paginacao quebrada e
negativos grafite permanecem proibidos.

## Criterios de aceite e testes

- Producao/router nao contem fixtures, catalogos hard-coded, contagens inventadas
  ou fallback fake desta familia.
- Filtros, ordenacao e paginacao sao server-side e sem N+1.
- Tipos, limites, opcoes, arvore, respostas condicionais e hierarquia sao
  garantidos no banco, mesmo sem Flutter.
- Testes positivos e negativos cobrem CRUD/RLS, cross-scope, IDs trocados,
  membership revogada, chamada direta, ciclos/profundidade, concorrencia,
  idempotencia, import/export e ausencia de segredos.
- Widgets e goldens focados cobrem 375/768/1024/1440, light/dark, texto 200%,
  teclado, foco, alvo 48 e reduced motion.
