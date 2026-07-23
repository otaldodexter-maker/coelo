---
title: "Proximos Passos Superadmin"
source: "conversa com usuario em 2026-07-20; specs/013-ui-packages-componentization.md; apps/superadmin/lib/app/shell/superadmin_shell.dart"
status: "draft-for-next-session"
generated_at: "2026-07-20"
---

# Proximos Passos Superadmin

## Decisao De Sequencia

Fazer UX/UI e Supabase juntos, em fatias pequenas. Primeiro validar a
experiencia com repository fake quando fizer sentido; depois conectar Supabase,
RLS, auditoria e testes da mesma fatia.

## Ordem Recomendada

1. Corrigir o popup do perfil no tablet/mobile.
   - O menu de Perfil, Configuracoes e Sair esta muito encostado/colado no
     canto direito em telas compactas.
   - Como o shell e compartilhado, corrigir isso antes de criar novas telas.

2. Fechar o fluxo real de Auth.
   - Login funcionando com Supabase.
   - Esqueci minha senha funcionando.
   - Redefinir/mudar senha funcionando.
   - Logout integrado ao fluxo real.

3. Completar Instituicoes.
   - Criar instituicao com UX/UI real.
   - Editar instituicao.
   - Excluir, arquivar ou desativar instituicao com confirmacao adequada.
   - Definir loading, erro, vazio, sucesso e sem permissao.
   - Conectar Supabase apenas depois do fluxo de tela estar claro.

4. Componentizar quando houver repeticao real.
   - Promover para `coelo_ui_admin` somente componentes usados por mais de uma
     tela administrativa.
   - Candidatos provaveis: toolbar, filtros, menu multiselect, tabela, chip de
     status, paginacao, dialog de confirmacao e feedback.

5. Implementar Unidades.
   - Criar, editar e excluir/desativar unidade.
   - Vincular unidade a instituicao.
   - Reusar componentes administrativos ja validados.

6. Implementar Grupos/Turmas.
   - Criar, editar e excluir/desativar turma.
   - Vincular turma a unidade e instituicao.
   - Validar estados e permissoes por tenant/instituicao.

7. Implementar Atividades contextuais.
   - Criar atividade com nome e descricao livres.
   - Permitir criacao pela instituicao e por unidade com capacidade explicita habilitada no perfil.
   - Na criacao pela unidade, herdar a instituicao-mae, vincular automaticamente a unidade de origem e preservar autoridade de ajuste da instituicao.
   - Vincular a atividade a uma ou mais turmas da mesma instituicao.
   - Definir professor(es) e permissoes por turma antes da tela final.
   - Comecar pelo Supabase, depois menu e, por fim, tela.

## Regra De Trabalho

Cada entrega deve nascer de spec pequena, com escopo, dados, permissoes,
estados de UX, criterios de aceite e testes. Evitar componentes especulativos:
comecar local e promover apenas quando houver segundo uso concreto.
