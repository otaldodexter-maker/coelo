---
source: Owner, solicitações e anexos de 13/09/2026 após consolidação R10
status: accepted
generated_at: 2026-09-13
---

# ADR0037 — Contêiner, contexto e mídia do Principal hospedado

Decisão do Owner: Acontece, Agora, Momentos, Para Você, Perfil e subtelas permanecem no contêiner principal ao lado do shell. Preservar a família visual Principal e o cabeçalho. Usar um único launcher padrão de conversas: pílula desktop e círculo mobile, acima do dock quando existir, sem sobreposição; continua ausente em publicar/editar e viewers conforme ADR0034.

Ver como fica como opção no avatar superior direito. O seletor usa superfície branca no tema claro, sem fundo laranja e sem hover cinza; suporta múltiplas seleções para leitura, com Aplicar/Cancelar. Publicar/editar exige contexto singular explícito e autorização server-side; seleção múltipla não amplia direitos nem significa publicar em todos silenciosamente.

O feed Acontece mantém publicações acessíveis depois de vistas. Novidade não filtra todo o histórico. Remoção, expiração própria da entidade e perda de autorização continuam respeitadas. Agora e Acontece usam a mesma hierarquia tipográfica de seção.

Adicionar mídia nos publicadores usa o mesmo card de criação de Instituições: componente neutro compartilhado, contorno tracejado, ícone circular, tokens e foco/hover aprovados. Miniaturas têm geometria uniforme; fotos/vídeos preservam proporção. Não duplicar o componente nem importar pacote administrativo no Principal.

Status desta ADR é aprovação de comportamento, não certificado de implementação. Avanços e lacunas por ação ficam nos três rastreadores e Principal-pos-R10.md; R10 permanece encerrada, sem iniciar Etapa3.
