---
source: apontamento e dois anexos do Owner durante preparação R11; docs/design/design-system.md
status: ajustes parcialmente implementados; aceite integral pendente
generated_at: 2026-09-13
---

# Meu perfil — identidade, ações e Meu acesso

Família visual administrativa, apps/superadmin > Meu perfil, action_id
account.profile. Incluído na R11 junto de Auth; preservar o limite total de cota.

O primeiro anexo mostra foto no editor e sigla no cabeçalho; o Owner também
suspeita do nome. Não foi confirmado no apontamento se Salvar já havia sido
acionado. Reproduzir seleção, sucesso de persistência e reload separadamente.
O segundo mostra Salvar alterações apenas depois da longa lista de permissões.

Aceites solicitados:
- Após salvar com sucesso, nome/foto do cabeçalho acompanham a identidade real
  da conta; remover foto volta à sigla correta. Navegação/reload mantêm o estado.
- Cabeçalho não conserva identidade de outra sessão, nem dados fixos de fixture.
- Salvar/Cancelar ficam acessíveis no rodapé padrão do contêiner, sem depender
  de percorrer toda a lista de permissões; teclado/viewport não encobrem ações.
- Meu acesso tem altura limitada e rolagem própria, busca interna e agrupamento
  legível por módulo e hierarquia/escopo realmente disponíveis no contrato.
- Continua somente leitura; informar acesso e funções adiadas com honestidade,
  sem transformar capacidade em promessa de importação/exportação operacional.
- Provar desktop/mobile, teclado, texto ampliado, estados vazios da busca e
  ausência de scroll preso; não criar um design de formulário novo.

Responsável C0 na R11. Primeiro gate: comparar conta persistida, estado do
controller e projeção do cabeçalho após Salvar; corrigir no componente/contrato
causal. Backend: ownership, R2 privado para foto, atualização/remoção e leitura
autorizadas; nenhum aceite novo até a prova. A suspeita de nome não é falha
confirmada ainda. Não confundir esta tela com principal.profile-edit/Sobre.

Os originais permanecem anexados à conversa; nenhum caminho de cópia binária
foi exposto. Registro textual sem nomes, e-mails ou conteúdo pessoal das imagens.

## Complemento Owner — cor da sigla

O Owner também informou que a cor escolhida do avatar sem foto não muda no cabeçalho. Reproduzir após salvar; validar sigla e cor persistidas no editor, header e navegação/reload. Remover foto deve recuperar a sigla/cor corretas da mesma conta, sem cor fixa ou estado de outra sessão. Preservar contraste e o fallback aprovado.

## Limite de confirmação e estado da R11

O cabeçalho consome a identidade confirmada pelo backend. A prévia local não
substitui a resposta persistida: se o servidor não confirmar algum campo, a UI
expõe essa ausência de confirmação e preserva o rascunho para revisão/cancelamento.
O agrupamento de Meu acesso usa metadados reais de módulo e escopo; contratos
antigos sem esses metadados mantêm a lista pesquisável, sem hierarquia inventada.

Na R11, rodapé/busca, confirmação do perfil, contraste e propagação da cor no
Principal hospedado têm código e provas focais. A suspeita do nome não se
reproduziu no save/reload real. Sigla/cor e metadados possuem candidato SQL local;
foto R2 ainda não possui transporte persistente. O estado por camada e os gates
remotos estão em `docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md`.
Este registro não converte render automatizado em aprovação visual A nem
certifica a ação inteira.
