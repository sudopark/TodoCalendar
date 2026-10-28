import os,re,collections
ROOT=os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../..")),"Domain/Sources")
ALIAS={"Notifications":"Notification","Settings":"Setting","Events":"Event","Auth":"Account"}
def sub_of(rel):
    p=rel.split(os.sep)
    return ALIAS.get(p[1],p[1]) if p[0] in {"Models","Usecases","Repositories"} and len(p)>2 else ("_loose" if p[0] in {"Models","Usecases","Repositories"} else "_utils")
files={}
for dp,_,fns in os.walk(ROOT):
    for fn in fns:
        if fn.endswith(".swift"):
            rel=os.path.relpath(os.path.join(dp,fn),ROOT)
            files[rel]=(sub_of(rel),open(os.path.join(dp,fn),encoding="utf-8",errors="ignore").read())
# Repositories/ 밑에서 선언된 프로토콜 = repository 포트
PROTO=re.compile(r'^\s*(?:public )?protocol\s+([A-Z]\w+)',re.M)
repo_owner={}
for rel,(sub,src) in files.items():
    if rel.startswith("Repositories"+os.sep):
        for m in PROTO.finditer(src): repo_owner[m.group(1)]=(sub,rel)
print(f"repository 포트 {len(repo_owner)}개\n")
hits=collections.defaultdict(list)
for rel,(sub,src) in files.items():
    if rel.startswith("Repositories"+os.sep): continue
    for t in set(re.findall(r'\b([A-Z]\w+)\b',src)):
        if t in repo_owner:
            o,orel=repo_owner[t]
            if o!=sub: hits[(sub,o)].append((rel,t))
if not hits: print("서브도메인 경계를 넘는 repository 포트 참조: 0건")
for (a,b),v in sorted(hits.items(),key=lambda kv:-len(kv[1])):
    print(f"### {a} -> {b} 의 repository 포트 ({len(v)}건)")
    for rel,t in sorted(v): print(f"   {rel:62s} {t}")
