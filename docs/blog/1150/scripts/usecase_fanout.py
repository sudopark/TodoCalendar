import os,re,collections
BASE=os.path.abspath(os.path.join(os.path.dirname(__file__),"../../../.."))
DOM=os.path.join(BASE,"Domain/Sources")
ALIAS={"Notifications":"Notification","Settings":"Setting","Events":"Event","Auth":"Account"}
def sub_of(rel):
    p=rel.split(os.sep)
    return ALIAS.get(p[1],p[1]) if p[0] in {"Models","Usecases","Repositories"} and len(p)>2 else "_loose"
# usecase 프로토콜 -> 서브도메인
uc={}
for dp,_,fns in os.walk(os.path.join(DOM,"Usecases")):
    for fn in fns:
        if not fn.endswith(".swift"): continue
        p=os.path.join(dp,fn); rel=os.path.relpath(p,DOM)
        src=open(p,encoding="utf-8",errors="ignore").read()
        for m in re.finditer(r'^\s*public protocol\s+([A-Z]\w+)',src,re.M):
            uc[m.group(1)]=sub_of(rel)
# Presentation 모듈별 소비
PRES=os.path.join(BASE,"Presentations")
mods=[d for d in os.listdir(PRES) if os.path.isdir(os.path.join(PRES,d))]
consumed=collections.defaultdict(set)      # usecase -> {모듈}
sub_by_mod=collections.defaultdict(set)    # 모듈 -> {서브도메인}
for mod in mods:
    srcdir=os.path.join(PRES,mod,"Sources")
    if not os.path.isdir(srcdir): continue
    for dp,_,fns in os.walk(srcdir):
        for fn in fns:
            if not fn.endswith(".swift"): continue
            txt=open(os.path.join(dp,fn),encoding="utf-8",errors="ignore").read()
            for t in set(re.findall(r'\b([A-Z]\w+)\b',txt)):
                if t in uc:
                    consumed[t].add(mod); sub_by_mod[mod].add(uc[t])
print(f"public usecase 프로토콜 {len(uc)}개 중 Presentation 이 소비하는 것 {len(consumed)}개\n")
print("== 2개 이상 화면 모듈이 쓰는 usecase (요구사항 축의 증거) ==")
multi=[(t,v) for t,v in consumed.items() if len(v)>=2]
for t,v in sorted(multi,key=lambda kv:-len(kv[1]))[:18]:
    print(f"  {t:42s} [{uc[t]:12s}] {len(v)}개: {', '.join(sorted(v))}")
print(f"\n  → 다화면 소비 {len(multi)}개 / 단일화면 소비 {len(consumed)-len(multi)}개")
print("\n== 화면 모듈이 참조하는 서브도메인 수 (1이면 화면 모양) ==")
for mod in sorted(sub_by_mod,key=lambda m:-len(sub_by_mod[m])):
    print(f"  {mod:22s} {len(sub_by_mod[mod])}개: {', '.join(sorted(sub_by_mod[mod]))}")
