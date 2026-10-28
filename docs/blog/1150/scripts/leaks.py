import os, re, collections
ROOT=os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../..")),"Domain/Sources")
LAYERS={"Models","Usecases","Repositories"}
ALIAS={"Notifications":"Notification","Settings":"Setting","Events":"Event"}
def sub_of(rel):
    p=rel.split(os.sep)
    if p[0] in LAYERS:
        return ALIAS.get(p[1],p[1]) if len(p)>2 else "_loose"
    return "_utils"
files={}
for dp,_,fns in os.walk(ROOT):
    for fn in fns:
        if fn.endswith(".swift"):
            rel=os.path.relpath(os.path.join(dp,fn),ROOT)
            files[rel]=(sub_of(rel),open(os.path.join(dp,fn),encoding="utf-8",errors="ignore").read())
DECL=re.compile(r'^\s*(?:public |internal |private |final |@\w+\s+)*(?:struct|class|enum|protocol|typealias|actor)\s+([A-Z]\w+)',re.M)
owner={}
for rel,(sub,src) in files.items():
    for m in DECL.finditer(src):
        owner.setdefault(m.group(1),(sub,rel))
# 소수 방향 간선의 실물 출력
PAIRS=[("Notification","Event"),("Event","Notification"),("Setting","Event"),("Event","Setting"),
       ("Account","Event"),("Event","Account"),("AI","Event"),("Event","AI"),
       ("Common","Event"),("Event","Common"),("_utils","Event"),("Auth","Account"),("Account","Auth")]
det=collections.defaultdict(list)
for rel,(sub,src) in files.items():
    for t in set(re.findall(r'\b([A-Z]\w+)\b',src)):
        if t in owner:
            o,orel=owner[t]
            if o!=sub and (sub,o) in PAIRS:
                det[(sub,o)].append((rel,t,orel))
for k in PAIRS:
    v=det.get(k)
    if not v: continue
    print(f"\n### {k[0]} -> {k[1]}  ({len(v)}건)")
    for rel,t,orel in sorted(v):
        print(f"  {rel:58s}  {t:28s}  (선언: {orel})")
