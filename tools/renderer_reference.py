import zipfile, html, re, json, hashlib, sys
from xml.etree import ElementTree as ET
ns='{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
DOCX='/root/.claude/uploads/b9fa23cc-70a3-5627-959b-3ce44515618a/cc971957-Article-Source-Dont-Count-Your-Chickens-v3.1.docx'
PDIR='prompts'; GOLD='dont-count-your-chickens-before-the-checkpoint.html'

# ---------- 1. Build the content-as-data file (what Marketing would submit) from the source ----------
root=ET.fromstring(zipfile.ZipFile(DOCX).read('word/document.xml').decode('utf-8'))
def ptext(p): return ''.join((n.text or '') for n in p.iter() if n.tag.split('}')[-1]=='t' or n.tag.split('}')[-1]=='br' and False) or ''.join(('\n' if n.tag.split('}')[-1]=='br' else (n.text or '')) for n in p.iter() if n.tag.split('}')[-1] in('t','br'))
def pstyle(p):
    pPr=p.find(ns+'pPr'); ps=pPr.find(ns+'pStyle') if pPr is not None else None
    return ps.get(ns+'val','') if ps is not None else ''
paras=[(pstyle(p),ptext(p)) for p in root.iter(ns+'p')]
prompts=[open(f'{PDIR}/prompt{i}.txt').read() for i in range(1,7)]
skip=set()
for a,b in [(31,63),(70,73),(79,84),(90,92),(98,100),(106,109)]: skip.update(range(a,b+1))
COPY={30:1,69:2,78:3,89:4,97:5,105:6}

body_md_lines=[]; stop=False
for i,(style,text) in enumerate(paras,start=1):
    if stop: break
    if i in (1,2): continue
    if style=='Heading2' and text.strip().startswith('Notes for publishing'): break
    if i in skip: continue
    if not text.strip(): continue
    if i in COPY:
        body_md_lines.append('```prompt\n'+prompts[COPY[i]-1]+'\n```'); continue
    if style=='Heading2': body_md_lines.append('## '+text); continue
    if style=='Heading3': body_md_lines.append('### '+text); continue
    if style=='ListNumber': body_md_lines.append('@OL '+text); continue
    if style=='ListBullet': body_md_lines.append('- '+text); continue
    # inject the two approved links as markdown in the body text
    if text.startswith('Back in June'):
        text=text.replace('Back in June','[Back in June](https://martech.org/build-your-ai-skills-with-a-useful-home-project/)',1)
    if 'ryanphelan.com/chat' in text:
        text=text.replace('ryanphelan.com/chat','[ryanphelan.com/chat](https://ryanphelan.com/chat)',1)
    body_md_lines.append(text)
body_md='\n'.join(body_md_lines)

front={'schema':'blogpub/article/v1','id':'2026-10-29-dont-count-chickens','op':'create',
 'slug':'dont-count-your-chickens-before-the-checkpoint',
 'title':paras[0][1],'seo_title':paras[0][1].split(':')[0],
 'excerpt':'Six AI governance prompts I use every day, why I wrote each one, and how to start with just two. Copy them for your own projects.',
 'meta_description':'Six AI governance prompts I use every day, why I wrote each one, and how to start with just two. Copy them for your own projects.',
 'author':'Ryan Phelan','tags':['Original'],'canonical_url':'','publish_time':'2026-10-29T13:00:00Z'}
content_file='---\n'+json.dumps(front,indent=0)[1:-1].replace('\n','\n')+'\n---\n'+body_md+'\n'
open('content_dont-count.md','w').write(content_file)

# ---------- 2. Renderer: content body -> body HTML (same logic the generator used) ----------
esc=lambda s: html.escape(s, quote=False)
def smarten(t):
    t=t.replace("'","’"); out=[]
    for i,ch in enumerate(t):
        if ch=='"':
            prev=t[i-1] if i>0 else ' '
            out.append('“' if (i==0 or prev.isspace() or prev in '([{’') else '”')
        else: out.append(ch)
    return ''.join(out)
