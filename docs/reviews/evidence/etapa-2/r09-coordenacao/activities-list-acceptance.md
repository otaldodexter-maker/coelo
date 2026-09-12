---
source: C0 normal UI; productive activity v2 repository; SQL mirror
status: verified-read
generated_at: 2026-09-12
---

# Atividades: leitura produtiva por hierarquia

apps/superadmin -> Estrutura -> Atividades -> diretorio -> activities.list.
Na base9713bbdeb, C0 abriu o menu normal. Modelos vieram do catalogo;
aba Atividades mostrou Atividade R05 Estrutura (editada), R05 Sonda e
R06 Arroba. Filtro de instituicao mostrou tres instituicoes reais; Escola
R04 Estrutura restringiu unidades a Unidade Centro R04. Aplicados ambos,
os tres registros foram mantidos, com contagens de unidade/turma dos cards.
Reload completo e nova selecao da aba Atividades trouxeram os mesmos dados.
A aba/filtros voltam ao estado inicial; nao alegar persistencia dos filtros.
Nenhum CRUD de avaliacao, turma ou novo destinatario foi executado.

activities-consumer.json:5checksPASS. Anon401; Auth normal200; RPC v2 com
instituicao190dd028/unidadef5284f2f retornou total3 e IDs95b98978,
2e45c8bd e085da87e completos no manifest. Combinar a unidade com outra
instituicao retornou200/total0, sem vazamento; isso e negativa de hierarquia,
nao uma segunda sessao tenantB. Logout local204.

SQL local:28/28 superadmin_internal_activities_v2_read_test e97/97
directory_contract_test PASS, incluindo leitura de A por ator escopado,
tenantB indistinguivel de UUID aleatorio, capacidades por secao, pessoa de
outro app negada, allowlists/filtros/projecao segura.95corpos de funcoes
iguais entre producao/espelho. Escritas/atividade existentes R05/R06 e
provas FE anteriores reutilizadas; nao criados novos dados para uma leitura.
BE/E2E da lista aceitos; FE verified historico preservado. Sem novo SQL,
deploy, golden ou certificado de atividades.assessment/assessments.*.
Memoria: contrato de diretorio interno v2 existente, nenhuma regra nova.
