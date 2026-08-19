//
//  FlexManager.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit

struct ConstraintWrapper: Hashable {

    let firstItem: AnyObject?
    
    let secondItem: AnyObject?
    
    var firstAttribute: NSLayoutConstraint.Attribute {
        constraint.firstAttribute
    }

    var secondAttribute: NSLayoutConstraint.Attribute {
        constraint.secondAttribute
    }
    
     var relation: NSLayoutConstraint.Relation {
        constraint.relation
    }

     var multiplier: CGFloat {
        constraint.multiplier
    }

    var constant: CGFloat {
        get {
            constraint.constant
        }
        set {
            constraint.constant = newValue
        }
    }
    
    var priority: UILayoutPriority {
        constraint.priority
    }

    
    
    let constraint: NSLayoutConstraint
    init(_ constraint: NSLayoutConstraint) {
        self.firstItem = constraint.firstItem
        self.secondItem = constraint.secondItem
        self.constraint = constraint
    }
    
    
    static func == (lhs: ConstraintWrapper, rhs: ConstraintWrapper) -> Bool {
        return lhs.firstItem === rhs.firstItem &&
            lhs.secondItem === rhs.secondItem &&
            lhs.firstAttribute == rhs.firstAttribute &&
            lhs.secondAttribute == rhs.secondAttribute &&
            lhs.relation == rhs.relation &&
            lhs.multiplier == rhs.multiplier &&
            lhs.constant == rhs.constant &&
            lhs.priority == rhs.priority
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(firstAttribute)
        hasher.combine(secondAttribute)
        hasher.combine(relation)
        hasher.combine(multiplier)
        hasher.combine(constant)
        hasher.combine(priority)
        hasher.combine(firstItem.map(ObjectIdentifier.init))
        hasher.combine(secondItem.map(ObjectIdentifier.init))
    }
}


final class FlexManager {

    weak var stackView: StackView?
    
    private var justifyFirstConstraints: NSLayoutConstraint?
    private var justifyLastConstraints: NSLayoutConstraint?
    
    private(set) var constraints: [ConstraintWrapper] = []
    
    private(set) var preConstraints: [ConstraintWrapper] = []
        
    // MARK: - Private lazy StackEdgeInsets

    lazy private var stackLayoutEngine: StackLayoutEngine =  {
        let insets = StackLayoutEngine()
        insets.stackView = self.stackView
        return insets
    }()

    // MARK: - Convenience accessors

    private var views: [UIView] {
        stackView?.arrangedViews ?? []
    }

    private var justify: Justify {
        stackView?.justifyContent ?? .fill
    }

    private var align: FlexItemCrossAlign {
        stackView?.alignment ?? .center
    }

    private var horizontal: Bool {
        stackView?.axis == .horizontal
    }
    
    ///开启刷新优化
    private var enableRefreshOptimization: Bool = false

    // MARK: - Layout

    func removeAllSpacing() {
        stackLayoutEngine.removeEdgeInsets()
        stackView?.layoutGuides
            .compactMap { $0 as? LayoutGuide }
            .forEach { $0.removeFromOwningView() }
    }

    // MARK: - Horizontal

