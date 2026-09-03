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

Todo recurso Supabase/Cloudflare remoto do Coelo é produção. R2 usa três
buckets privados: `coelo-media-prod` para mídia operacional,
`coelo-documents-prod` para documentos/evidências e
`coelo-transient-prod` para uploads pendentes, quarentena, processamento e
exportações temporárias. Há uma única hierarquia permanente por escopo,
domínio, entidade, finalidade, ativo e rendição; não existem raízes globais
`v1`/`v2`. Substituição cria novo ativo/objeto e o histórico fica no Postgres.
Há relatos conflitantes sobre a existência desses três buckets. E2E 3 confirma
a conta e o estado read-only, cria somente os ausentes no pacote autorizado ou
valida/configura os existentes; nunca recria, renomeia, esvazia ou remove.

Superadmin, Admin e Principal consomem o mesmo ativo e o mesmo contrato via
packages compartilhados; o app consumidor nunca entra na chave. Na Etapa 2,
somente Superadmin é conectado. O Site mantém assets estáticos no build/CDN e
não acessa mídia privada; publicação pública dinâmica futura terá fluxo e
bucket separados.

Perfil, capa, logo, mapa/foto de local, evento, comunicação, resposta de
formulário, cuidado e anexos usam a entidade/finalidade correspondente. PDF
fica no bucket de documentos e nunca no Stream. JPEG/PNG/WebP são formatos de
imagem finais; HEIC/HEIF só entra após conversão. MIME real, bytes,
dimensões/pixels, checksum e limites por finalidade da ADR 0032 são validados
no servidor. SVG de usuário e GIF animado ficam fora do MVP.

Importação e exportação reais estão adiadas para depois do MVP. Nas telas
aplicáveis, os botões permanecem visíveis, acessíveis e responsivos, mas apenas
informam honestamente que a função estará disponível depois do MVP. Não existe
picker, parser, job, arquivo, download ou persistência Supabase nesse recorte.

A única exceção atual é Formulários: o formulário possui exportação real em
Excel com suas respostas, sem configuração adicional. A ação usa
`forms.responses.export`; o backend reautoriza ator, tenant, formulário e
capability; o XLSX fica privado, temporário e auditado no R2. As mídias
originais seguem sua própria retenção. Exportação por resposta, CSV, ZIP, PDF e
exportações de outros módulos continuam adiadas.

Artefatos legados já implantados antes da decisão ficam congelados e fora do
wiring do MVP. Eles não contam como funcionalidade aprovada nem como conclusão;
qualquer reconciliação do Supabase de produção deve ser forward-only,
coordenada e não destrutiva.

No encerramento formal do MVP, o Owner deve ser consultado separadamente sobre:

1. implementar importação e/ou exportação reais;
2. revisar os limiares de Stream de Momentos/Acontece e transformações após
   métricas reais do piloto.

Sem nova aprovação, nenhum dos dois temas entra automaticamente na etapa
seguinte.
