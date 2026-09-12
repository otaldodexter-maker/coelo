---
source: C0 autorizacao13h21; baseline get_profile_about21946; revisao G7; logs focais e codigo9863512b9
status: local-green-sem-ui-e2e
generated_at: 2026-09-12
---

# Perfil — leitura do Sobre e confirmação após reload

apps/superadmin → Coelo → Perfil → Editar/Sobre → principal.profile-edit,
com impacto na leitura compartilhada de principal.profile-view.
Código publicado: `9863512b9`, sobre a base C0 ciclo120 `7cc6d4e7b`.

Dois problemas reproduzidos:

1. Depois de save aceito, _load capturava falha/403 ou descartava resposta de
   contexto anterior; _save ainda chamava onSaved e mostrava “Sobre salvo.”.
2. A RPC get_profile_about devolve objeto plano com campos key e seções type.
   O parser procurava page e tratava uma página válida como ausência de conteúdo.

_load agora retorna se aceitou a consulta; _save confirma somente nesse caso.
O retry de leitura continua sem repetir o save. A nova geração ignora a conclusão
do contexto antigo. O parser usa exclusivamente o formato canônico plano,
normalizando key/type para o leitor de linhas existente. null real permanece
estado vazio; objeto sem versão falha como resposta inválida. Não há novo
wrapper ou fallback de envelope; o fallback histórico por RPC ausente permanece
inalterado e nenhuma negativa vira select direto.

## Verificação

Slot nominal C0 13h21–13h41, devolvido às13h24, concurrency1:

- RED: cinco casos novos executados, cinco falhas esperadas, native1,
  `profile-contract-red.jsonl`. O reporter classifica três asserts de widget
  como error e dois de parser como failure; não eram erros de compilação.
- GREEN: dois arquivos completos, **37 PASS / 0 FAIL / 0 SKIP**, native0,
  `profile-contract-green.jsonl` (done success=true).
- São cinco casos novos e32 existentes; dois casos antigos que modelavam o
  wrapper não canônico foram substituídos. Não somar RED/GREEN ou contar a
  alteração de oráculo como nova funcionalidade. O controle positivo existente
  também confere onSaved exatamente uma vez após sucesso.
- Análise dos dois arquivos de produto e dois de teste: **No issues found**,
  native0, `profile-contract-analyze.log`.
- diff --check aprovado; sem alteração de golden, dependência, SQL ou fixture.

Os arquivos executados foram principal_profile_edit_page_test.dart e
supabase_profile_about_repository_test.dart nos respectivos diretórios da
feature. A correção consumiu aproximadamente três minutos do slot; a estimativa
inicial incluía diagnóstico/adaptação que não foram necessários após o RED.

Leitura real separada: get_profile_about200/null nos três sujeitos QA nominais,
logout204, `profile-about-read-manifest.json`. Não prova resultado não vazio
em produção, save/reload pela UI ou negativa cross-tenant. A paridade não vazia
foi qualificada contra a baseline única confirmada por G7/C0. Nenhuma fixture
remota foi criada para completar artificialmente o aceite.

H02 (atualizar também cadastro oficial) continua decisão residual. O código
salva apenas o Sobre e não altera permissões, dados oficiais ou a experiência
visual aprovada. Memória: correção ao contrato existente; nenhuma nova decisão
durável ou projeção de conhecimento a criar.
