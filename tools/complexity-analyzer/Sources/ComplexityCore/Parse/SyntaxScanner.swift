import Foundation
import SwiftSyntax
import SwiftParser

/// SwiftSyntax로 소스를 파싱해 메소드 단위 + 내부 복잡도를 뽑는다.
public struct SyntaxScanner {

    public init() {}

    public func scan(source: String, file: String) -> [AnalyzedUnit] {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: tree)
        let collector = MethodCollector(file: file, converter: converter)
        collector.walk(tree)
        collector.finalize()
        return collector.units
    }
}

// MARK: - 메소드 수집 + enclosing type 추적

private final class MethodCollector: SyntaxVisitor {

    let file: String
    let converter: SourceLocationConverter
    private(set) var units: [AnalyzedUnit] = []
    private var typeStack: [String] = []

    /// 정규화 타입 이름(enclosing 체인 + 이름) → 소속 메소드 측정 누적.
    private var rollupByQualified: [String: (internal: Int, cqs: Int, combine: Int)] = [:]
    /// 정규화 타입 이름 → units 배열 내 그 타입 유닛 인덱스(post-walk 패치용).
    private var typeUnitIndexByQualified: [String: Int] = [:]
    /// 정규화 타입 이름 → public/open 멤버 수.
    private var publicSurfaceByQualified: [String: Int] = [:]

    private var currentQualified: String { typeStack.joined(separator: ".") }
    private func qualified(_ name: String) -> String {
        (typeStack + [name]).joined(separator: ".")
    }

    init(file: String, converter: SourceLocationConverter) {
        self.file = file
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { enterType(node.name) }
    override func visitPost(_ node: ClassDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { enterType(node.name) }
    override func visitPost(_ node: StructDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { enterType(node.name) }
    override func visitPost(_ node: EnumDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { enterType(node.name) }
    override func visitPost(_ node: ActorDeclSyntax) { typeStack.removeLast() }

    // extension은 타입 선언이 아니므로 타입 단위를 새로 내지 않고, enclosing type 추적만.
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        push(node.extendedType.trimmedDescription)
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let line = converter.location(for: node.name.positionAfterSkippingLeadingTrivia).line
        let internalC = node.body.map { ComplexityCounter.score(of: $0) } ?? 0
        let query = returnsNonVoid(node.signature.returnClause)
        let effects = node.body.map { SideEffectAnalyzer.analyze(body: $0, isQuery: query) }
            ?? .zero
        units.append(
            AnalyzedUnit(
                kind: .method,
                name: node.name.text,
                enclosingType: typeStack.last,
                file: file,
                line: line,
                measurements: .init(
                    internalComplexity: internalC,
                    cqsViolations: query ? effects.cqsViolations : nil,
                    combineRoleMix: effects.combineRoleMix
                )
            )
        )

        var acc = rollupByQualified[currentQualified] ?? (0, 0, 0)
        acc.internal += internalC
        acc.cqs += effects.cqsViolations
        acc.combine += effects.combineRoleMix
        rollupByQualified[currentQualified] = acc

        if isPublicOrOpen(node.modifiers) { addSurface(1) }

        return .visitChildren
    }

    /// 타입 멤버 프로퍼티(로컬 var 제외)의 public/open 표면적 카운트.
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.parent?.is(MemberBlockItemSyntax.self) == true, isPublicOrOpen(node.modifiers) {
            addSurface(node.bindings.count)
        }
        return .visitChildren
    }

    private func isPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.text == "public" || $0.name.text == "open" }
    }

    private func addSurface(_ n: Int) {
        publicSurfaceByQualified[currentQualified, default: 0] += n
    }

    /// post-walk: 정규화 타입별 누적을 타입 유닛에 패치.
    func finalize() {
        for (qualified, index) in typeUnitIndexByQualified {
            if let roll = rollupByQualified[qualified] {
                units[index].measurements.rolledUpInternalComplexity = roll.internal
                units[index].measurements.rolledUpCqsViolations = roll.cqs
                units[index].measurements.rolledUpCombineRoleMix = roll.combine
            }
            units[index].measurements.publicSurface = publicSurfaceByQualified[qualified] ?? 0
        }
    }

    /// 반환 타입이 non-Void면 query (값·Publisher). Void/무반환 = command.
    private func returnsNonVoid(_ clause: ReturnClauseSyntax?) -> Bool {
        guard let type = clause?.type else { return false }
        // 빈 튜플 `()` / `( )` = Void
        if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.isEmpty { return false }
        let name = type.trimmedDescription.replacingOccurrences(of: " ", with: "")
        return name != "Void" && name != "Swift.Void" && name != "()"
    }

    /// 명목 타입 선언(class/struct/enum/actor): 타입 단위 방출 + enclosing 추적.
    private func enterType(_ nameToken: TokenSyntax) -> SyntaxVisitorContinueKind {
        let line = converter.location(for: nameToken.positionAfterSkippingLeadingTrivia).line
        typeUnitIndexByQualified[qualified(nameToken.text)] = units.count
        units.append(
            AnalyzedUnit(
                kind: .type,
                name: nameToken.text,
                enclosingType: typeStack.last,
                file: file,
                line: line
            )
        )
        typeStack.append(nameToken.text)
        return .visitChildren
    }

    private func push(_ name: String) -> SyntaxVisitorContinueKind {
        typeStack.append(name)
        return .visitChildren
    }
}

// MARK: - 내부 복잡도 계산 (분기·중첩 가중)
//
// 규칙 (페이즈 1 고정 v1): 제어흐름 노드마다 (1 + 중첩깊이).
//   - 중첩 구문 (if/guard/for/while/repeat/catch): +1+depth 하고 자기 블록은 depth+1
//   - switch: 점수 없음, depth 불변. 각 case: +1+depth
//   - boolean 연산자·삼항: 페이즈 1 미포함 (후속 정련)

private final class ComplexityCounter: SyntaxVisitor {

    private var depth = 0
    private var total = 0

    static func score(of body: CodeBlockSyntax) -> Int {
        let counter = ComplexityCounter(viewMode: .sourceAccurate)
        counter.walk(body)
        return counter.total
    }

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        // else-if는 SwiftSyntax상 부모 IfExpr의 elseBody로 표현되지만 실제론 형제 분기다.
        // 진짜 중첩처럼 depth를 올리면 사다리가 삼각수로 폭증하므로, 사슬 base 깊이에서
        // 평평하게 +1만 하고 depth는 올리지 않는다.
        if isElseIf(node) {
            total += 1 + max(depth - 1, 0)
            return .visitChildren
        }
        return enterNesting()
    }
    override func visitPost(_ node: IfExprSyntax) {
        if isElseIf(node) { return }
        depth -= 1
    }

    private func isElseIf(_ node: IfExprSyntax) -> Bool {
        node.parent?.is(IfExprSyntax.self) == true
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind { enterNesting() }
    override func visitPost(_ node: ForStmtSyntax) { depth -= 1 }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind { enterNesting() }
    override func visitPost(_ node: WhileStmtSyntax) { depth -= 1 }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind { enterNesting() }
    override func visitPost(_ node: RepeatStmtSyntax) { depth -= 1 }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind { enterNesting() }
    override func visitPost(_ node: GuardStmtSyntax) { depth -= 1 }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind { enterNesting() }
    override func visitPost(_ node: CatchClauseSyntax) { depth -= 1 }

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        total += 1 + depth
        return .visitChildren
    }

    /// 중첩 구문 진입: 점수 가산 + depth 증가.
    private func enterNesting() -> SyntaxVisitorContinueKind {
        total += 1 + depth
        depth += 1
        return .visitChildren
    }
}