    func addHorizontalLayoutConstraints() {
        guard horizontal else { return }
        if enableRefreshOptimization {
            preConstraints.removeAll()
            preConstraints.append(contentsOf: constraints)
            constraints.removeAll()
        }
       
        let views = self.views
        let count = views.count
        var nextXAnchor:  NSLayoutXAxisAnchor = stackLayoutEngine.jLeadingAnchor
        var widthDim:     NSLayoutDimension?   // for spaceBetween/Around/Evenly
        var viewWidthDim: NSLayoutDimension?   // for fillEqually
        var flexWidthDim: NSLayoutDimension?   // for flex spaces
        var flexViews:    [UIView] = []

        let fittingLow = UILayoutPriority(rawValue: UILayoutPriority.fittingSizeLevel.rawValue / 2.0)
        
        let noIntrinsic = CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        let insets = stackView?.insets ?? .zero
        var leadingMarge = 0.0
        var preTrailingMarge = 0.0
        for i in 0 ..< count {
            let view = views[i]
            view.translatesAutoresizingMaskIntoConstraints = false

            // 垂直方向设置低优先级高度约束防止过度压缩
            if align != .fill, view.intrinsicContentSize == noIntrinsic {
                let c = view.heightAnchor.constraint(equalToConstant: 0)
                c.priority = fittingLow
                addConstraint(c)
            }

            let cfg = view.flex
            if cfg.flex > 0, justify != .fillEqually {
                flexViews.append(view)
            }
            let marge = cfg.margin
            let startSpacing = marge.top
            let endSpacing   = marge.bottom
            let spacing      = cfg.spacing
            leadingMarge = marge.leading

            // 交叉轴约束
            addCrossAxisConstraints(
                for: view, cfg: cfg,
                startSpacing: startSpacing + insets.top, endSpacing: endSpacing + insets.bottom,
                startAnchor: stackLayoutEngine.topAnchor,
                endAnchor:   stackLayoutEngine.bottomAnchor,
                centerAnchor: stackLayoutEngine.centerYAnchor,
                mainAxis: .horizontal
            )

            // 主轴起始约束
            let leadingCon: NSLayoutConstraint
            
            if i == 0 {
                if justify == .end {
                    leadingCon = view.leadingAnchor.constraint(greaterThanOrEqualTo: nextXAnchor, constant: insets.leading + leadingMarge)
                }else {
                    leadingCon = view.leadingAnchor.constraint(equalTo: nextXAnchor, constant: insets.leading + leadingMarge)
                }
                justifyFirstConstraints = leadingCon
            }else {
                leadingCon = view.leadingAnchor.constraint(equalTo: nextXAnchor, constant: preTrailingMarge + leadingMarge)
            }
            
            addConstraint(leadingCon)
            nextXAnchor = view.trailingAnchor
            preTrailingMarge = marge.trailing

            // fillEqually: 宽度相等
            if justify == .fillEqually {
                if let dim = viewWidthDim {
                    addConstraint(view.widthAnchor.constraint(equalTo: dim))
                }
                viewWidthDim = view.widthAnchor
            }

            // fill / fillEqually: 弹性空间
            if (justify == .fill || justify == .fillEqually), cfg.isFlexibleSpace {
                let guide = LayoutGuide()
                guide.stackView = stackView
                let cons = guide.leadingAnchor.constraint(equalTo: nextXAnchor,constant: preTrailingMarge)
                nextXAnchor = guide.trailingAnchor
                preTrailingMarge = 0.0
                addConstraint(cons)

                
                
                addConstraint(guide.widthAnchor.constraint(greaterThanOrEqualToConstant: 0))
                if let dim = flexWidthDim {
                    addConstraint(dim.constraint(equalTo: guide.widthAnchor))
                }
                flexWidthDim = guide.widthAnchor
            }

            // start / end / center / fill / fillEqually: 固定间距
            let spacingCases: [Justify] = [.start, .end, .center, .fill, .fillEqually]
            if spacingCases.contains(justify), i < count - 1 {
                if spacing >= 0 || cfg._minSpacing > 0 || cfg._maxSpacing > 0 {
                    let guide = LayoutGuide()
                    guide.stackView = stackView
                    let cons = guide.leadingAnchor.constraint(equalTo: nextXAnchor,constant: preTrailingMarge)
                    addConstraint(cons)
                    nextXAnchor = guide.trailingAnchor
                    preTrailingMarge = 0.0

                    var spacingFlag = true
                    if cfg._minSpacing > 0 {
                        let c1 = guide.widthAnchor.constraint(greaterThanOrEqualToConstant: cfg._minSpacing)
                        c1.item.type = .minSpacing; c1.item.view = view
                        addConstraint(c1)
                        let c2 = guide.widthAnchor.constraint(equalToConstant: cfg._minSpacing)
                        c2.item.type = .minSpacing; c2.item.view = view
                        c2.priority = fittingLow
                        addConstraint(c2)
                        if spacing < cfg._minSpacing { spacingFlag = false }
                    }
                    if cfg._maxSpacing > 0 {
                        let c1 = guide.widthAnchor.constraint(lessThanOrEqualToConstant: cfg._maxSpacing)
                        c1.item.type = .maxSpacing; c1.item.view = view
                        addConstraint(c1)
                        let c2 = guide.widthAnchor.constraint(equalToConstant: 0)
                        c2.item.type = .maxSpacing; c2.item.view = view
                        c2.priority = fittingLow
                        addConstraint(c2)
                        if spacing > cfg._maxSpacing { spacingFlag = false }
                    }
                    if spacingFlag, spacing >= 0 {
                        let c = guide.widthAnchor.constraint(equalToConstant: spacing)
                        c.item.type = .spacing; c.item.view = view
                        addConstraint(c)
                    }
                }
            }

            // spaceBetween / spaceAround / spaceEvenly: 均等间距
            if [.spaceBetween, .spaceAround, .spaceEvenly].contains(justify), i < count - 1 {
                let guide = LayoutGuide()
                guide.stackView = stackView
                let cons = guide.leadingAnchor.constraint(equalTo: nextXAnchor,constant: preTrailingMarge)
                addConstraint(cons)
                nextXAnchor = guide.trailingAnchor
                preTrailingMarge = 0.0
                if let dim = widthDim {
                    addConstraint(guide.widthAnchor.constraint(equalTo: dim))
                }
                widthDim = guide.widthAnchor
                
            }
        }

        // 末尾约束
        if justify == .start {
            addConstraint(nextXAnchor.constraint(lessThanOrEqualTo: stackLayoutEngine.jTrailingAnchor, constant: -insets.trailing - preTrailingMarge))
        } else {
            addConstraint(nextXAnchor.constraint(equalTo: stackLayoutEngine.jTrailingAnchor, constant: -insets.trailing - preTrailingMarge))
        }
        
        justifyLastConstraints = constraints.last?.constraint

       

        // spaceAround / spaceEvenly 边距关系
        if let dim = widthDim {
            let anchors = stackLayoutEngine.widthAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
                if justify == .spaceAround {
                    addConstraint(first.constraint(equalTo: dim, multiplier: 0.5))
                } else if justify == .spaceEvenly {
                    addConstraint(first.constraint(equalTo: dim))
                }
            }
        }

