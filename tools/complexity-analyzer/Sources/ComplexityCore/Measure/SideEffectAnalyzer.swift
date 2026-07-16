import SwiftSyntax

/// query 함수 메인 흐름 / 순수 Combine 연산자 클로저에 노출된 side-effect를 센다.
/// side-effect v1 (좁게): stored-property/Subject 대입(`self.x =`, `subject.value =`) + `.send(...)`.
enum SideEffectAnalyzer {

    struct Result: Equatable {
        var cqsViolations: Int
        var combineRoleMix: Int
        static let zero = Result(cqsViolations: 0, combineRoleMix: 0)
    }

    /// 순수 변형 계약 연산자 — 클로저 안 side-effect는 역할 혼합 위반.
    private static let pureOperators: Set<String> =
        ["map", "flatMap", "compactMap", "filter", "reduce", "scan"]
    /// side-effect 허용 연산자 — 여기 클로저는 위반 아님 (side-effect의 올바른 자리).
    private static let allowedOperators: Set<String> =
        ["sink", "handleEvents", "do"]
    /// 동기 고차함수 — 클로저가 즉시 실행되므로 지연(deferred)이 아니다. 투명하게 통과시켜
    /// 바깥 컨텍스트(본문·pure·allowed)가 분류하게 한다. `arr.forEach { self.x = ... }`는 동기 변이.
    private static let synchronousOperators: Set<String> = ["forEach"]

    static func analyze(body: CodeBlockSyntax, isQuery: Bool) -> Result {
        let collector = SideEffectCollector(viewMode: .sourceAccurate)
        collector.walk(body)

        var result = Result.zero
        let bodyNode = Syntax(body)
        for site in collector.sites {
            // 로컬 변수(복사본)의 멤버 대입(`var c = self; c.x = ...`)은 functional update —
            // 외부 상태 변이가 아니므로 side-effect에서 제외한다. self·멤버(subject) 대입만 남긴다.
            if let base = site.assignmentBase, collector.localVarNames.contains(base) { continue }
            switch nearestOperator(from: site.node, stopAt: bodyNode) {
            case .pure:
                result.combineRoleMix += 1
            case .allowed, .deferred:
                break
            case .none:
                if isQuery { result.cqsViolations += 1 }
            }
        }
        return result
    }

    /// none = 메서드 본문 직접 흐름(동기), pure/allowed = 인식된 Combine 연산자,
    /// deferred = 인식 못 한 클로저(반환 factory·escaping 콜백 등) 안 — 나중 실행이라 동기 side-effect 아님.
    private enum OperatorKind { case pure, allowed, none, deferred }

    /// site에서 body까지 부모를 거슬러 올라가며 판정. 인식된 연산자 클로저를 만나면 그 종류,
    /// 동기 고차함수(forEach)는 투명 통과, 인식 못 한 클로저를 통과하면 deferred,
    /// 어떤 클로저도 안 거치면 none(본문 직접).
    private static func nearestOperator(from site: Syntax, stopAt body: Syntax) -> OperatorKind {
        var current = site.parent
        var passedUnrecognizedClosure = false
        while let node = current, node != body {
            if let closure = node.as(ClosureExprSyntax.self) {
                let name = operatorName(wrapping: closure)
                if let name {
                    if pureOperators.contains(name) { return .pure }
                    if allowedOperators.contains(name) { return .allowed }
                    if synchronousOperators.contains(name) {
                        current = node.parent   // 동기 → 투명 통과(바깥 컨텍스트가 분류)
                        continue
                    }
                }
                // 반환 클로저·escaping 콜백 등 인식 못 한 클로저 → 지연 실행
                passedUnrecognizedClosure = true
            }
            current = node.parent
        }
        return passedUnrecognizedClosure ? .deferred : .none
    }

    /// 클로저가 `x.op { }`(trailing) / `x.op(label: { })`(labeled arg) 형태로 붙은 연산자 이름.
    private static func operatorName(wrapping closure: ClosureExprSyntax) -> String? {
        let call = closure.parent?.as(FunctionCallExprSyntax.self)
            ?? closure.parent?.as(LabeledExprSyntax.self)?
                .parent?.as(LabeledExprListSyntax.self)?
                .parent?.as(FunctionCallExprSyntax.self)
        return call?.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }
}

// MARK: - side-effect 부위 수집

private final class SideEffectCollector: SyntaxVisitor {

    /// side-effect 후보. `assignmentBase`는 멤버 대입의 최상위 base 식별자(예: `self`·`subject`·`c`).
    /// nil이면 base 판별이 필요 없는 site(예: `.send`).
    struct Site {
        let node: Syntax
        let assignmentBase: String?
    }

    private(set) var sites: [Site] = []
    /// 이 메소드 본문에서 선언된 로컬 변수 이름 — 그 멤버 대입은 functional update로 간주해 제외.
    private(set) var localVarNames: Set<String> = []

    // 중첩 함수·local 타입은 각자 독립 unit으로 따로 측정되므로, 바깥 메소드 스코프에
    // 새어들지 않게 하위로 내려가지 않는다 (클로저는 연산자 컨텍스트용이라 계속 순회).
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }

    /// 로컬 변수 선언(`var c = self`, `let x = ...`) 이름을 등록. 본문 스코프 한정
    /// (중첩 func/타입은 skipChildren이라 안 들어옴).
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                localVarNames.insert(name)
            }
        }
        return .visitChildren
    }

    /// stored-property/Subject 대입: `self.x = ...`, `subject.value = ...`
    ///
    /// `Parser.parse`는 operator folding을 하지 않아 대입이 `InfixOperatorExpr`가 아니라
    /// unfolded `SequenceExpr`(좌변 · `=`(AssignmentExpr) · 우변)로 나온다. 대입 토큰 직전
    /// 요소가 MemberAccess(`self.x`, `subject.value`)면 외부 상태 변이 후보로 본다.
    /// 단 최상위 base가 로컬 변수면 functional update라 analyze에서 걸러진다.
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        for (i, element) in elements.enumerated()
        where element.is(AssignmentExprSyntax.self) {
            if i > 0, let member = elements[i - 1].as(MemberAccessExprSyntax.self) {
                sites.append(Site(node: Syntax(node), assignmentBase: Self.rootBaseName(of: member)))
            }
        }
        return .visitChildren
    }

    /// Subject 방출: `xxx.send(...)`
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "send" {
            sites.append(Site(node: Syntax(node), assignmentBase: nil))
        }
        return .visitChildren
    }

    /// 멤버 접근 체인의 최상위 base 식별자. `self.subject.value` → `self`, `c.x` → `c`.
    private static func rootBaseName(of member: MemberAccessExprSyntax) -> String? {
        var base = member.base
        while let inner = base?.as(MemberAccessExprSyntax.self) { base = inner.base }
        return base?.as(DeclReferenceExprSyntax.self)?.baseName.text
    }
}
