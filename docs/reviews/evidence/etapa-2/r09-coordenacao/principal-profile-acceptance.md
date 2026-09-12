---
source: C0 normal UI; list_my_principal_contexts; current SQL mirror
status: verified-read
generated_at: 2026-09-12
---

# Perfil: leitura institucional e retorno ao shell

apps/superadmin -> Coelo (Principal) -> Perfil -> contexto/leitura ->
principal.profile-view. Base executada9713bbdeb, Chrome22592, release3014,
Supabase real evvbomzejfijozbtgvpt. C0 abriu o menu normal (scroll suportado)
e Perfil mostrou QA R04 Cuidado (sintetico), @qa-r04-cuidado-sintetico.
Seletor Ver como ofereceu os dois contextos efetivamente autorizados;
QA R04 Instituicao Sintetica mudou cabecalho, @qa-r04-chat e Contexto atual
sem manter o sujeito anterior. Sobre mostrou estado vazio honesto nos dois.
Reload completo preservou a sessao e releu o Perfil; a selecao voltou ao
primeiro contexto. Nao alegar persistencia da selecao. Reabrir o segundo
contexto funcionou; Home devolveu o shell administrativo pela navegacao normal.

principal-profile-consumer.json:7PASS, anon401, Auth normal200, os mesmos
dois contextos e handles, get_profile_about200/null em ambos, releitura
identica e logout local204. Nenhuma sessao foi injetada. As instituicoes
d0c40000-0000-4000-8000-000000000001 e9f040000-0000-4000-8000-000000000010
sao retidas de rodadas anteriores. Nenhuma nova fixture ou escrita remota.

49pgTAP PASS/0FAIL: principal_runtime_contexts13, internal_actor_bridge22,
context_handles_and_coelo_profile14. Cobrem identidade derivada do JWT,
hierarquia, membership inativo excluido, A nao enumera B e B nao enumera A,
precedencia people-based, ponte interna P35 e anon negado.14corpos de funcoes
iguais no espelho e producao (resolver/atores/Sobre); manifests de paridade.
As negativas multi-tenant sao SQL local com corpos produtivos equivalentes,
nao duas sessoes reais de tenants diferentes nesta navegacao.

FE verified historico preservado; BE done e E2E aceitos para leitura.
Nao certifica principal.profile-edit, foto, capa, follow, dados oficiais,
conteudo Sobre nao vazio ou selo visual. Placeholders de midia e ajustes
visuais aprovados anteriormente continuam fora deste gate. Avatar OC do
shell segue pendencia posterior do Owner. Nenhuma nova migration/deploy.
R08 parser/sujeito/reload43PASS reutilizados, nao reexecutados nem somados.
Memoria: cumprimento do contrato existente; nenhuma nova regra duravel.
