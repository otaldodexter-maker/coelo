---
source: "Solicitação e nove referências visuais aprovadas pelo Owner Coelo em 2026-09-01"
status: "approved"
generated_at: "2026-09-01"
---

# Finalização das telas de Comunicação do Superadmin

## Contrato

- Objetivo: concluir Conversas, Convites, Comunicações e Circulares no Superadmin, integradas ao Supabase quando o contrato de produção já existir.
- Incluído: correções funcionais, responsividade, diretórios, formulários, paginação, ações de arquivo, fixtures `/dev`, CRUD e RLS essenciais, revisão e rastreadores.
- Fora de escopo: implementar o processamento real de importação/exportação, alterar domínios não ligados a Comunicação e substituir provedores de mídia.
- Limite de aplicação: esta Etapa 2 altera somente `apps/superadmin` e os pacotes/backend indispensáveis ao Superadmin. `Coelo (Principal)` nomeia uma superfície dentro do menu do Superadmin; não autoriza alterações em `apps/principal`, `apps/admin` ou `apps/site`.
- Ordem: crashes; diretórios; formulários; fixtures; backend; verificação e documentação.
- Critério de parada: seis horas ou conclusão do recorte, o que ocorrer primeiro. Bloqueios remotos são registrados sem repetição indefinida.
- Evidências: testes focados, análise dos arquivos afetados, validador visual do Superadmin, inspeção em 375/768/1024/1440 e testes SQL relevantes quando o ambiente permitir.

## Direção visual

Instituições é a baseline obrigatória para toolbar, ações de arquivo, criação, tabela, cards e paginação. Criar/Editar Instituição é a baseline dos formulários e de seus rodapés. Comunicações segue a composição responsiva do anexo 6; Publicar/Editar Circular segue o compositor e a prévia do anexo 9 dentro do Superadmin, sem materializar nem importar UI de `apps/principal`.

Importar e exportar aparecem por `CoeloAdminFileActions`. Enquanto não houver processamento para o domínio, os itens ficam desabilitados e explicam `Disponível em breve`; nenhuma ação ativa simula sucesso. Diretórios com resultados apresentam paginação imediatamente depois da lista ou tabela, dentro do rodapé compartilhado, sem empurrá-la para o fim de uma área vazia.

## Comportamento por superfície

### Conversas

O carregamento diferencia indisponibilidade real, ausência de contexto autorizado e lista vazia. `/dev` usa conversas, participantes e mensagens coerentes. A tela mantém painel de conversas, thread e compositor conforme a baseline de chat do Superadmin.

### Convites

O detalhe ganha retorno contextual, resumo de identidade/status, ações agrupadas e seções de dados e linha do tempo em superfícies administrativas. Reenviar e revogar preservam os contratos atuais de autorização e auditoria.

### Comunicações

O breakpoint é decidido pela largura útil recebida pelo diretório. Mobile usa lista compacta; tablet e desktop usam tabela redimensionável; desktop largo pode mostrar prévia lateral. O tamanho da página e suas opções são calculados pela mesma largura, eliminando a combinação inválida `8` com opções compactas iniciadas em `11`. O formulário reutiliza navegação de etapas e rodapé canônicos.

### Circulares

O diretório usa toolbar, arquivos, tabs lineares, ação de criação, tabela redimensionável e paginação. O detalhe deixa de ser uma página vazia e passa a uma leitura administrativa com metadados, conteúdo, anexos, perguntas e ações. Publicar/Editar Circular usa editor responsivo com título, texto, mídia, perguntas, público/contexto, agendamento, rascunho/publicação e prévia no desktop.

## Dados e segurança

Fixtures `/dev` terão nomes, datas, quantidades e vínculos plausíveis entre instituições, unidades, grupos, autores, públicos, mensagens, convites, avisos e circulares. Em produção, IDs e filtros continuam não confiáveis: o cliente usa apenas repositories/RPCs autorizados; tabelas expostas permanecem deny-by-default; políticas conferem ator, tenant e escopo; comandos sensíveis preservam auditoria e idempotência.

O pedido de mapa aplica-se apenas a formulários deste recorte que possuam endereço ou coordenadas persistidas. Nenhum dos formulários de Comunicação atuais cadastra localização física, portanto este pacote não inventa um campo geográfico nem um mapa decorativo.
