---
title: "E2E3 — segundo smoke local das superfícies originais"
source: "Navegação browser root em Flutter web-server local, AX e screenshots inspecionados"
status: "local fixture smoke; not E2E"
generated_at: "2026-09-08"
---

# Ambiente e limites

Servidor 127.0.0.1:58343, `COELO_APP_ENV=local`, sem URL/chave Supabase.
Build inicial `75783bb5`; hot restart concluído em `f353fee2` antes do Agora.
1280×720 escuro nos diretórios, 375×600 escuro nas prévias seguintes.
Fixtures `/dev`, sem autorização ou persistência produtiva comprovada.
Screenshots e AX foram inspecionados na ferramenta, não gravados como PNG.

# Resultados observados

- Avisos: edição fixture Festival Esportivo, cinco etapas do wizard. Na etapa
  público foi escolhida Infantil4 no rascunho local para continuar; Ver popup
  final abriu conteúdo, Escape fechou e devolveu foco ao botão de preview.
  Cancelar retornou ao diretório sem salvar/publicar.
- Convites: diretório com e-mails mascarados, detalhes dev-invite-12. Reenviar
  executou diretamente a operação **em memória**, sem diálogo de confirmação,
  e mostrou resultado simulado de emissão/entrega. Não é prova de e-mail real.
  O título usado pela ferramenta antes do clique dizia verificar confirmação;
  o efeito observado foi reenvio fixture, não mera abertura de confirmação.
  Resultado fechado. Nenhum serviço remoto configurado neste build.
- Circulares: diretório renderizado; Próxima página mudou 1 de2 para2 de2,
  trocou linhas e desabilitou avanço. Arquivos mostrou Importar/Exportar;
  menu fechado sem executar essas opções. Não prova indisponibilidade ao clique.
- Para Você: seletor aberto em375×600, última opção Lucas alcançada e escolhida;
  sheet fechou, resumo mudou para Contexto de Lucas Silva e foco retornou ao
  botão Lucas Silva. Não prova troca de autorização server-side.
- Perfil: aberto pelo cabeçalho de Para Você. Aba Circulares mostrou Contexto
  não autorizado sem conteúdo. Não promovida a consulta autorizada/E2E.
- Momentos: dock abriu prévia sobre Perfil; Comentar mostrou indisponibilidade
  explícita, retorno restaurou Perfil ainda na aba Circulares. Mais opções foi
  clicado, mas a captura posterior não reteve seu feedback transitório; não
  se infere sucesso/falha dessa ação. Mídia apresentada é asset da fixture.
- Agora: após hot restart, rota de prévia terminou automaticamente e retornou
  ao Acontece antes da inspeção. Não conta como prova visual do player/options.
  Pelo card Publicar agora abriu compositor; Texto e Cortar renderizaram em
 375×600, Concluir/Fechar visíveis, fechamento retornou foco ao tool de origem.
  A tentativa encadeada de fechar Texto/abrir Cortar durante transição reabriu
  Texto; repetição com AX estável abriu Cortar corretamente. Sem arquivo,
  mudança textual ou publicação; Cancelar retornou ao Acontece.

Consulta final dos últimos dez logs warn/error retornou cinco avisos de Flutter
sobre substituição do meta viewport e nenhum error. Viewport restaurada e aba
temporária fechada após a inspeção.

# O que não foi provado

Nenhum upload, R2, Stream, URL curta, autenticação real, tenant A/B, auditoria,
reload persistido, revogação de servidor ou entrega de e-mail foi testado.
Goldens e revisão nominal pendentes não são aprovados por este smoke.
Não houve mudança durável de produto para a memória de conhecimento.
