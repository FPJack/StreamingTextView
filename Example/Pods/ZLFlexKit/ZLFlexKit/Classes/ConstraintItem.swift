//
//  ConstraintItem.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit
@objc(ZLLayoutConType)
public enum LayoutConType: Int {
    case none
    case start
    case end
    case center
    case top
    case bottom
    case leading
    case trailing
    case spacing
    case minSpacing
    case maxSpacing
}
@objc(ZLConstraintItem)
public class ConstraintItem: NSObject {

    public var type: LayoutConType = .none

    weak var view: UIView?
}


import ObjectiveC.runtime

private var itemKey: UInt8 = 0

extension NSLayoutConstraint {

    public var item: ConstraintItem {

        if let obj = objc_getAssociatedObject(self, &itemKey) as? ConstraintItem {
            return obj
        }

        let obj = ConstraintItem()
        objc_setAssociatedObject(
            self,
            &itemKey,
            obj,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return obj
    }
}
