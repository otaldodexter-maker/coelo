---
title: "Ajustes do formulário de instituição do Superadmin"
source: "Revisão de produto aprovada em 2026-07-28; docs/design/design-system.md; specs/012-superadmin-mvp.md"
status: "approved"
generated_at: "2026-07-28"
---

# Ajustes do formulário de instituição do Superadmin

## Objetivo

Refinar a criação e a edição de instituições no protótipo local do Superadmin,
adotando o popup de bug como referência de diálogo, reorganizando a identidade
visual e tornando explícitas as regras de representantes e administradores.

## Identidade visual

- A prévia compacta é o primeiro bloco da etapa, antes dos uploads e campos.
- A futura prévia expandida poderá abrir por hover ou clique e mostrar capa,
  foto, bio e demais dados; essa interação não faz parte desta entrega.
- As cores são agrupadas em `Cores de superfície` (principal e secundária),
  `Cores da marca` (principal, secundária e terciária) e `Cores de texto`
  (principal, secundária e terciária).
- Em desktop, as cores de marca e de texto usam três colunas; a grade colapsa
  responsivamente, preservando ordem, rótulo e foco.
- A bio aceita emojis, oferece uma paleta compacta e limita o conteúdo a 220
  grafemas, sem cortar sequências visuais no meio. Um ícone acessível abre a
  seleção; escolher emoji insere no cursor sem substituir o teclado nativo.

## Diálogos e seleções

- `CoeloAdminDialogShell` oficializa a composição administrativa baseada no
  popup de bug: superfície neutra, tint transparente, cabeçalho com divisor,
  fechar vermelho acessível, corpo rolável e rodapé persistente.
- Uma ação ocupa toda a largura útil. Quando existem duas ações, cada uma ocupa
  metade da largura, separada por `CoeloSpacing.space3`.
- Single-select acompanha a largura do gatilho, abre 4 px abaixo e mostra no
  máximo seis opções por vez. Quando faltar espaço inferior, reduz a altura e
  mantém busca fixa e opções roláveis.
- O ícone assimétrico de enviar convite usa caixa quadrada centralizada por
  token, sem deslocamento manual.

## Pessoas e regras locais

- Criação e edição exigem ao menos um representante legal e um administrador.
  O último registro de cada papel não pode ser removido; outra pessoa deve ser
  adicionada antes.
- Nome, sobrenome e nome de exibição são obrigatórios. E-mail, telefone e CPF
  são opcionais no cadastro inicial; valores presentes são validados.
- O CPF continua obrigatório antes da ativação real de um adulto no produto.
  `Marcar como aceito` no protótipo é apenas simulação local e não representa
  ativação de identidade.
- Administradores recebem `@` automático, estável e único no repositório local.
  A fonte definitiva de unicidade global continuará sendo o domínio de
  identidade.
- O avatar opcional já está disponível no cadastro e na edição de administrador.
  Ele usa o recorte circular padrão de perfil, com `Cancelar` e `Aplicar` em
  50/50; o reset é um botão circular por ícone com tooltip, semântica e alvo
  mínimo.
- Converter representante em administrador cria um perfil contextual
  independente ligado à mesma pessoa lógica. Os dados começam iguais e só
  voltam a coincidir por sincronização explícita em uma das duas direções.
- A sincronização copia nome, sobrenome, nome de exibição, e-mail, telefone e
  CPF; preserva `@`, foto, nível administrativo e estado do convite.
- Remover um papel não remove o outro; apenas encerra o vínculo local de
  sincronização.
- Os rótulos de sincronização são direcionais: `Copiar dados do representante`
  leva representante → administrador e `Copiar dados para o representante` leva
  administrador → representante.
- Administrador pode receber foto local opcional.
- Enviar convite sem e-mail abre o editor focado no e-mail. Salvar um e-mail
  válido envia o convite localmente; cancelar não altera o estado.

## Escopo e segurança

Esta entrega não cria migration, RLS, API, envio real de convite ou
persistência de mídia. Não duplica a pessoa global no modelo futuro: papéis e
perfis contextuais permanecem separados, mas ligados à mesma identidade.
Fixtures, documentação, goldens e memória de conhecimento não incluem PII real.

## Aceite

- Os diálogos afetados usam o shell compartilhado e ações 100% ou 50/50.
- A prévia antecede os uploads e os três grupos de cor aparecem na ordem
  aprovada.
- Menus longos permanecem abaixo do campo, limitados e roláveis.
- O limite da bio respeita grafemas e a paleta insere no cursor.
- Representantes e administradores preservam mínimo de um, independência,
  sincronização explícita e handles locais estáveis.
- A matriz 375/768/1024/1440, light/dark e texto a 200% não apresenta overflow.
