---
source: Owner screenshots; C0 remote OPTIONS read-only; source inspection
status: fixing
generated_at: 2026-09-13
---

# Chat — envio e mídia na conversa

apps/superadmin → Comunicação → Conversas → R08-G4 PNG privado QA → chat.attach.
Owner pediu foto inline e vídeo com play. Render atual só mostra metadados,
botão Abrir imagem e status incorreto Pronto para enviar em mensagem pronta.
Segundo anexo: PNG531KB selecionado normalmente; envio retorna erro genérico.
Não copiar nem reutilizar a foto pessoal como fixture.

C0 confirmou OPTIONS da Edge chat-media: origem127.0.0.1:3016 retorna403;
3014 e3000 retornam200 com allow-origin exata. 3015/3017 também403.
Runtime novo transferido para3000, já autorizado, sem ampliar CORS remoto.
O build é o mesmo release de filtros aprovado localmente (66s). A prova de
envio ainda precisa repetir na origem permitida; CORS não prova ausência
de outras falhas. Retry de prepare replayed pending está em investigação.

Owner autorizou máximo de auxiliares: /root/chat_inline e /root/chat_upload
confirmaram ACK e trabalham em arquivos separados. C0 mantém UI/deploy.
Nenhum novo certificado FE/BE/E2E. Gate: teste focal, merge real, build
conjunto e upload/leitura/reload pela rota normal com sintéticos existentes.
