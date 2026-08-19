//
//  EdgeInsetsDS.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/16.
//

import Foundation
public struct EdgeInsets: Equatable {

    public var t: CGFloat
    public var s: CGFloat
    public var b: CGFloat
    public var e: CGFloat

    public init(
        t: CGFloat,
        s: CGFloat,
        b: CGFloat,
        e: CGFloat
    ) {
        self.t = t
        self.s = s
        self.b = b
        self.e = e
    }
}



public extension EdgeInsets {

    var directionalEdgeInsets: NSDirectionalEdgeInsets {
        .init(
            top: t,
            leading: s,
            bottom: b,
            trailing: e
        )
    }

    init(_ ns: NSDirectionalEdgeInsets) {
        self.init(
            t: ns.top,
            s: ns.leading,
            b: ns.bottom,
            e: ns.trailing
        )
    }
}

public extension EdgeInsets {
    
    static var zero: EdgeInsets {
        .init(t: 0, s: 0, b: 0, e: 0)
    }

    static func all(_ value: CGFloat) -> Self {
        .init(t: value, s: value, b: value, e: value)
    }
    
    static func vertical(_ value: CGFloat) -> Self {
        .init(t: value, s: 0, b: value, e: 0)
    }

    static func horizontal(_ value: CGFloat) -> Self {
        .init(t: 0, s: value, b: 0, e: value)
    }
    
    static func top(_ value: CGFloat) -> Self {
        .init(t: value, s: 0, b: 0, e: 0)
    }

    static func bottom(_ value: CGFloat) -> Self {
        .init(t: 0, s: 0, b: value, e: 0)
    }

    static func start(_ value: CGFloat) -> Self {
        .init(t: 0, s: value, b: 0, e: 0)
    }

    static func end(_ value: CGFloat) -> Self {
        .init(t: 0, s: 0, b: 0, e: value)
    }
}

