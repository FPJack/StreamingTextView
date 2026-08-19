//
//  FlexItem.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit
import ObjectiveC

@objc(ZLFlexItemCrossAlign)
public enum FlexItemCrossAlign: Int {
    case center
    case start
    case end
    case fill
}


@objc(ZLFlexItem)
public  class FlexItem: NSObject {
    private var observation: NSKeyValueObservation?
    
    
    /// 弹性view
    @objc
    public  weak var view: UIView? {
        didSet {
            guard observation == nil else { return }
            observation = view?.observe(\.isHidden, options: [.new, .old]) {[weak self] view, change in
                guard let self = self else { return }
                if let newValue = change.newValue,
                    let oldValue = change.oldValue,
                    newValue != oldValue {
                    self.setStackViewNeedsUpdateConstraints()
                }
            }
        }
    }
    
    
    
    
    /// 所在的StackView
    public weak var stackView: StackView?
    
    
    private var _margin: NSDirectionalEdgeInsets = .zero
    
    /// 外边距
    public var margin: NSDirectionalEdgeInsets {
        get {
            _margin
        }
        set {
            guard _margin != newValue else { return }
            if _margin.leading != newValue.leading {
                updateLeadMarge(_margin.leading, newValue.leading)
            }
            if _margin.trailing != newValue.trailing {
                updateTrailMarge(_margin.trailing, newValue.trailing)
            }
            if _margin.top != newValue.top {
                updateTopMarge(_margin.top, newValue.top)
            }
            if _margin.bottom != newValue.bottom {
                updateBottomMarge(_margin.bottom, newValue.bottom)
            }
            _margin = newValue
            updateCenterOffset()
        }
    }
    private func updateLeadMarge(_ preMarge: CGFloat,_ marge: CGFloat) {
        let arr = filterConstraint { constraint in
            return constraint.firstItem === view && constraint.firstAttribute == .leading && (constraint.relation == .equal || constraint.relation == .greaterThanOrEqual)
        }
        if var cons = arr?.first {
            cons.constant = cons.constant - preMarge + marge
        }else {
            setStackViewNeedsUpdateConstraints()
        }
    }
    private func updateTrailMarge(_ preMarge: CGFloat,_ marge: CGFloat) {
        let arr = filterConstraint { constraint in
            let relation = constraint.relation
            let res1 = constraint.secondItem === view && constraint.secondAttribute == .trailing && (relation == .equal || relation == .greaterThanOrEqual)
            if res1 {
                return true
            }
            let res2 = constraint.firstItem === view && constraint.firstAttribute == .trailing && (relation == .equal || relation == .lessThanOrEqual)
            if res2 {
                return true
            }
            return false
        }
        if var constraint = arr?.first {
            let relation = constraint.relation
            if constraint.firstItem === view && constraint.firstAttribute == .trailing && (relation == .equal || relation == .lessThanOrEqual) {
                    constraint.constant = constraint.constant + preMarge - marge
            }else {
                if stackView?.axis == .vertical {
                    constraint.constant = constraint.constant + preMarge - marge
                }else {
                    constraint.constant = constraint.constant - preMarge + marge
                }
            }
        }else {
            setStackViewNeedsUpdateConstraints()
        }
    }
    private func updateTopMarge(_ preMarge: CGFloat,_ marge: CGFloat) {
        let arr = filterConstraint { constraint in
            return constraint.firstItem === view && constraint.firstAttribute == .top && (constraint.relation == .equal || constraint.relation == .greaterThanOrEqual)
        }
        if var cons = arr?.first {
            cons.constant = cons.constant - preMarge + marge
        }else {
            setStackViewNeedsUpdateConstraints()
        }
    }
    private func updateBottomMarge(_ preMarge: CGFloat,_ marge: CGFloat) {
        let arr = filterConstraint { constraint in
            let relation = constraint.relation
            let res1 = constraint.secondItem === view && constraint.secondAttribute == .bottom && (relation == .equal || relation == .greaterThanOrEqual)
            if res1 {
                return true
            }
            let res2 = constraint.firstItem === view && constraint.firstAttribute == .bottom && (relation == .equal || relation == .lessThanOrEqual)
            if res2 {
                return true
            }
            return false
        }
        if var constraint = arr?.first {
            let relation = constraint.relation
            if constraint.firstItem === view && constraint.firstAttribute == .bottom && (relation == .equal || relation == .lessThanOrEqual) {
                constraint.constant = constraint.constant + preMarge - marge
            }else {
                if stackView?.axis == .horizontal {
                    constraint.constant = constraint.constant + preMarge - marge
                }else {
                    constraint.constant = constraint.constant - preMarge + marge
                }
            }
        }else {
            setStackViewNeedsUpdateConstraints()
        }
    }
    private func updateCenterOffset() {
        guard let axis = stackView?.axis,let align = stackView?.alignment else { return }
        let inset = stackView?.insets ?? .zero
        guard align == .center else { return }
        if axis == .horizontal {
            let arr = filterConstraint { cons in
                return cons.firstItem === view && cons.firstAttribute == .centerY && cons.relation == .equal
            }
            if var cons = arr?.first {
                cons.constant = (margin.top + inset.top - margin.bottom - inset.bottom) * 0.5
            }
        }else {
            let arr = filterConstraint { cons in
                return cons.firstItem === view && cons.firstAttribute == .centerX && cons.relation == .equal
            }
            if var cons = arr?.first {
                cons.constant = (margin.leading + inset.leading - margin.trailing - inset.trailing) * 0.5
            }
        }
    }
    
    
    var _spacing: CGFloat = 0
    
