---
source: apontamento e sete anexos do Owner na preparação R11; ADR0032; docs/design/design-system.md
status: direção de ajuste registrada para Etapa 2; implementação e render pendentes
generated_at: 2026-09-13
---

# Chat — referência de mídia e campo de escrita

Recorte: apps/superadmin > conversas/chat, incluindo acesso pelo launcher do
Coelo (Principal). Ações-pai: chat.open, chat.attach, chat.send. Não criar IDs
novos ou alterar percentuais por este registro. Prioridade: backlog da Etapa 2;
fora do caminho crítico R11 de Estrutura e recuperação de senha.

## Direção expressa pelo Owner

O Owner pediu mais acabamento na apresentação de fotos/vídeos e nos campos
de escrita, atualmente percebidos como retos demais. Os sete anexos desta
mensagem são referências de composição de conversa, não aprovação da marca,
cores, conteúdos pessoais ou de todas as funcionalidades do aplicativo mostrado.

| Referência na mensagem | Ponto visual a conservar como direção |
|---|---|
| 1 — foto e teclado | Foto ocupa o corpo da mensagem; campo de escrita branco em cápsula, ações alinhadas e área de teclado respeitada. |
| 2 — campo e painel de emoji | Compositor mantém alinhamento, altura e bordas arredondadas ao trocar o modo de entrada. |
| 3 — vídeo e balões | Prévia visual com play central/duração; mensagens com cantos mais suaves, remetente e horário legíveis. |
| 4 — duas coleções | Múltiplas fotos organizadas em mosaico coeso, separações finas e contador de itens adicionais. |
| 5 — coleção e vídeo | Mesma linguagem entre mosaico e prévia de vídeo; compositor separado sem encobrir a conversa. |
| 6 — continuidade de coleções | Alinhamento constante, remetente/horário integrados e navegação pela conversa. |
| 7 — vídeo e campo | Vídeo reconhecível antes do play; campo em cápsula e ações com área de toque adequada. |

Fotos devem aparecer inline e abrir viewer; vídeo deve ter prévia/play e
controles funcionais. Imagens preservam proporção, mosaicos abrem os itens
reais, e agrupamento não pode fabricar um álbum apenas pela proximidade de
horário se o contrato não registrar o envio conjunto. Ao implementar, conferir
modelo de mensagens/anexos antes de escolher a menor alteração de contrato.

Preservar Nunito Sans, tokens, laranja Coelo, tema claro/escuro, estados de
carregamento/erro/retry e acessibilidade. Sem hover cinza reprovado. Texto cresce
até limite de altura apropriado, mantém cursor/seleção e continua visível com
teclado aberto. Não aplicar arredondamento global aos formulários administrativos.
As referências não adicionam chamadas, stickers, encaminhamento ou gravação
de áudio ao escopo por simples presença nos anexos.

Mídia continua no R2 privado, com metadados/permissões no Supabase,
reautorização, ownership e tenant; Chat não exige Stream no MVP.

## Preservação e próximo gate

Os originais estão anexados à conversa. Nenhum caminho local dos binários foi
exposto à preparação; este registro preserva a interpretação visual e a ordem,
não afirma ter copiado as imagens. Não copiar nomes, mensagens ou fotografias
pessoais para conhecimento, fixtures ou dados de produção. Para retomada visual,
usar os anexos originais quando acessíveis; se indisponíveis, manter o limite
explícito e usar esta direção com fixtures sintéticas, sem inventar baseline A.

Responsável: C0/FE na rodada designada da Etapa 2. Primeiro gate: comparar o
chat produtivo nos estados foto única, vídeo parado/em reprodução, múltiplas
mídias e compositor com teclado/texto multilinha; desenhar o delta conforme
coelo-ui e obter aceite visual do render. Testar envio/leitura/reload e RLS,
sem refazer as correções R10 já válidas. Nenhum aceite FE/BE/E2E novo aqui.

Destino operacional após decisão do Owner em13/09/2026: R12, conforme `docs/reviews/etapa-2-operacao/next-round/R12-pendencias-herdadas-R11.md` (Conta R12-46; compositor R12-52, coordenado com R12-43). Direção e aceites preservados; transferência não certifica implementação.
