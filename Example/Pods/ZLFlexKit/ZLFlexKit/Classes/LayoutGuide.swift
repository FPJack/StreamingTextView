//
//  LayoutGuide.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit

class LayoutGuide: UILayoutGuide {
    weak var stackView: UIView? {
        didSet {
            if let stackView = stackView {
                stackView.addLayoutGuide(self)
            } else {
                owningView?.removeLayoutGuide(self)
            }
        }
    }
    
    func removeFromOwningView() {
        owningView?.removeLayoutGuide(self)
    }
}
