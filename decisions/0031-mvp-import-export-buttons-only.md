---
title: "Importação e exportação como controles visuais no MVP"
source: "decisão explícita do Owner Coelo em 2026-09-01; rastreadores da Etapa 2"
status: "approved"
generated_at: "2026-09-01"
---

# ADR 0031 — Importação e exportação como controles visuais no MVP

## Decisão

Como regra geral, importação e exportação reais não fazem parte do backend
Supabase, da integração ou do E2E do MVP atual. Os botões permanecem visíveis
nas telas aplicáveis para preservar a composição e a descoberta do produto.

**Exceção aprovada pelo Owner em 2026-09-01:** cada resposta individual de um
Formulário deve possuir exportação real no MVP. A capacidade nasce com o
formulário, sem configuração adicional, e usa `forms.responses.export`. O
arquivo contém somente a resposta selecionada, preserva a versão e a ordem das
perguntas e reutiliza os formatos canônicos CSV/XLSX; ZIP é aplicável quando a
resposta possuir mídia. Download e mídia permanecem privados, reautorizados no
servidor, temporários e auditados. Exportação consolidada de várias respostas
e exportações dos demais domínios continuam `deferred-post-mvp`.

Ao serem acionados, os controles devem responder de forma honesta que a função
estará disponível depois do MVP. Eles não podem abrir picker, gerar arquivo,
fingir sucesso, chamar RPC/Edge Function, criar job ou persistir dados.

No Flutter, cada botão ainda precisa cumprir os gates da camada cliente:
posição correta, acessibilidade, foco, responsividade e mensagem coerente. No
Supabase e no rastreador integrado, as ações reais ficam
`deferred-post-mvp` e não bloqueiam a conclusão do MVP, exceto
`forms.export`, que exige backend, segurança, arquivo real e E2E completos.

Artefatos de banco, migrations, funções ou código implantados antes desta
decisão não transformam import/export em funcionalidade do MVP. Eles devem ser
congelados, inventariados e mantidos fora do wiring da UI. Qualquer desativação
ou correção no Supabase de produção será forward-only, coordenada e não
destrutiva; esta ADR não autoriza rollback, drop ou exclusão automática.

## Evolução depois do MVP

No gate formal de encerramento do MVP, o Coordenador deve perguntar ao Owner se
deseja implementar importação e/ou exportação reais. Somente uma resposta
afirmativa autoriza nova spec para formatos, colunas, capabilities, jobs,
arquivos privados, expiração, auditoria e isolamento entre tenants.

## Supersessão

Esta decisão prevalece sobre specs, ADRs, planos e rastreadores anteriores que
tratavam parser, upload, download, jobs ou exportação real como requisito do
MVP, preservada somente a exceção de exportação individual de resposta de
Formulário descrita acima.
