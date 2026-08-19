//
//  DSL.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import Foundation

public protocol StackViewDSL {
    func getDslView() -> UIView?
}
extension StackViewDSL {
    public func getDslView() -> UIView? {
        nil
    }
}

extension UIView: StackViewDSL {
    public func getDslView() -> UIView? {
        self
    }
}
extension Float: StackViewDSL {}
extension Int: StackViewDSL {}
extension Double: StackViewDSL {}
public enum Spacer {
    case normal
    case min(Float)
    case max(Float)
    case value(Float)
    
    public init() {
        self = .normal
    }
    public init(_ value: Float) {
        self = .value(value)
    }
    public init(min: Float) {
        self = .min(min)
    }
    public init(max: Float) {
        self = .max(max)
    }
}
extension Spacer: StackViewDSL {}


public protocol SpacerType {
    var minSpacing: Spacer {get}
    var maxSpacing: Spacer {get}
}

extension Int: SpacerType {
    public var minSpacing: Spacer {
        Spacer.min(Float(self))
    }
    public var maxSpacing: Spacer {
        Spacer.max(Float(self))
    }
}
extension Float: SpacerType {
    public var minSpacing: Spacer {
        Spacer.min(self)
    }
    public var maxSpacing: Spacer {
        Spacer.max(self)
    }
}
extension Double: SpacerType {
    public var minSpacing: Spacer {
        Spacer.min(Float(self))
    }
    public var maxSpacing: Spacer {
        Spacer.max(Float(self))
    }
}

///允许可选类型的view
extension Optional: StackViewDSL where Wrapped: FlexType {
    public func getDslView() -> UIView? {
        switch self {
        case .some(let view):
            return view.baseView
        case .none:
            return nil
        }
    }
}

extension FlexItem: StackViewDSL {}


@resultBuilder
public struct StackViewBuilder {
    public static func buildBlock(
        _ components: [StackViewDSL]...
    ) -> [StackViewDSL] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(
        _ expression: StackViewDSL
    ) -> [StackViewDSL] {
        [expression]
    }
    
    public static func buildOptional(
        _ component: [StackViewDSL]?
    ) -> [StackViewDSL] {
        component ?? []
    }
    
    public static func buildEither(
        first component: [StackViewDSL]
    ) -> [StackViewDSL] {
        component
    }
    
    public static func buildEither(
        second component: [StackViewDSL]
    ) -> [StackViewDSL] {
        component
    }
    
    
    public static func buildArray(
        _ components: [[StackViewDSL]]
    ) -> [StackViewDSL] {
        components.flatMap { $0 }
    }
}
