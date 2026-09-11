# Gera os artboards .dc.html das telas de publicacao (mobile 375 e desktop 1440) com os tokens do coelo_tokens.
import json, os
OUT = os.path.dirname(os.path.abspath(__file__))

# tokens (packages/coelo_tokens): orange500 D63C00, orange50 FFF3EE, neutral700 3F4549, neutral200 DDE0E2, neutral100 EEF0F1, neutral500 737B80, peach50 FFF8F5, forest500 2D8A4E; radius sm 8 md 12 lg 16; space 4/8/12/16/24
HEAD = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Nunito+Sans:wght@400;600;700;800&display=swap">
  <style>
    body{margin:0;font-family:"Nunito Sans","Segoe UI",system-ui,sans-serif;color:#3F4549;background:#FFFFFF;-webkit-font-smoothing:antialiased}
    a{color:#D63C00}a:hover{color:#B83300}
    .card{border:1px solid #DDE0E2;border-radius:12px;background:#FFFFFF}
    .lbl{font-size:13px;font-weight:700;color:#3F4549}
    .muted{color:#737B80;font-size:12px}
    .chip{display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 12px;border-radius:999px;border:1px solid #DDE0E2;font-size:12px;font-weight:600;color:#3F4549;background:#FFFFFF}
    .chip.on{border-color:#D63C00;color:#D63C00;background:#FFF3EE}
    .btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;height:48px;padding:0 20px;border-radius:12px;font-size:14px;font-weight:700;border:1px solid transparent;box-sizing:border-box}
    .btn.primary{background:#D63C00;color:#FFFFFF}
    .btn.secondary{background:#FFFFFF;color:#3F4549;border-color:#DDE0E2}
    .tool{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:11px;font-weight:600;color:#3F4549}
    .tool .ic{width:44px;height:44px;border-radius:999px;border:1px solid #DDE0E2;display:flex;align-items:center;justify-content:center;background:#FFFFFF}
    .media{border-radius:16px;position:relative;overflow:hidden;background:#F7F8F8}
    .media img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;display:block}
    .media .tag{position:absolute;left:12px;top:12px;background:rgba(28,32,34,.72);color:#fff;font-size:11px;font-weight:700;padding:4px 8px;border-radius:999px}
    .thumb{width:48px;height:48px;border-radius:8px;background:#F7F8F8;position:relative;flex:0 0 auto;overflow:hidden}
    .thumb img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
    .thumb.on{outline:2px solid #D63C00;outline-offset:1px}
    .thumb span{position:absolute;left:4px;bottom:4px;color:#fff;font-size:10px;font-weight:700}
    .thumb.add{background:#FFFFFF;border:1px dashed #C4C9CC;display:flex;align-items:center;justify-content:center;color:#737B80;font-size:20px;font-weight:600}
    .field{border:1px solid #DDE0E2;border-radius:12px;padding:12px;font-size:14px;color:#9DA4A8;min-height:72px;display:flex;flex-direction:column;justify-content:space-between}
    .field .ct{align-self:flex-end;font-size:11px;color:#737B80}
    .row{display:flex;align-items:center;gap:12px}
    .toggle{width:40px;height:22px;border-radius:999px;background:#DDE0E2;position:relative;flex:0 0 auto}
    .toggle::after{content:"";position:absolute;left:3px;top:3px;width:16px;height:16px;border-radius:999px;background:#fff}
    .note{background:#FFF3EE;border-radius:12px;padding:12px;font-size:12px;color:#3F4549;display:flex;gap:8px;align-items:flex-start}
    .avatar{width:32px;height:32px;border-radius:999px;background:#FFC2AD;flex:0 0 auto}
    .avatar.brand{background:#D63C00;color:#fff;font-weight:800;font-size:12px;display:flex;align-items:center;justify-content:center}
    .logo{font-weight:800;color:#D63C00;font-size:22px;letter-spacing:-.02em}
    .nav a{text-decoration:none;color:#3F4549;font-size:14px;font-weight:600;padding:8px 4px;border-bottom:2px solid transparent}
    .nav a.on{color:#D63C00;border-bottom-color:#D63C00}
    .side a{display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:10px;text-decoration:none;color:#3F4549;font-size:14px;font-weight:600}
    .side a.on{background:#FFF3EE;color:#D63C00}
    .list-row{display:flex;align-items:center;gap:12px;padding:10px 12px;border-bottom:1px solid #EEF0F1}
    .seg{display:flex;border:1px solid #DDE0E2;border-radius:999px;overflow:hidden}
    .seg span{padding:6px 10px;font-size:11px;font-weight:700;color:#737B80}
    .seg span.p{background:#F0F9F3;color:#2D8A4E}.seg span.f{background:#FFF3EE;color:#D63C00}.seg span.a{background:#FFF8F5;color:#8A5B00}
    .step{height:3px;border-radius:2px;background:#EEF0F1;flex:1}
    .step.on{background:#D63C00}
  </style>
</helmet>
"""
TAIL = "</x-dc>\n</body>\n</html>\n"

def ic(name, size=20, color="#3F4549"):
    p = {
     "x": '<path d="M6 6l12 12M18 6L6 18"/>',
     "help": '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .9-1 1.7M12 17h.01"/>',
     "text": '<path d="M4 7h16M12 7v13M8 20h8"/>',
     "music": '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
     "crop": '<path d="M7 3v14a1 1 0 0 0 1 1h13M3 8h14a1 1 0 0 1 1 1v12"/>',
     "cover": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 17l-5-5-8 8"/>',
     "chev": '<path d="M9 6l6 6-6 6"/>',
     "down": '<path d="M6 9l6 6 6-6"/>',
     "users": '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4a3.5 3.5 0 0 1 0 7M21.5 20a6.5 6.5 0 0 0-5-6.3"/>',
     "cal": '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
     "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
     "save": '<path d="M6 3h9l4 4v14H6z"/><path d="M8 3v6h7"/>',
     "send": '<path d="M21 3L10 14M21 3l-7 18-4-7-7-4z"/>',
     "bell": '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 21h4"/>',
     "bug": '<path d="M8 2l1.5 2M16 2l-1.5 2M9 7h6a3 3 0 0 1 3 3v5a6 6 0 0 1-12 0v-5a3 3 0 0 1 3-3zM3 12h3M18 12h3M4 19l3-2M20 19l-3-2M4 6l3 2M20 6l-3 2M12 10v10"/>',
     "bank": '<path d="M3 10l9-6 9 6M5 10v9M9 10v9M15 10v9M19 10v9M3 19h18"/>',
     "shield": '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
     "grid": '<rect x="4" y="4" width="4" height="4"/><rect x="10" y="4" width="4" height="4"/><rect x="16" y="4" width="4" height="4"/><rect x="4" y="10" width="4" height="4"/><rect x="10" y="10" width="4" height="4"/><rect x="16" y="10" width="4" height="4"/><rect x="4" y="16" width="4" height="4"/><rect x="10" y="16" width="4" height="4"/><rect x="16" y="16" width="4" height="4"/>',
     "layers": '<path d="M12 4l9 5-9 5-9-5zM3 14l9 5 9-5"/>',
     "up": '<path d="M6 15l6-6 6 6"/>',
     "filter": '<path d="M4 5h16l-6 7v6l-4-2v-4z"/>',
     "video": '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/>',
     "story": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/>',
     "user": '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
     "home": '<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
     "back": '<path d="M15 6l-6 6 6 6"/>',
     "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
     "clip": '<path d="M21 12l-8.5 8.5a5 5 0 0 1-7-7L14 5a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L15 8"/>',
     "pin": '<path d="M12 21s7-6.5 7-11.5a7 7 0 0 0-14 0C5 14.5 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
     "check": '<path d="M5 12l4 4L19 7"/>',
     "heart": '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/>',
     "comment": '<path d="M4 5h16v11H9l-5 4z"/>',
     "book": '<path d="M5 4h6a2 2 0 0 1 2 2v14a2 2 0 0 0-2-2H5zM19 4h-6a2 2 0 0 0-2 2v14a2 2 0 0 1 2-2h6z"/>',
     "emoji": '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M9 10h.01M15 10h.01"/>',
    }[name]
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{p}</svg>'

def rabbit(size=36):
    return f'''<div style="width:{size}px;height:{size}px;border-radius:999px;background:#D63C00;display:flex;align-items:center;justify-content:center;flex:0 0 auto"><svg width="{int(size*0.6)}" height="{int(size*0.6)}" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M7.5 3.5c1.6 0 2.6 2.4 2.9 5.2h3.2c.3-2.8 1.3-5.2 2.9-5.2 1.9 0 2.3 3.6 1.4 6.4-.4 1.2-1 2-1.7 2.5 1.5 1 2.3 2.6 2.3 4.1 0 2.9-3 4.5-6.5 4.5S5.5 19.4 5.5 16.5c0-1.5.8-3.1 2.3-4.1-.7-.5-1.3-1.3-1.7-2.5-.9-2.8-.5-6.4 1.4-6.4z"/><circle cx="9.6" cy="15" r="1" fill="#D63C00"/><circle cx="14.4" cy="15" r="1" fill="#D63C00"/></svg></div>'''

def shell_header(width, initials="AC", badge=True):
    f = "header-1440.jpg" if width > 600 else "header-375.jpg"
    return f'<img src="{f}" style="display:block;width:{width}px;height:64px">'

def tool(name, label):
    return f'<div class="tool"><div class="ic">{ic(name,22)}</div><span>{label}</span></div>'

def chips(items, on=0):
    return '<div class="row" style="flex-wrap:wrap;gap:8px">' + "".join(f'<span class="chip{" on" if i==on else ""}">{ic("users",14,"#D63C00" if i==on else "#3F4549")}{t}</span>' for i,t in enumerate(items)) + '</div>'

def publico(lines, compact=False):
    l = "".join(f'<div style="font-size:13px;color:#3F4549">{x}</div>' for x in lines)
    return f'''<div class="card" style="padding:12px;display:flex;align-items:center;gap:12px">{ic("users",20,"#D63C00")}<div style="flex:1;display:flex;flex-direction:column;gap:2px"><div class="lbl">Público e contexto</div>{l}</div>{ic("chev",18,"#737B80")}</div>'''

def agendar(label="Agendar publicação", value=None):
    right = f'<span style="font-size:13px;font-weight:700;color:#D63C00">{value}</span>{ic("down",16,"#737B80")}' if value else '<div class="toggle"></div>'
    return f'<div class="card" style="padding:12px 14px;display:flex;align-items:center;gap:12px">{ic("cal",20,"#3F4549")}<div class="lbl" style="flex:1">{label}</div>{right}</div>'

def opcoes(label="Salvar como rascunho"):
    return f'<div style="display:flex;flex-direction:column;gap:8px"><div class="lbl">Opções</div><div class="row" style="justify-content:space-between">{ic("save",18)}<span style="flex:1;font-size:13px">{label}</span><div class="toggle"></div></div></div>'

def field(placeholder, count):
    return f'<div class="field"><span>{placeholder}</span><span class="ct">{count}</span></div>'

def thumbs(n=4, durations=("0:15","0:08","0:12","0:10"), sel=None):
    fotos=["foto-2.jpg","foto-3.jpg","foto-vertical.jpg","foto-paisagem.jpg"]
    t = "".join(f'<div class="thumb{" on" if sel==i else ""}"><img src="{fotos[i%4]}"><span>{durations[i%len(durations)]}</span></div>' for i in range(n))
    return f'<div class="row" style="gap:8px;overflow:hidden"><div class="thumb add">+</div>{t}</div>'

def footer(primary, secondary="Salvar rascunho", stacked=True, icon_primary="send"):
    p = f'<div class="btn primary" style="width:100%">{primary}</div>'
    s = f'<div class="btn secondary" style="width:100%">{secondary}</div>'
    return f'<div class="card" style="padding:16px;display:flex;flex-direction:column;gap:12px;align-items:center;margin-top:8px">{p}{s}<span style="color:#D63C00;font-weight:700;font-size:14px;padding:6px">Cancelar</span></div>'

def footer_desktop(primary, secondary="Salvar rascunho"):
    return f'''<div class="card" style="margin:24px 40px 16px;padding:14px 24px;display:flex;align-items:center;justify-content:space-between">
    <span style="color:#D63C00;font-weight:700;font-size:14px">Cancelar</span>
    <div style="display:flex;gap:12px"><div class="btn secondary">{secondary}</div><div class="btn primary">{primary}</div></div>
  </div>'''

def mobile(title, body, h=920, initials="AC"):
    return HEAD + f'''<div style="width:375px;min-height:{h}px;background:#FFFFFF;display:flex;flex-direction:column;box-sizing:border-box">
  {shell_header(375, initials)}
  <div style="padding:8px 16px 4px;display:flex;flex-direction:column;gap:2px"><span style="font-size:22px;font-weight:700;color:#1C2022">Sua publicação</span><span style="font-size:17px;font-weight:700;color:#3F4549">{title}</span></div>
  <div style="display:flex;flex-direction:column;gap:12px;padding:12px 16px 24px">{body}</div>
</div>
''' + TAIL

def menu_item(icon_html, label, active=None, chevron="down", child=False):
    bg = {"parent": "#942900", "child": "#D63C00"}.get(active, "transparent")
    color = "#FFFFFF" if active else "#3F4549"
    ml = "16px 8px 0 24px" if child else "4px 8px 0 8px"
    chev = ic(chevron, 18, color) if chevron else ""
    return f'<div style="display:flex;align-items:center;gap:12px;height:{"48" if child else "52"}px;padding:0 12px 0 {"12" if child else "16"}px;border-radius:10px;background:{bg};color:{color};font-size:15px;font-weight:700;margin:{ml}">{icon_html}<span style="flex:1">{label}</span>{chev}</div>'

def superadmin_menu(h):
    def img(n): return f'<img src="ic-{n}.png" style="width:24px;height:24px;display:block">'
    items = [
      menu_item(ic("bank",24), "Estrutura"), menu_item(img("acompanhamento"), "Acompanhamento"), menu_item(img("acessos"), "Acessos"),
      menu_item(img("saude"), "Saúde e Cuidado"), menu_item(img("operacao"), "Operação"), menu_item(img("comunicacao"), "Comunicação"),
      menu_item(ic("shield",24), "Governança"),
      menu_item(ic("grid",24,"#FFFFFF"), "Coelo (Principal)", active="parent", chevron="up"),
      menu_item(ic("layers",22,"#FFFFFF"), "Acontece", active="child", chevron="up", child=True),
      menu_item(ic("heart",22), "Para você", chevron=None, child=True),
      menu_item(ic("video",22), "Momentos", chevron=None, child=True),
      menu_item(ic("story",22), "Agora", chevron=None, child=True),
      menu_item(ic("user",22), "Perfil", chevron=None, child=True),
    ]
    return f'''<div style="position:absolute;left:12px;top:12px;width:260px;height:{h-24}px;border:1px solid #DDE0E2;border-radius:16px;background:#FFFFFF;box-sizing:border-box;overflow:hidden;display:flex;flex-direction:column">
    <img src="menu-topo.jpg" style="display:block;width:258px;height:208px">
    <div style="flex:1;display:flex;flex-direction:column">{"".join(items)}</div>
    <img src="menu-rodape.jpg" style="display:block;width:258px;height:135px">
  </div>'''

def desktop(title, nav_on, cols, h=1320, sidebar=None, primary="Publicar", secondary="Salvar rascunho"):
    c = "".join(f'<div style="flex:{w};min-width:0;display:flex;flex-direction:column;gap:12px">{html}</div>' for w,html in cols if w)
    return HEAD + f'''<div style="width:1440px;height:{h}px;background:#FFFFFF;position:relative;box-sizing:border-box;overflow:hidden">
  {superadmin_menu(h)}
  <div style="position:absolute;left:284px;top:12px;width:1144px;height:{h-24}px;border:1px solid #DDE0E2;border-radius:16px;background:#FFFFFF;box-sizing:border-box;display:flex;flex-direction:column;overflow:hidden">
    <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 20px 0 20px">
      <div style="display:flex;align-items:center;gap:10px">{ic("filter",18)}<span style="font-size:13px;font-weight:700">Vendo como</span><div style="display:flex;align-items:center;gap:10px;height:40px;padding:0 16px 0 12px;border-radius:999px;background:#942900;color:#FFFFFF;font-size:14px;font-weight:700">{ic("down",18,"#FFFFFF")}Colégio Coelo · @colegio-coelo</div></div>
      <img src="main-usuario.jpg" style="display:block;width:280px;height:52px">
    </div>
    <div style="flex:1;padding:16px 24px 0;display:flex;flex-direction:column;gap:16px;min-width:0">
      <div style="display:flex;flex-direction:column;gap:2px"><span style="font-size:26px;font-weight:700;color:#1C2022">Sua publicação</span><span style="font-size:18px;font-weight:700;color:#3F4549">{title}</span></div>
      <div style="display:flex;gap:24px;align-items:flex-start">{c}</div>
    </div>
    <div class="card" style="margin:24px 24px 16px;padding:14px 24px;display:flex;align-items:center;justify-content:space-between">
      <span style="color:#D63C00;font-weight:700;font-size:14px">Cancelar</span>
      <div style="display:flex;gap:12px"><div class="btn secondary">{secondary}</div><div class="btn primary">{primary}</div></div>
    </div>
  </div>
</div>
''' + TAIL

def preview_card(title_ctx, sub, text, tall=False):
    media = f'<div class="media" style="width:100%;height:{"360" if tall else "160"}px;border-radius:10px"><img src="foto-paisagem.jpg"></div>'
    return f'''<div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px">
  <div class="row"><span class="lbl" style="flex:1">Prévia</span>{ic("info",16,"#737B80")}</div>
  <div class="row"><div class="avatar brand">CO</div><div><div style="font-size:13px;font-weight:700">{title_ctx}</div><div class="muted">{sub}</div></div></div>
  <div style="font-size:13px;color:#3F4549">{text}</div>{media}
  <div class="row" style="gap:14px;color:#737B80;font-size:12px">{ic("heart",16,"#D63C00")}<span>128</span>{ic("comment",16,"#737B80")}<span>14</span></div>
  <div class="note">{ic("info",16,"#D63C00")}<span>A prévia é uma simulação de como o post aparecerá no feed.</span></div>
</div>'''

# ---------- AGORA ----------
agora_note = f'<div class="note">{ic("clock",18,"#D63C00")}<span>Stories ficam disponíveis por <b>24 horas</b> no Agora.</span></div>'
agora_m = mobile("Publicar no Agora",
  f'''<div class="row" style="align-items:flex-start;gap:12px">
    <div class="media" style="width:230px;height:320px"><img src="foto-vertical.jpg"><span class="tag">0:12</span></div>
    <div style="display:flex;flex-direction:column;gap:12px;flex:1;align-items:center">{tool("text","Texto")}{tool("music","Música")}{tool("crop","Cortar")}{tool("cover","Capa")}<div class="tool"><div class="ic">{ic("down",18)}</div></div></div>
  </div>
  {field("Escreva algo (opcional)","0/60")}
  {publico(["Colégio Coelo • Unidade Centro","Turma 3º ano A • Famílias"])}
  {agendar()}
  {agora_note}
  {footer("Publicar agora", icon_primary="send")}''', h=1060)
agora_d = desktop("Publicar no Agora", 1, [
  (0.9, f'<div class="row" style="align-items:flex-start;gap:20px"><div class="media" style="width:300px;height:520px"><img src="foto-vertical.jpg"><span class="tag">0:12</span></div><div style="display:flex;flex-direction:column;gap:20px;padding-top:8px">{tool("text","Texto")}{tool("music","Música")}{tool("crop","Cortar")}{tool("cover","Capa")}</div></div>'),
  (1, f'''{field("Escreva algo (opcional)","0/60")}{publico(["Colégio Coelo","Unidade Centro","Turma 3º ano A","Famílias"])}{agendar()}{agora_note}'''),
], h=900, primary="Publicar agora")

# ---------- ACONTECE ----------
def acontece_form(mobile_=True):
    return f'''<div class="lbl">Mídia</div>
  <div class="media" style="width:100%;height:{"200" if mobile_ else "300"}px"><img src="foto-paisagem.jpg"><span class="tag">1/6</span><span class="tag" style="left:auto;right:12px;top:auto;bottom:12px">Editar capa</span></div>
  {thumbs(4)}
  <div class="lbl">Legenda</div>
  <div class="field" style="min-height:96px"><span style="color:#3F4549">Aprender juntos é crescer juntos. Momentos que fortalecem laços e constroem o futuro. <span style="color:#D63C00">#coeloacontece</span></span><span class="ct">98/2.200</span></div>
  <div class="lbl">Público e contexto</div>
  {publico(["Colégio Coelo","Unidade Higienópolis • 3º ano A"])}
  {chips(["Famílias","Alunos","Equipe escolar","Somente responsáveis"])}
  {agendar("Agendamento","Publicar agora")}
  {opcoes()}'''
acontece_m = mobile("Publicar no Acontece", acontece_form(True) + footer("Publicar no Acontece"), h=1200)
acontece_d = desktop("Publicar no Acontece", 2, h=1160, cols=[
  (1.4, acontece_form(False)),
  (0.8, preview_card("Colégio Coelo","Unidade Higienópolis • Agora","Aprender juntos é crescer juntos. #coeloacontece", tall=True)),
], primary="Publicar no Acontece")

# ---------- MOMENTOS ----------
def momentos_form(mobile_=True):
    return f'''<div class="row" style="align-items:flex-start;gap:12px">
    <div class="media" style="{"flex:1;height:440px" if mobile_ else "width:300px;height:520px"}"><img src="foto-vertical.jpg"><span class="tag">1/5</span><span class="tag" style="top:auto;bottom:12px;background:rgba(28,32,34,.72)">0:32</span></div>
    <div style="display:flex;flex-direction:column;gap:10px">{tool("cover","Capa")}{tool("text","Texto")}{tool("music","Música")}{tool("crop","Cortar")}</div>
  </div>
  <div class="lbl">Capa do momento</div>
  {thumbs(4, sel=2)}
  <div class="lbl">Legenda</div>
  {field("Conte sobre este momento…","0/220")}
  {publico(["Colégio Coelo • 1º ano A • Famílias"])}
  {chips(["Famílias","Alunos","Equipe escolar"])}
  {agendar("Agendar publicação","Agora")}
  <div class="note">{ic("info",16,"#D63C00")}<span>Somente pessoas do contexto selecionado poderão ver este momento.</span></div>'''
momentos_m = mobile("Publicar em Momentos", momentos_form(True) + footer("Publicar agora"), h=1260)
momentos_d = desktop("Publicar em Momentos", 3, h=1300, cols=[
  (1.4, momentos_form(False)),
  (0.7, f'''<div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px"><div class="lbl">Prévia do momento</div><div class="muted">Veja como seu momento aparecerá para quem faz parte do contexto.</div>
      <div class="media" style="width:100%;height:420px;border-radius:12px"><img src="foto-vertical.jpg"><span class="tag">Colégio Coelo · 1º Ano A</span><div style="position:absolute;left:14px;right:14px;bottom:14px;color:#fff;font-weight:700;font-size:15px">Cultivando curiosidade, colhendo descobertas!</div></div>
      <div class="note">{ic("info",16,"#D63C00")}<span>Essa é uma prévia. O resultado final pode variar levemente.</span></div></div>'''),
], primary="Publicar agora")

# ---------- CIRCULARES ----------
def circular_form(mobile_=True):
    return f'''<div class="lbl">Título</div>
  <div class="field" style="min-height:48px"><span style="color:#3F4549">Reunião de pais e responsáveis — 3º ano</span></div>
  <div class="lbl">Texto da circular</div>
  <div class="field" style="min-height:{"120" if mobile_ else "180"}px"><span style="color:#3F4549">Convidamos as famílias para a reunião do 3º ano, com apresentação do plano do semestre e orientações da coordenação.</span><span class="ct">142/4.000</span></div>
  <div class="lbl">Anexos <span class="muted">até 4 · PDF ou imagem</span></div>
  <div class="row" style="gap:8px"><div class="thumb add">+</div><div class="card" style="padding:8px 10px;display:flex;align-items:center;gap:8px;font-size:12px">{ic("clip",16)}plano-semestre.pdf</div></div>
  <div class="lbl">Público e contexto</div>
  {publico(["Colégio Coelo","Unidade Higienópolis • 3º ano A"])}
  {chips(["Famílias","Alunos","Equipe escolar"])}
  <div class="lbl">Resposta esperada</div>
  {chips(["Só leitura","Confirmar ciência","Aceitar / recusar"], on=1)}
  {agendar("Agendamento","Publicar agora")}
  {opcoes()}'''
circular_m = mobile("Publicar Circular", circular_form(True) + footer("Publicar circular"), h=1300)
circular_d = desktop("Publicar Circular", 5, h=1280, cols=[
  (1.4, circular_form(False)),
  (0.8, f'''<div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px"><div class="row"><span class="lbl" style="flex:1">Prévia da circular</span>{ic("info",16,"#737B80")}</div>
     <div class="row"><div class="avatar brand">CO</div><div><div style="font-size:13px;font-weight:700">Colégio Coelo</div><div class="muted">Circular · Unidade Higienópolis</div></div></div>
     <div style="font-size:15px;font-weight:700">Reunião de pais e responsáveis — 3º ano</div>
     <div style="font-size:13px">Convidamos as famílias para a reunião do 3º ano, com apresentação do plano do semestre e orientações da coordenação.</div>
     <div class="card" style="padding:8px 10px;display:flex;align-items:center;gap:8px;font-size:12px;background:#F8F9FA">{ic("clip",16)}plano-semestre.pdf</div>
     <div class="btn primary" style="height:40px">{ic("check",16,"#fff")}Confirmar ciência</div>
     <div class="note">{ic("info",16,"#D63C00")}<span>A prévia mostra a circular como a família a verá no Principal.</span></div></div>'''),
], primary="Publicar circular")

# ---------- EVENTOS ----------
def evento_form(mobile_=True):
    return f'''<div class="lbl">Título do evento</div>
  <div class="field" style="min-height:48px"><span style="color:#3F4549">Festa junina do 3º ano</span></div>
  <div class="row" style="gap:10px"><div class="card" style="flex:1;padding:12px;display:flex;align-items:center;gap:10px">{ic("cal",18,"#D63C00")}<div><div class="muted">Data</div><div style="font-size:13px;font-weight:700">27 jun 2026</div></div></div><div class="card" style="flex:1;padding:12px;display:flex;align-items:center;gap:10px">{ic("clock",18,"#D63C00")}<div><div class="muted">Horário</div><div style="font-size:13px;font-weight:700">14:00 – 17:00</div></div></div></div>
  <div class="card" style="padding:12px;display:flex;align-items:center;gap:10px">{ic("pin",18,"#D63C00")}<div style="flex:1"><div class="muted">Local</div><div style="font-size:13px;font-weight:700">Pátio central · Unidade Higienópolis</div></div>{ic("chev",18,"#737B80")}</div>
  <div class="lbl">Descrição</div>
  {field("Conte o que vai acontecer…","0/1.000")}
  <div class="lbl">Categoria</div>
  {chips(["Evento","Prova","Aniversário","Reunião"], on=0)}
  <div class="lbl">Público e contexto</div>
  {publico(["Colégio Coelo","Unidade Higienópolis • 3º ano A"])}
  {chips(["Famílias","Alunos","Equipe escolar"])}
  <div class="row" style="justify-content:space-between">{ic("bell",18)}<span style="flex:1;font-size:13px">Lembrar 1 dia antes</span><div class="toggle"></div></div>
  {agendar("Agendamento","Publicar agora")}'''
evento_m = mobile("Publicar Evento", evento_form(True) + footer("Publicar evento"), h=1320)
evento_d = desktop("Publicar Evento", 4, h=1300, cols=[
  (1.4, evento_form(False)),
  (0.8, f'''<div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px"><div class="row"><span class="lbl" style="flex:1">Prévia na Agenda</span>{ic("info",16,"#737B80")}</div>
     <div class="card" style="padding:12px;display:flex;gap:12px;align-items:center;border-left:4px solid #D63C00"><div style="text-align:center;min-width:44px"><div style="font-size:11px;color:#737B80;font-weight:700">JUN</div><div style="font-size:22px;font-weight:800;color:#D63C00">27</div></div><div style="flex:1"><div style="font-size:14px;font-weight:700">Festa junina do 3º ano</div><div class="muted">14:00 – 17:00 · Pátio central</div></div></div>
     <div class="muted">Aparece no calendário de todas as famílias do 3º ano A e no sino no dia anterior.</div></div>'''),
], primary="Publicar evento")

# ---------- LANÇAR FALTAS ----------
def aluno(nome, estado="p", obs=None):
    seg = f'<div class="seg"><span class="{"p" if estado=="p" else ""}">P</span><span class="{"f" if estado=="f" else ""}">F</span><span class="{"a" if estado=="a" else ""}">A</span></div>'
    o = f'<div class="muted" style="margin-top:2px">{obs}</div>' if obs else ""
    return f'<div class="list-row"><div class="avatar" style="width:36px;height:36px"></div><div style="flex:1"><div style="font-size:14px;font-weight:600">{nome}</div>{o}</div>{seg}</div>'
alunos = aluno("Ana Lima") + aluno("Bruno Souza","f","Sem justificativa") + aluno("Carla Mendes") + aluno("Davi Rocha","a","Chegou 8:20") + aluno("Elisa Prado") + aluno("Felipe Nunes")
def faltas_form(mobile_=True):
    return f'''<div class="card" style="padding:12px;display:flex;align-items:center;gap:12px">{ic("users",20,"#D63C00")}<div style="flex:1"><div class="lbl">Turma e data</div><div style="font-size:13px">3º ano A · Unidade Higienópolis</div><div class="muted">Sexta, 12 set · 1º período</div></div>{ic("chev",18,"#737B80")}</div>
  <div class="row" style="justify-content:space-between"><span class="lbl">Alunos <span class="muted">24 · 22 presentes</span></span><span class="chip">Marcar todos presentes</span></div>
  <div class="card" style="overflow:hidden">{alunos}</div>
  <div class="lbl">Observação da chamada</div>
  {field("Ex.: saída antecipada, aula externa…","0/280")}
  <div class="note">{ic("bell",16,"#D63C00")}<span>Ao concluir, as famílias dos alunos com falta recebem aviso no sino.</span></div>'''
faltas_m = mobile("Lançar chamada", faltas_form(True) + footer("Concluir chamada", "Salvar e continuar depois", icon_primary="check"), h=1300)
faltas_d = desktop("Lançar chamada", 0, h=1260, cols=[
  (1.4, faltas_form(False)),
  (0.8, f'''<div class="card" style="padding:14px;display:flex;flex-direction:column;gap:10px"><div class="row"><span class="lbl" style="flex:1">Resumo do dia</span>{ic("info",16,"#737B80")}</div>
     <div style="display:grid;grid-template-columns:repeat(3, minmax(0, 1fr));gap:10px"><div class="card" style="padding:12px;text-align:center"><div style="font-size:22px;font-weight:800;color:#2D8A4E">22</div><div class="muted">Presentes</div></div><div class="card" style="padding:12px;text-align:center"><div style="font-size:22px;font-weight:800;color:#D63C00">1</div><div class="muted">Faltas</div></div><div class="card" style="padding:12px;text-align:center"><div style="font-size:22px;font-weight:800;color:#8A5B00">1</div><div class="muted">Atrasos</div></div></div>
     <div class="muted">Bruno Souza · falta sem justificativa · família será avisada</div>
     <div class="muted">Davi Rocha · atraso 8:20</div></div>'''),
], primary="Concluir chamada", secondary="Salvar e continuar depois")

files = {
 "Main.dc.html": agora_m, "AgoraDesktop.dc.html": agora_d,
 "AconteceMobile.dc.html": acontece_m, "AconteceDesktop.dc.html": acontece_d,
 "MomentosMobile.dc.html": momentos_m, "MomentosDesktop.dc.html": momentos_d,
 "CircularMobile.dc.html": circular_m, "CircularDesktop.dc.html": circular_d,
 "EventoMobile.dc.html": evento_m, "EventoDesktop.dc.html": evento_d,
 "FaltasMobile.dc.html": faltas_m, "FaltasDesktop.dc.html": faltas_d,
}
for k,v in files.items():
    open(os.path.join(OUT,k),"w",encoding="utf-8").write(v)
rows = [("Main.dc.html","AgoraDesktop.dc.html","Agora",1060),("AconteceMobile.dc.html","AconteceDesktop.dc.html","Acontece",1200),("MomentosMobile.dc.html","MomentosDesktop.dc.html","Momentos",1260),("CircularMobile.dc.html","CircularDesktop.dc.html","Circular",1300),("EventoMobile.dc.html","EventoDesktop.dc.html","Evento",1320),("FaltasMobile.dc.html","FaltasDesktop.dc.html","Lançar chamada",1300)]
ab=[]; y=0
for m,d,t,h in rows:
    ab.append({"file":m,"x":0,"y":y,"w":375,"h":h,"title":f"{t} · mobile 375"})
    ab.append({"file":d,"x":480,"y":y,"w":1440,"h":{"Agora":900,"Acontece":1160,"Momentos":1300,"Circular":1280,"Evento":1300,"Lançar chamada":1260}[t],"title":f"{t} · desktop 1440"})
    y += max(h,1300)+140
json.dump({"artboards":ab,"launch":{"view":"canvas"}}, open(os.path.join(OUT,"canvas.json"),"w"), indent=1)
print("ok", len(files))
