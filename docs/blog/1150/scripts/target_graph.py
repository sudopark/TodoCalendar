import os,re,sys
from collections import defaultdict
REPO=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../.."))
# 아직 Domain 에 남은 파일은 경로 규칙으로, 모듈로 떼어 낸 파일은 그 디렉터리로 서브도메인을 정한다
ROOTS=[("Domain/Sources",None),
       ("Domain/KernelUtils/Sources","Kernel_Utils"),
       ("Domain/CalendarDomain/Interface","CalendarDomain"),
       ("Domain/CalendarDomain/Sources","CalendarDomain"),
       ("Repository/CalendarRepository/Interface","CalendarDomain")]

def module_of(rel):
    r=rel.replace(os.sep,"/")
    if "/Device/" in r: return "Kernel_Utils"
    if "/Migration/" in r: return "MigrationDomain"
    if r.startswith("Models/Place/"): return "PlaceServiceInterface"
    if "Events/ExternalCalendar/" in r or "Account/ExternalServiceIntegration/" in r \
       or r.endswith("Repositories/Auth/ExternalServiceIntegrateRepository.swift"):
        return "ExternalCalendarDomain"
    if r.startswith(("Models/Events","Usecases/Events","Repositories/Events")): return "EventDomain"
    if r in ("Utils/RRule+EventRepeating.swift","Utils/EventDeepLink.swift",
             "Utils/SharedEventNotifyService.swift","Repositories/DDayCandidateRepository.swift"):
        return "EventDomain"
    if r.startswith(("Models/Calendar","Usecases/Calendar","Repositories/Calendar")): return "CalendarDomain"
    if r.startswith(("Models/Account","Usecases/Account","Repositories/Auth")): return "AccountDomain"
    if r.startswith(("Models/Notifications","Usecases/Notification","Repositories/Notification")): return "NotificationDomain"
    if r.startswith(("Models/Billing","Usecases/Billing","Repositories/Billing")): return "BillingDomain"
    if r.startswith(("Models/AI","Usecases/AI","Repositories/AI")): return "AIDomain"
    if r.startswith(("Models/Ad","Usecases/Ad","Repositories/Ad")): return "AdDomain"
    if r.startswith(("Models/Settings","Usecases/Setting","Repositories/Setting")): return "SettingDomain"
    if r.startswith(("Usecases/Support","Usecases/Speech","Usecases/ImageText",
                     "Usecases/Common","Models/Common")): return "SupportDomain"
    if r.startswith("Repositories/"): return "SupportDomain"     # 미분류 포트(App/Guide/LegalNotice/ColdLaunch)
    if r.startswith("Models/"): return "SupportDomain"           # AppUpdateInfo/LegalNotice
    return "Kernel_Utils"                                        # SharedDataStore/FeatureFlag/Link 류

files={}
for root,fixed in ROOTS:
    base=os.path.join(REPO,root)
    for dp,_,fns in os.walk(base):
        for fn in fns:
            if fn.endswith(".swift"):
                rel=os.path.relpath(os.path.join(dp,fn),base)
                src=open(os.path.join(dp,fn),encoding="utf-8",errors="ignore").read()
                key=rel if fixed is None else f"{root}/{rel}"
                files[key]=(fixed or module_of(rel),re.sub(r'//.*','',src))

DECL=re.compile(r'^\s*(?:public |internal |private |final |@\w+\s+)*(?:struct|class|enum|protocol|typealias|actor)\s+([A-Z]\w+)',re.M)
owner={}
for rel,(mod,src) in files.items():
    for m in DECL.finditer(src):
        t=m.group(1)
        owner.setdefault(t,(mod,rel))
NOISE={"CodingKeys","Query","Status","DataType","QueryType","ResultType","Error","Key","Item","Option","Result","Element","Value","Failure","Output","Input",
       "Event","Scope","Subject","Tag","Constant"}
edges=defaultdict(list)
for rel,(mod,src) in files.items():
    for t in set(re.findall(r'\b([A-Z]\w+)\b',src)):
        if t in NOISE: continue
        if t in owner:
            o,orel=owner[t]
            if o!=mod: edges[(mod,o)].append((rel,t))
mods=sorted({m for m,_ in files.values()})
adj={m:set() for m in mods}
for (a,b) in edges:
    if a in adj: adj[a].add(b)
# SCC (Tarjan)
idx={};low={};on=set();st=[];cnt=[0];sccs=[]
def dfs(v):
    idx[v]=low[v]=cnt[0];cnt[0]+=1;st.append(v);on.add(v)
    for w in adj.get(v,()):
        if w not in idx: dfs(w);low[v]=min(low[v],low[w])
        elif w in on: low[v]=min(low[v],idx[w])
    if low[v]==idx[v]:
        c=[]
        while True:
            w=st.pop();on.discard(w);c.append(w)
            if w==v: break
        if len(c)>1: sccs.append(c)
sys.setrecursionlimit(10000)
for m in mods:
    if m not in idx: dfs(m)
print("== 제안 분할 기준 모듈 간 간선 ==")
for (a,b),v in sorted(edges.items(),key=lambda kv:-len(kv[1])):
    print(f"  {a:24s} -> {b:24s} {len(v):3d}")
print("\n== 남은 순환 (SCC) ==")
if not sccs: print("  없음 — DAG")
for c in sccs:
    print(f"  {' <-> '.join(sorted(c))}")
    for a in c:
        for b in c:
            if a!=b and (a,b) in edges:
                for rel,t in sorted(edges[(a,b)])[:6]:
                    print(f"     {a}->{b}  {rel}  :: {t}")

print("\n== 추출 층 (의존이 없는 쪽부터) ==")
if sccs:
    print("  순환이 남아 층을 낼 수 없다 — 위 SCC 부터 끊는다")
else:
    depth={}
    def longest(v):
        if v not in depth: depth[v]=1+max((longest(w) for w in adj[v]),default=-1)
        return depth[v]
    for m in mods: longest(m)
    for d in sorted(set(depth.values())):
        print(f"  {d}: {', '.join(sorted(m for m in mods if depth[m]==d))}")