    ///  view后面的间距
    public var spacing: CGFloat {
        get {_spacing > 0 ? _spacing : stackView?.spacing ?? 0 }
        set {
            let oldValue = spacing
            _spacing = newValue
            if oldValue != newValue {
                setStackViewNeedsUpdateConstraints()
            }
        }
    }
    
    var _minSpacing: CGFloat = 0
    
    /// view后面的最小间距
    public var minSpacing: CGFloat {
        get {_minSpacing }
        set {
            let oldValue = minSpacing
            _minSpacing = newValue
            if oldValue != newValue {
                setStackViewNeedsUpdateConstraints()
            }
        }
    }
    
    var _maxSpacing: CGFloat = 0
    
    ///  view后面的最大间距
    public var maxSpacing: CGFloat  {
        get { _maxSpacing }
        set {
            let oldValue = maxSpacing
            _maxSpacing = newValue
            if oldValue != newValue {
                setStackViewNeedsUpdateConstraints()
            }
        }
    }
    
    
    /// view后面是否是弹性空间，弹性空间没有view，只有间距，且会占用剩余空间
    public var isFlexibleSpace: Bool = false {
        didSet {
            guard isFlexibleSpace != oldValue else { return }
            setStackViewNeedsUpdateConstraints()
        }
    }
    
    
    
    /// 弹性系数，默认为0，值越大占用剩余空间越多，flex为0表示自适应
    public var flex: Int = 0 {
        didSet {
            guard flex != oldValue else { return }
            setStackViewNeedsUpdateConstraints()
        }
    }
    
    private var isSetAlign = false
    
    private var _alignSelf: FlexItemCrossAlign?
    
    
    /// 单个item的对齐方式，默认为nil，表示跟随StackView的alignment属性
    public var alignSelf: FlexItemCrossAlign {
        get {
            _alignSelf ?? (stackView?.alignment ?? .center)
        }
        set {
            isSetAlign = true
            
            let oldValue = alignSelf
            
            _alignSelf = newValue
            
            if oldValue != newValue {
                setStackViewNeedsUpdateConstraints()
            }
        }
    }
    
    
    