        // center justify 两边宽度相等
        if justify == .center || ([.spaceAround, .spaceEvenly].contains(justify) && count == 1){
            let anchors = stackLayoutEngine.widthAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
            }
        }

        // align center 上下高度相等
        if align == .center {
            let anchors = stackLayoutEngine.heightAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
            }
        }

        // flex 相对宽度权重
        applyFlexWeights(flexViews, axis: .horizontal)
    }

    // MARK: - Vertical

    func addVerticalLayoutConstraints() {
        guard !horizontal else { return }
        if enableRefreshOptimization {
            preConstraints.removeAll()
            preConstraints.append(contentsOf: constraints)
            constraints.removeAll()
        }
       
        let views = self.views
        let count = views.count
        var nextYAnchor: NSLayoutYAxisAnchor = stackLayoutEngine.jTopAnchor
        var heightDim:     NSLayoutDimension?
        var viewHeightDim: NSLayoutDimension?
        var flexHeightDim: NSLayoutDimension?
        var flexViews:     [UIView] = []

        let fittingLow = UILayoutPriority(rawValue: UILayoutPriority.fittingSizeLevel.rawValue / 2.0)
        let noIntrinsic = CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        let insets = stackView?.insets ?? .zero
        var topMarge = 0.0
        var preBottomMarge = 0.0
        for i in 0 ..< count {
            let view = views[i]
            view.translatesAutoresizingMaskIntoConstraints = false

            // 水平方向低优先级宽度约束
            if align != .fill, view.intrinsicContentSize == noIntrinsic {
                let c = view.widthAnchor.constraint(equalToConstant: 0)
                c.priority = fittingLow
                addConstraint(c)
            }

            let cfg = view.flex
            if cfg.flex > 0, justify != .fillEqually {
                flexViews.append(view)
            }
            let marge = cfg.margin
            let startSpacing = marge.leading
            let endSpacing   = marge.trailing
            let spacing      = cfg.spacing
            topMarge = marge.top

            // 交叉轴约束
            addCrossAxisConstraints(
                for: view, cfg: cfg,
                startSpacing: startSpacing + insets.leading, endSpacing: endSpacing + insets.trailing,
                startAnchor: stackLayoutEngine.leadingAnchor,
                endAnchor:   stackLayoutEngine.trailingAnchor,
                centerAnchor: stackLayoutEngine.centerXAnchor,
                mainAxis: .vertical
            )

            // 主轴起始约束
            let topCon: NSLayoutConstraint
            
            if i == 0 {
                if justify == .end {
                    topCon = view.topAnchor.constraint(greaterThanOrEqualTo: nextYAnchor, constant: insets.top + topMarge)
                }else {
                    topCon = view.topAnchor.constraint(equalTo: nextYAnchor, constant: insets.top + topMarge)
                }
                justifyFirstConstraints = topCon
            }else {
                topCon = view.topAnchor.constraint(equalTo: nextYAnchor, constant: preBottomMarge + topMarge)
            }
            
            addConstraint(topCon)
            nextYAnchor = view.bottomAnchor
            preBottomMarge = marge.bottom

            // fillEqually: 高度相等
            if justify == .fillEqually {
                if let dim = viewHeightDim {
                    addConstraint(view.heightAnchor.constraint(equalTo: dim))
                }
                viewHeightDim = view.heightAnchor
            }

            // fill / fillEqually: 弹性空间
            if (justify == .fill || justify == .fillEqually), cfg.isFlexibleSpace {
                let guide = LayoutGuide()
                guide.stackView = stackView
                addConstraint(guide.topAnchor.constraint(equalTo: nextYAnchor,constant: preBottomMarge))
                nextYAnchor = guide.bottomAnchor
                preBottomMarge = 0.0
                addConstraint(guide.heightAnchor.constraint(greaterThanOrEqualToConstant: 0))
                if let dim = flexHeightDim {
                    addConstraint(dim.constraint(equalTo: guide.heightAnchor))
                }
                flexHeightDim = guide.heightAnchor
            }

            // start / end / center / fill / fillEqually: 固定间距
            let spacingCases: [Justify] = [.start, .end, .center, .fill, .fillEqually]
            if spacingCases.contains(justify), i < count - 1 {
                if spacing >= 0 || cfg._minSpacing > 0 || cfg._maxSpacing > 0 {
                    let guide = LayoutGuide()
                    guide.stackView = stackView
                    addConstraint(guide.topAnchor.constraint(equalTo: nextYAnchor,constant: preBottomMarge))
                    nextYAnchor = guide.bottomAnchor
                    preBottomMarge = 0.0

                    var spacingFlag = true
                    if cfg._minSpacing > 0 {
                        let c1 = guide.heightAnchor.constraint(greaterThanOrEqualToConstant: cfg._minSpacing)
                        c1.item.type = .minSpacing; c1.item.view = view
                        addConstraint(c1)
                        let c2 = guide.heightAnchor.constraint(equalToConstant: cfg._minSpacing)
                        c2.item.type = .minSpacing; c2.item.view = view
                        c2.priority = fittingLow
                        addConstraint(c2)
                        if spacing < cfg._minSpacing { spacingFlag = false }
                    }
                    if cfg._maxSpacing > 0 {
                        let c1 = guide.heightAnchor.constraint(lessThanOrEqualToConstant: cfg._maxSpacing)
                        c1.item.type = .maxSpacing; c1.item.view = view
                        addConstraint(c1)
                        let c2 = guide.heightAnchor.constraint(equalToConstant: 0)
                        c2.item.type = .maxSpacing; c2.item.view = view
                        c2.priority = fittingLow
                        addConstraint(c2)
                        if spacing > cfg._maxSpacing { spacingFlag = false }
                    }
                    if spacingFlag, spacing >= 0 {
                        let c = guide.heightAnchor.constraint(equalToConstant: spacing)
                        c.item.type = .spacing; c.item.view = view
                        addConstraint(c)
                    }
                }
            }

            // spaceBetween / spaceAround / spaceEvenly: 均等间距
            if [.spaceBetween, .spaceAround, .spaceEvenly].contains(justify), i < count - 1 {
                let guide = LayoutGuide()
                guide.stackView = stackView
                addConstraint(guide.topAnchor.constraint(equalTo: nextYAnchor,constant: preBottomMarge))
                nextYAnchor = guide.bottomAnchor
                preBottomMarge = 0.0
                if let dim = heightDim {
                    addConstraint(guide.heightAnchor.constraint(equalTo: dim))
                }
                heightDim = guide.heightAnchor
            }
        }

        // 末尾约束
        if justify == .start {
            addConstraint(nextYAnchor.constraint(lessThanOrEqualTo: stackLayoutEngine.jBottomAnchor, constant: -insets.bottom - preBottomMarge))
        } else {
            addConstraint(nextYAnchor.constraint(equalTo: stackLayoutEngine.jBottomAnchor, constant: -insets.bottom - preBottomMarge))
        }
        justifyLastConstraints = constraints.last?.constraint

        // spaceAround / spaceEvenly 边距关系
        if let dim = heightDim {
            let anchors = stackLayoutEngine.heightAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
                if justify == .spaceAround {
                    addConstraint(first.constraint(equalTo: dim, multiplier: 0.5))
                } else if justify == .spaceEvenly {
                    addConstraint(first.constraint(equalTo: dim))
                }
            }
        }

        // center justify 上下高度相等
        if justify == .center || ([.spaceAround, .spaceEvenly].contains(justify) && count == 1) {
            let anchors = stackLayoutEngine.heightAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
            }
        }

        // align center 左右宽度相等
        if align == .center {
            let anchors = stackLayoutEngine.widthAnchors
            if let first = anchors.first, let last = anchors.last {
                addConstraint(first.constraint(equalTo: last))
            }
        }

        // flex 相对高度权重
        applyFlexWeights(flexViews, axis: .vertical)
    }
    
    func addConstraint(_ constraint: NSLayoutConstraint) {
        constraints.append(ConstraintWrapper(constraint))
    }

    // MARK: - Constraint Control

    func activateConstraints() {
        if enableRefreshOptimization {
            if preConstraints.isEmpty {
                NSLayoutConstraint.activate(constraints.map{$0.constraint})
            }else {
                let preConstraintsSet = Set(preConstraints)
                let constraintsSet = Set(constraints)
                
                let constraintsToDeactivate = preConstraintsSet.subtracting(constraintsSet)
                let constraintsToActivate = constraintsSet.subtracting(preConstraintsSet)
                
                NSLayoutConstraint.deactivate(constraintsToDeactivate.map{$0.constraint})
                NSLayoutConstraint.activate(constraintsToActivate.map{$0.constraint})
                
                constraints.removeAll()
                constraints.append(contentsOf: preConstraintsSet.intersection(constraintsSet))
                constraints.append(contentsOf: constraintsToActivate)
                preConstraints.removeAll()
            }

        } else {
           NSLayoutConstraint.activate(constraints.map{$0.constraint})
        }
        
    }

    func deactivateConstraints() {
        if !enableRefreshOptimization {
            NSLayoutConstraint.deactivate(constraints.map{$0.constraint})
            constraints.removeAll()
        }
    }

    // MARK: - Insets
    func updateInsets(_ preInsets: NSDirectionalEdgeInsets, _ insets: NSDirectionalEdgeInsets) {
        do { ///更新主轴起始/末尾约束常量
            let preFirstInset = horizontal ? preInsets.leading : preInsets.top
            let preLastInset = horizontal ? preInsets.trailing : preInsets.bottom
            let firstInset = horizontal ? insets.leading : insets.top
            let lastInset = horizontal ? insets.trailing : insets.bottom
            
            if let first = justifyFirstConstraints {
                first.constant = first.constant - preFirstInset + firstInset
            }
            if let last = justifyLastConstraints {
                last.constant = last.constant + preLastInset - lastInset
            }
        }
        do {
            let startMarge = horizontal ? insets.top : insets.leading
            let endMarge = horizontal ? insets.bottom : insets.trailing
            let constraints = constraints.map { $0.constraint }
            constraints.forEach { cons in
                guard let view = cons.item.view else { return }
                let flexItem = view.flex
                let marge = flexItem.margin
                let type = cons.item.type
                if type == .start {
                    if horizontal {
                        cons.constant = startMarge + marge.top
                    } else {
                        cons.constant = startMarge + marge.leading
                    }
                } else if type == .end {
                    if horizontal {
                        cons.constant = -(endMarge + marge.bottom)
                    } else {
                        cons.constant = -(endMarge + marge.trailing)
                    }
                } else if type == .center {
                    let startSpacing = horizontal ? startMarge + marge.top : startMarge + marge.leading
                    let endSpacing   = horizontal ? endMarge + marge.bottom : endMarge + marge.trailing
                    cons.constant = (startSpacing - endSpacing) * 1
                }
            }
        }
        
    }

   
    // MARK: - Private helpers

    /// 交叉轴方向对齐约束（horizontal 时处理垂直方向，vertical 时处理水平方向）
    private func addCrossAxisConstraints(
        for view: UIView,
        cfg: FlexItem,
        startSpacing: CGFloat,
        endSpacing: CGFloat,
        startAnchor: NSLayoutYAxisAnchor,
        endAnchor: NSLayoutYAxisAnchor,
        centerAnchor: NSLayoutYAxisAnchor,
        mainAxis: NSLayoutConstraint.Axis
    ) {
        func make(_ c: NSLayoutConstraint, type: LayoutConType) -> NSLayoutConstraint {
            c.item.type = type; c.item.view = view; return c
        }
        switch cfg.alignSelf {
        case .start:
            addConstraint(make(view.topAnchor.constraint(equalTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.bottomAnchor.constraint(lessThanOrEqualTo: endAnchor, constant: -endSpacing), type: .end))
        case .center:
            let offsetY = (startSpacing - endSpacing) * 1
            addConstraint(make(view.topAnchor.constraint(greaterThanOrEqualTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.bottomAnchor.constraint(lessThanOrEqualTo: endAnchor, constant: -endSpacing), type: .end))
            addConstraint(make(view.centerYAnchor.constraint(equalTo: centerAnchor, constant: offsetY), type: .center))
        case .end:
            addConstraint(make(view.topAnchor.constraint(greaterThanOrEqualTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.bottomAnchor.constraint(equalTo: endAnchor, constant: -endSpacing), type: .end))
        case .fill:
            addConstraint(make(view.topAnchor.constraint(equalTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.bottomAnchor.constraint(equalTo: endAnchor, constant: -endSpacing), type: .end))
        @unknown default:
            break
        }
    }

    /// 垂直方向交叉轴约束（vertical 主轴时，对水平方向处理）
    private func addCrossAxisConstraints(
        for view: UIView,
        cfg: FlexItem,
        startSpacing: CGFloat,
        endSpacing: CGFloat,
        startAnchor: NSLayoutXAxisAnchor,
        endAnchor: NSLayoutXAxisAnchor,
        centerAnchor: NSLayoutXAxisAnchor,
        mainAxis: NSLayoutConstraint.Axis
    ) {
        func make(_ c: NSLayoutConstraint, type: LayoutConType) -> NSLayoutConstraint {
            c.item.type = type; c.item.view = view; return c
        }
        switch cfg.alignSelf {
        case .start:
            addConstraint(make(view.leadingAnchor.constraint(equalTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.trailingAnchor.constraint(lessThanOrEqualTo: endAnchor, constant: -endSpacing), type: .end))
        case .center:
            let offsetX = (startSpacing - endSpacing) * 1
            addConstraint(make(view.leadingAnchor.constraint(greaterThanOrEqualTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.trailingAnchor.constraint(lessThanOrEqualTo: endAnchor, constant: -endSpacing), type: .end))
            addConstraint(make(view.centerXAnchor.constraint(equalTo: centerAnchor, constant: offsetX), type: .center))
        case .end:
            addConstraint(make(view.leadingAnchor.constraint(greaterThanOrEqualTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.trailingAnchor.constraint(equalTo: endAnchor, constant: -endSpacing), type: .end))
        case .fill:
            addConstraint(make(view.leadingAnchor.constraint(equalTo: startAnchor, constant: startSpacing), type: .start))
            addConstraint(make(view.trailingAnchor.constraint(equalTo: endAnchor, constant: -endSpacing), type: .end))
        @unknown default:
            break
        }
    }

    /// 应用 flex 相对权重约束
    private func applyFlexWeights(_ flexViews: [UIView], axis: NSLayoutConstraint.Axis) {
        guard let firstView = flexViews.first else { return }
        let firstDim: NSLayoutDimension = axis == .horizontal
            ? firstView.widthAnchor : firstView.heightAnchor
        let firstFlex = CGFloat(firstView.flex.flex)
        guard firstFlex > 0 else { return }
        let hugging     = UILayoutPriority(rawValue: UILayoutPriority.defaultLow.rawValue - 1)
        let compression = UILayoutPriority(rawValue: UILayoutPriority.defaultHigh.rawValue - 1)
        for (i, view) in flexViews.enumerated() {
            view.setContentHuggingPriority(hugging, for: axis)
            view.setContentCompressionResistancePriority(compression, for: axis)
            guard i > 0 else { continue }
            let dim: NSLayoutDimension = axis == .horizontal
                ? view.widthAnchor : view.heightAnchor
            let multiplier = CGFloat(view.flex.flex) / firstFlex
            addConstraint(dim.constraint(equalTo: firstDim, multiplier: multiplier))
        }
    }
}
