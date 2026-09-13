---
source: Owner screenshot R10; coelo-ui administrative directory contract; C0 tests
status: local-green-awaiting-runtime
generated_at: 2026-09-13
---

# Filtros administrativos — correção do apontamento do Owner

apps/superadmin → Estrutura → Atividades → Modelos → Origem;
mesma causa em Comunicação → Circulares/Comunicações, Operação → Cardápios
e Governança → Auditoria. IDs: activities.list, circulars.filter,
notices.list, meal-plans.list e audit.filter. Não são novos IDs nem aceites.

O filtro Origem utilizava InputDecorator de formulário com label flutuante,
ícone e raio de campo. Categorias usa o gatilho em cápsula do diretório.
Foi extraído o mesmo gatilho interno para single/multi-select; os oito
filtros de escolha única encontrados nessas cinco superfícies usam a variante
de filtro. Escolha única continua imediata, sem checkbox/Aplicar; formulários
preservam seu campo. O valor neutro mostra o nome do filtro.

Teste antes: 2 FAIL (light/dark), encontrou InputDecorator indevido.
Depois: 15 PASS/0 FAIL nas suítes single-select field/filter e multi-select
filter, incluindo seleção, Escape, foco e estilos. Analyze dos componentes e
cinco consumidores: sem problemas. Build/runtime ainda pendentes neste checkpoint.

O validador visual global retorna 16 ocorrências; execução de controle no
checkout R09 ff11b1798 retorna as mesmas 16. Nenhuma ocorrência nova no delta;
nenhuma allowlist ampliada. Resíduos: controles crus de Agenda, Chat,
Instituições, Principal e Alunos, mais três entradas de allowlist obsoletas.
Precisam de correção focal posterior; o check global não está verde.

Inspeção de outros SingleSelectField em activity_directory_page identificou
campos dentro de diálogos de criação, não filtros; não os convertemos em
cápsulas. Importações contém seletor de fixture do fluxo adiado, fora desta
correção. A busca não certifica a padronização de todos os controles do app.

Primeiro gate: atualizar build servido após terminar a inspeção UI, abrir
Origem/Categorias, escolher origem e conferir filtro/reset em 375/768/1024/1440.
Responsável C0. Nenhuma alteração de SQL, autorização ou dado sintético.