def linkify(e):  # convert [text](url) markdown links to anchors (url has no special chars here)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', e)
def prompt_block(n,txt):
    return ('<div class="prompt">\n'
            '  <details class="prompt-d">\n'
            '    <summary class="prompt-toggle"><span class="pt-show">Show the prompt</span><span class="pt-hide">Hide the prompt</span></summary>\n'
            f'    <pre class="prompt-text" id="prompt-{n}">{esc(txt)}</pre>\n'
            '  </details>\n'
            f'  <button type="button" class="prompt-copy" data-copy="prompt-{n}" aria-live="polite">Copy</button>\n'
            '</div>')

def render_body(md):
    lines=md.split('\n'); i=0; out=[]; pn=0
    olbuf=[]; ulbuf=[]
    def flush():
        nonlocal olbuf,ulbuf
        if olbuf: out.append('<ol>'+''.join(f'<li>{esc(smarten(x))}</li>' for x in olbuf)+'</ol>'); olbuf=[]
        if ulbuf: out.append('<ul>'+''.join(f'<li>{esc(smarten(x))}</li>' for x in ulbuf)+'</ul>'); ulbuf=[]
    while i<len(lines):
        ln=lines[i]
        if ln.startswith('```prompt'):
            flush(); j=i+1; buf=[]
            while j<len(lines) and lines[j]!='```': buf.append(lines[j]); j+=1
            pn+=1; out.append(prompt_block(pn,'\n'.join(buf))); i=j+1; continue
        if ln.startswith('## '): flush(); out.append(f'<h2>{esc(smarten(ln[3:]))}</h2>'); i+=1; continue
        if ln.startswith('### '): flush(); out.append(f'<h3>{esc(smarten(ln[4:]))}</h3>'); i+=1; continue
        if ln.startswith('@OL '): 
            if ulbuf: flush()
            olbuf.append(ln[4:]); i+=1; continue
        if ln.startswith('- '):
            if olbuf: flush()
            ulbuf.append(ln[2:]); i+=1; continue
        if not ln.strip(): flush(); i+=1; continue
        flush()
        e=esc(smarten(ln))
        if ln.startswith('Why I wrote it:'): e=e.replace('Why I wrote it:','<strong>Why I wrote it:</strong>',1)
        e=linkify(e)
        out.append(f'<p>{e}</p>'); i+=1
    flush()
    return '\n'.join(out)

# ---------- 3. Golden test: rendered body vs the live article's body ----------
gold=open(GOLD,encoding='utf-8').read()
m1='    <div class="art-body">\n'; m2='\n    </div>\n  </div></div></article>'
gbody=gold[gold.index(m1)+len(m1):gold.index(m2)]
# body_md from the stored content file (reparse its body)
cf=open('content_dont-count.md').read()
cbody=cf.split('\n---\n',1)[1].rstrip('\n')
rbody=render_body(cbody)
print('golden body bytes:',len(gbody.encode()),'| rendered body bytes:',len(rbody.encode()))
print('BODY BYTE-EXACT MATCH:', rbody==gbody)
if rbody!=gbody:
    # show first difference
    for k in range(min(len(rbody),len(gbody))):
        if rbody[k]!=gbody[k]:
            print('first diff at char',k); print(' gold:',repr(gbody[k-40:k+40])); print(' rend:',repr(rbody[k-40:k+40])); break
    print('len gold',len(gbody),'len rend',len(rbody))
# prompt-exactness inside rendered body
for n in range(1,7):
    pt=re.search(rf'id="prompt-{n}">(.*?)</pre>',rbody,re.S).group(1)
    src=open(f'{PDIR}/prompt{n}.txt').read()
    print(f'  prompt-{n} exact:', html.unescape(pt)==src)