    /// view的高度，默认为0，表示自适应
    public var height: CGFloat = -1 {
        didSet {
            view?.box.height(height)
        }
    }
    
    
    /// view的宽度，
    public var width: CGFloat = 0 {
        didSet {
            view?.box.width(width)
        }
    }
    
    
    
    /// view的最小宽度
    public var minWidth: CGFloat = 0 {
        didSet {
            view?.box.minWidth(minWidth)
        }
    }
    
    
    /// view的最大宽度
    public var maxWidth: CGFloat = 0 {
        didSet {
            view?.box.maxWidth(maxWidth)
        }
    }
    
    
    ///  view的最小高度
    public var minHeight: CGFloat = 0 {
        didSet {
            view?.box.minHeight(minHeight)
        }
    }
    
    
    /// view的最大高度
    public var maxHeight: CGFloat = 0 {
        didSet {
            view?.box.maxHeight(maxHeight)
        }
    }
    
    
    /// view的大小，width和height同时设置时生效
    public var size: CGSize = .zero {
        didSet {
            view?.box.size(w: size.width, h: size.height)
        }
    }
    
    
    public override init() {
        super.init()
        minSpacing = -2
        maxSpacing = -2
    }
    
   
    
    
    /// 设置view后面的间距，默认跟随StackView的spacing属性
    /// - Parameter spacing: <#spacing description#>
    /// - Returns: <#description#>
    @discardableResult
    public func spacing(_ spacing: NumberConvertible) -> Self {
        self.spacing = spacing.cgFloat
        return self
    }
    
    
    /// 设置item的对齐方式，默认跟随StackView的alignment属性
    /// - Parameter align: <#align description#>
    /// - Returns: <#description#>
    @discardableResult
    public func align(_ align: FlexItemCrossAlign) -> Self {
        self.alignSelf = align
        return self
    }
    
    
    /// 设置外边距，默认值为.zero
    /// - Parameter margin: <#margin description#>
    /// - Returns: <#description#>
    @discardableResult
    public func margin(_ margin: EdgeInsets) -> Self {
        self.margin = margin.directionalEdgeInsets
        return self
    }
    
    
   
    
    
    /// 设置view后面的最小间距，默认跟随StackView的spacing属性
    /// - Parameter spacing: <#spacing description#>
    /// - Returns: <#description#>
    @discardableResult
    public func minSpacing(_ spacing: NumberConvertible) -> Self {
        self.minSpacing = spacing.cgFloat
        return self
    }
    
    
    /// 设置view后面的最大间距，默认跟随StackView的spacing属性
    /// - Parameter spacing: <#spacing description#>
    /// - Returns: <#description#>
    @discardableResult
    public func maxSpacing(_ spacing: NumberConvertible) -> Self {
        self.maxSpacing = spacing.cgFloat
        return self
    }
    
    
    ///  设置view后面是否是弹性空间，弹性空间没有view，只有间距，且会占用剩余空间
    /// - Parameter isFlex: <#isFlex description#>
    /// - Returns: <#description#>
    @discardableResult
    public func isFlexibleSpace(_ isFlex: Bool) -> Self {
        self.isFlexibleSpace = isFlex
        return self
    }
    
    
    /// 设置弹性系数，默认为0，值越大占用剩余空间越多，flex为0表示自适应
    /// - Parameter value: <#value description#>
    /// - Returns: <#description#>
    @discardableResult
    public func flex(_ value: Int) -> Self {
        self.flex = value
        return self
    }
    
    
    /// 设置view的高度，默认为0，表示自适应
    /// - Parameter height: <#height description#>
    /// - Returns: <#description#>
    @discardableResult
    public func height(_ height: NumberConvertible) -> Self {
        self.height = height.cgFloat
        return self
    }
    
    
    ///  设置view的宽度，默认为0，表示自适应
    /// - Parameter width: <#width description#>
    /// - Returns: <#description#>
    @discardableResult
    public func width(_ width: NumberConvertible) -> Self {
        self.width = width.cgFloat
        return self
    }
    
    
    /// 设置view的最小宽度，
    /// - Parameter width: <#width description#>
    /// - Returns: <#description#>
    @discardableResult
    public func minWidth(_ width: NumberConvertible) -> Self {
        self.minWidth = width.cgFloat
        return self
    }
    
    
    
