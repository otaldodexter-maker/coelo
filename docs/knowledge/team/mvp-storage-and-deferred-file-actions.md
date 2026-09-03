---
title: "Storage e ações de arquivo no MVP"
knowledge_id: "mvp-storage-and-deferred-file-actions"
source: "AGENTS.md"
status: "validated"
generated_at: "2026-09-01"
updated_at: "2026-09-03"
audience: "team"
surfaces: [superadmin, principal-menu, supabase, storage, imports, exports, media]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Storage e ações de arquivo no MVP

Desde 2026-09-03, toda mídia privada nova do MVP usa Cloudflare R2 privado;
Supabase guarda metadados, permissões e auditoria. Não há dados para migrar.
Bucket público, segredo no cliente e URL permanente continuam proibidos.

Importação e exportação reais estão adiadas para depois do MVP. Nas telas
aplicáveis, os botões permanecem visíveis, acessíveis e responsivos, mas apenas
informam honestamente que a função estará disponível depois do MVP. Não existe
picker, parser, job, arquivo, download ou persistência Supabase nesse recorte.

A única exceção atual é Formulários: cada resposta individual possui
exportação real, sem configuração adicional ao criar o formulário. A ação usa
`forms.responses.export`, gera somente o envio escolhido em CSV/XLSX e inclui
ZIP quando houver mídia. O backend reautoriza ator, tenant, formulário,
resposta e capability; arquivos ficam privados, temporários e auditados.
Exportação consolidada e exportações de outros módulos continuam adiadas.

Artefatos legados já implantados antes da decisão ficam congelados e fora do
wiring do MVP. Eles não contam como funcionalidade aprovada nem como conclusão;
qualquer reconciliação do Supabase de produção deve ser forward-only,
coordenada e não destrutiva.

No encerramento formal do MVP, o Owner deve ser consultado separadamente sobre:

1. implementar importação e/ou exportação reais;
2. avaliar Stream/transformações após métricas reais do piloto.

Sem nova aprovação, nenhum dos dois temas entra automaticamente na etapa
seguinte.
