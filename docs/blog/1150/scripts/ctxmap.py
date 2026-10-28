import os, re, collections
ROOT=os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../..")),"Domain/Sources")
LAYERS={"Models","Usecases","Repositories"}
ALIAS={"Notifications":"Notification","Settings":"Setting","Events":"Event","Account":"Account"}

def sub_of(rel):
    parts=rel.split(os.sep)
    if parts[0] in LAYERS:
        if len(parts)>2:
            s=parts[1]
            return ALIAS.get(s,s)
        return "_loose"      # 계층 바로 밑 단일 파일
    return "_utils"

files={}
for dp,_,fns in os.walk(ROOT):
    for fn in fns:
        if not fn.endswith(".swift"): continue
        p=os.path.join(dp,fn); rel=os.path.relpath(p,ROOT)
        files[rel]=(sub_of(rel), open(p,encoding="utf-8",errors="ignore").read())

DECL=re.compile(r'^\s*(?:public |internal |private |final |@\w+\s+)*(?:struct|class|enum|protocol|typealias|actor)\s+([A-Z]\w+)',re.M)
owner={}   # 타입명 -> 서브도메인 (선언 파일 기준)
decl_counts=collections.Counter()
for rel,(sub,src) in files.items():
    for m in DECL.finditer(src):
        t=m.group(1)
        if t not in owner: owner[t]=sub
for rel,(sub,src) in files.items():
    decl_counts[sub]+=1

edges=collections.Counter()
for rel,(sub,src) in files.items():
    used=set(re.findall(r'\b([A-Z]\w+)\b',src))
    for t in used:
        o=owner.get(t)
        if o and o!=sub:
            edges[(sub,o)]+=1

subs=sorted(decl_counts, key=lambda s:-decl_counts[s])
print("서브도메인별 파일 수:")
for s in subs: print(f"  {s:14s} {decl_counts[s]}")
print("\n의존 간선 (A -> B, 참조 횟수 5회 이상):")
for (a,b),c in sorted(edges.items(), key=lambda kv:-kv[1]):
    if c>=5: print(f"  {a:14s} -> {b:14s} {c}")
print("\n양방향(순환) 쌍:")
seen=set()
for (a,b),c in edges.items():
    if (b,a) in edges and (b,a) not in seen and a<b:
        seen.add((a,b)); print(f"  {a} <-> {b}   ({a}->{b}: {c}, {b}->{a}: {edges[(b,a)]})")