    ///  设置view的最大宽度，
    /// - Parameter width: <#width description#>
    /// - Returns: <#description#>
    @discardableResult
    public func maxWidth(_ width: NumberConvertible) -> Self {
        self.maxWidth = width.cgFloat
        return self
    }
    
    
    
    ///  设置view的最小高度，
    /// - Parameter height: <#height description#>
    /// - Returns: <#description#>
    @discardableResult
    public func minHeight(_ height: NumberConvertible) -> Self {
        self.minHeight = height.cgFloat
        return self
    }
    
    
    
    ///  设置view的最大高度，
    /// - Parameter height: <#height description#>
    /// - Returns: <#description#>
    @discardableResult
    public func maxHeight(_ height: NumberConvertible) -> Self {
        self.maxHeight = height.cgFloat
        return self
    }
    
    
    /// 设置view的大小，width和height同时设置时生效
    /// - Parameters:
    ///   - w: <#w description#>
    ///   - h: <#h description#>
    /// - Returns: <#description#>
    @discardableResult
    public func size(w: NumberConvertible,h: NumberConvertible) -> Self {
        self.size = CGSize(width: w.cgFloat, height: h.cgFloat)
        return self
    }
    
    
    
    /// 设置正方形长宽
    /// - Parameter side: <#side description#>
    /// - Returns: <#description#>
    @discardableResult
    public func square(_ side: NumberConvertible) -> Self {
        return size(w: side, h: side)
    }

    
    
    
    /// 获取view并转换成指定类型，转换失败返回nil
    /// - Parameter view: <#view description#>
    /// - Returns: <#description#>
    @discardableResult
    public func view<T>(as view: T.Type) -> T? where T: UIView {
        return self.view as? T
    }
}

extension FlexItem {
    func setStackViewNeedsUpdateConstraints() {
        guard let view = self.view,
              let stackView = self.stackView,
              view.superview == stackView else { return }
        stackView.markedUpdateConstraints()
    }
    
    func setSpacingWithoutUpdate(_ spacing: CGFloat) {
        _spacing = spacing
    }
    
    func filterConstraint(
        _ block: (ConstraintWrapper) -> Bool
    ) -> [ConstraintWrapper]? {
        guard let manager = stackView?.layoutManager else {
            return nil
        }
        guard !manager.constraints.isEmpty else { return nil }
        return manager.constraints.filter { constraint in
            block(constraint)
        }
    }
}



public extension FlexItem {
    
    
    /// 设置外边距，默认值为.zero
    @objc(margin)
    @available(swift, obsoleted: 1, renamed: "margin(_:)")
    var marginObjc: (_ margin: NSDirectionalEdgeInsets) -> FlexItem {
        { margin in self.margin = margin; return self }
    }
    
    
    
    /// 设置后面的间距，默认跟随StackView的spacing属性
    @objc(spacing)
    @available(swift, obsoleted: 1, renamed: "spacing(_:)")
    var spacingObjc: (_ spacing: CGFloat) -> FlexItem {
        { spacing in self.spacing = spacing; return self }
    }
    
    
    
    /// 设置view后面的最小间距，默认跟随StackView的spacing属性
    @objc(minSpacing)
    @available(swift, obsoleted: 1, renamed: "minSpacing(_:)")
    var minSpacingObjc: (_ spacing: CGFloat) -> FlexItem {
        { spacing in self.minSpacing = spacing; return self }
    }
    
    
    
