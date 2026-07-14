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

    static func analyze(body: CodeBlockSyntax, isQuery: Bool) -> Result {
        let collector = SideEffectCollector(viewMode: .sourceAccurate)
        collector.walk(body)

        var result = Result.zero
        let bodyNode = Syntax(body)
        for site in collector.sites {
            switch nearestOperator(from: site, stopAt: bodyNode) {
            case .pure:
                result.combineRoleMix += 1
            case .allowed:
                break
            case .none:
                if isQuery { result.cqsViolations += 1 }
            }
        }
        return result
    }

    private enum OperatorKind { case pure, allowed, none }

    /// site에서 body까지 부모를 거슬러 올라가며 만나는 첫 인식 연산자 클로저의 종류.
    private static func nearestOperator(from site: Syntax, stopAt body: Syntax) -> OperatorKind {
        var current = site.parent
        while let node = current, node != body {
            if let closure = node.as(ClosureExprSyntax.self),
               let name = operatorName(wrapping: closure) {
                if pureOperators.contains(name) { return .pure }
                if allowedOperators.contains(name) { return .allowed }
                // 인식 못 한 연산자 클로저(예: forEach) → 계속 상향 탐색
            }
            current = node.parent
        }
        return .none
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

    private(set) var sites: [Syntax] = []

    /// stored-property/Subject 대입: `self.x = ...`, `subject.value = ...`
    ///
    /// `Parser.parse`는 operator folding을 하지 않아 대입이 `InfixOperatorExpr`가 아니라
    /// unfolded `SequenceExpr`(좌변 · `=`(AssignmentExpr) · 우변)로 나온다. 대입 토큰 직전
    /// 요소가 MemberAccess(`self.x`, `subject.value`)면 외부 상태 변이로 본다.
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        for (i, element) in elements.enumerated()
        where element.is(AssignmentExprSyntax.self) {
            if i > 0, elements[i - 1].is(MemberAccessExprSyntax.self) {
                sites.append(Syntax(node))
            }
        }
        return .visitChildren
    }

    /// Subject 방출: `xxx.send(...)`
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "send" {
            sites.append(Syntax(node))
        }
        return .visitChildren
    }
}
