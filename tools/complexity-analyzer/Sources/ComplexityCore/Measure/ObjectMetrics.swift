/// 한 정규화 타입의 raw 객체-레벨 사실(파일 간 병합 전).
/// extension이 여러 파일에 흩어져도 정규화 이름으로 모아 원본 타입에 집계하기 위한 중간 표현.
struct TypeFacts: Equatable {
    var rollupInternal = 0
    var rollupCqs = 0
    var rollupCombine = 0
    var publicSurface = 0
    var storedProps: Set<String> = []
    var methods: [MethodMembership] = []
    /// 원본(primary) 타입 선언 위치. extension만 있는 파일에선 nil.
    var primary: SourceRef?

    struct MethodMembership: Equatable {
        var name: String
        var uses: Set<String>
        var calls: Set<String>
    }

    struct SourceRef: Equatable {
        var file: String
        var line: Int
        var name: String
    }

    /// 같은 정규화 이름의 파일별 facts를 합친다(롤업 합산·프로퍼티 union·메소드 concat·primary 보존).
    static func merged(_ a: TypeFacts, _ b: TypeFacts) -> TypeFacts {
        var r = a
        r.rollupInternal += b.rollupInternal
        r.rollupCqs += b.rollupCqs
        r.rollupCombine += b.rollupCombine
        r.publicSurface += b.publicSurface
        r.storedProps.formUnion(b.storedProps)
        r.methods.append(contentsOf: b.methods)
        r.primary = a.primary ?? b.primary
        return r
    }
}

/// 정규화 타입별 raw facts(파일 간 병합 완료)를 받아 객체-레벨 측정을 계산,
/// 원본 타입 유닛(primary 선언 위치)에 패치한다. cross-file extension 재조립이 여기서 성립.
enum ObjectMetricsAggregator {

    static func patched(units: [AnalyzedUnit], factsByQualified: [String: TypeFacts]) -> [AnalyzedUnit] {
        var result = units

        var indexByLocation: [String: Int] = [:]
        for (i, unit) in result.enumerated() where unit.kind == .type {
            indexByLocation["\(unit.file):\(unit.line):\(unit.name)"] = i
        }

        for facts in factsByQualified.values {
            guard let primary = facts.primary,
                  let index = indexByLocation["\(primary.file):\(primary.line):\(primary.name)"]
            else { continue }

            let methodNames = Set(facts.methods.map { $0.name })
            let nodes = facts.methods.map {
                MethodNode(
                    name: $0.name,
                    referencedProps: $0.uses.intersection(facts.storedProps),
                    calledMethods: $0.calls.intersection(methodNames)
                )
            }
            let cohesion = CohesionAnalyzer.metrics(methods: nodes)

            result[index].measurements.rolledUpInternalComplexity = facts.rollupInternal
            result[index].measurements.rolledUpCqsViolations = facts.rollupCqs
            result[index].measurements.rolledUpCombineRoleMix = facts.rollupCombine
            result[index].measurements.publicSurface = facts.publicSurface
            // LCOM(응집도)은 구현체 메소드가 상태를 공유하는지의 지표 — protocol(구현 없음)·enum(case별
            // 분기라 구조적으로 낮음)엔 비적용. 이 둘엔 lcom을 남기지 않아(nil) 과탐을 막는다.
            if result[index].measuresCohesion {
                result[index].measurements.lcom = cohesion.lcom
            }
            result[index].measurements.internalCoupling = cohesion.internalCoupling
            result[index].measurements.maxCallChainDepth = cohesion.maxCallChainDepth
        }
        return result
    }
}
