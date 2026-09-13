---
source: Owner screenshot R10; coelo-ui administrative directory contract; C0 tests
status: runtime-filter-proof-passed
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
cinco consumidores: sem problemas. Build release qa_main.dart passou em66s.

O validador visual global retorna 16 ocorrências; execução de controle no
checkout R09 ff11b1798 retorna as mesmas 16. Nenhuma ocorrência nova no delta;
nenhuma allowlist ampliada. Resíduos: controles crus de Agenda, Chat,
Instituições, Principal e Alunos, mais três entradas de allowlist obsoletas.
Precisam de correção focal posterior; o check global não está verde.

Inspeção de outros SingleSelectField em activity_directory_page identificou
campos dentro de diálogos de criação, não filtros; não os convertemos em
cápsulas. Importações contém seletor de fixture do fluxo adiado, fora desta
correção. A busca não certifica a padronização de todos os controles do app.

Prova C0 na origem3000, sessão sintética normal: Home → Estrutura → Atividades.
Origem/Categorias em cápsulas, abertura/fechamento sem recorte em375/768/1024/1440;
screenshots filter-origin-*.png nesta pasta. Escolher Institucional reduziu
lista ao estado vazio; Limpar filtros restaurou modelos e rótulo Origem.
Escape fecha o flyout. Viewport restaurada após prova.
SHA código6377b961a; bundle SHA256
B81BC93620F2E83E73C4AE630907290C071D19B06294308918300F1C2EE6B152.
As outras quatro telas têm análise e teste compartilhado, ainda sem prova UI
específica nesta rodada. Dark coberto por widget, não por screenshot runtime.
Nenhuma alteração de SQL, autorização ou dado sintético. Sem novo action_id
certificado e sem incremento percentual. Gate de memória: regra visual já
existente; referência canônica da skill e índice do componente atualizados.