    /// 设置view后面的最大间距，默认跟随StackView的spacing属性
    @objc(maxSpacing)
    @available(swift, obsoleted: 1, renamed: "maxSpacing(_:)")
    var maxSpacingObjc: (_ spacing: CGFloat) -> FlexItem {
        { spacing in self.maxSpacing = spacing; return self }
    }
    
    
    
    /// 设置view后面是否是弹性空间，弹性空间没有view，只有间距，且会占用剩余空间
    @objc(isFlexibleSpace)
    @available(swift, obsoleted: 1, renamed: "isFlexSpace(_:)")
    var isFlexSpaceObjc: (_ isFlex: Bool) -> FlexItem {
        { isFlex in self.isFlexibleSpace = isFlex; return self }
    }
    
    
    
    /// 设置弹性系数，默认为0，值越大占用剩余空间越多，flex为0表示自适应
    @objc(flex)
    @available(swift, obsoleted: 1, renamed: "flexValue(_:)")
    var flexValueObjc: (_ value: Int) -> FlexItem {
        { value in self.flex = value; return self }
    }
    
    
    
    /// 设置item的对齐方式，默认跟随StackView的alignment属性
    @objc(align)
    @available(swift, obsoleted: 1, renamed: "align")
    var alignSelfObjc: (_ align: FlexItemCrossAlign) -> FlexItem {
        { align in self.alignSelf = align; return self }
    }
    
    
    
    /// 设置view的高度，默认为0，表示自适应
    @objc(height)
    @available(swift, obsoleted: 1, renamed: "height(_:)")
    var heightObjc: (_ height: CGFloat) -> FlexItem {
        { height in self.height = height; return self }
    }
    
    
    
    /// 设置view的宽度，默认为0，表示自适应
    @objc(width)
    @available(swift, obsoleted: 1, renamed: "width(_:)")
    var widthObjc: (_ width: CGFloat) -> FlexItem {
        { width in self.width = width; return self }
    }
    
    
    
    /// 设置view的最小宽度，
    @objc(minWidth)
    @available(swift, obsoleted: 1, renamed: "minWidth(_:)")
    var minWidthObjc: (_ width: CGFloat) -> FlexItem {
        { width in self.minWidth = width; return self }
    }
    
    
    
    /// 设置view的最大宽度，
    @objc(maxWidth)
    @available(swift, obsoleted: 1, renamed: "maxWidth(_:)")
    var maxWidthObjc: (_ width: CGFloat) -> FlexItem {
        { width in self.maxWidth = width; return self }
    }
    
    
    
    /// 设置view的最小高度，
    @objc(minHeight)
    @available(swift, obsoleted: 1, renamed: "minHeight(_:)")
    var minHeightObjc: (_ height: CGFloat) -> FlexItem {
        { height in self.minHeight = height; return self }
    }
    
    
    
    /// 设置view的最大高度，
    @objc(maxHeight)
    @available(swift, obsoleted: 1, renamed: "maxHeight(_:)")
    var maxHeightObjc: (_ height: CGFloat) -> FlexItem {
        { height in self.maxHeight = height; return self }
    }
    
    
    /// 设置view的大小，width和height同时设置时生效
    @objc(size)
    @available(swift, obsoleted: 1, renamed: "size(w:h:)")
    var sizeObjc: (_ w: CGFloat, _ h: CGFloat) -> FlexItem {
        { w, h in self.size = CGSize(width: w, height: h); return self }
    }
}









private var flexKey:      UInt8 = 0
extension UIView {
    
    /// 获取view在StackView里面弹性布局对象
    @objc(zl_flex)
    public var flex: FlexItem {
        if let cfg = objc_getAssociatedObject(self, &flexKey) as? FlexItem {
            return cfg
        }
        let cfg = FlexItem()
        cfg.view = self
        // 如需显式延长生命周期到自动释放池销毁，可用：
        _ = Unmanaged.passRetained(self).autorelease()
        objc_setAssociatedObject(
            self,
            &flexKey,
            cfg,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return cfg
    }
}
