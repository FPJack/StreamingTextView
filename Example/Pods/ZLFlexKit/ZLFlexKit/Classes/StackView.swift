//
//  StackView.swift
//  ZLFlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit
@objc(ZLStackViewAxis)
public enum StackViewAxis: Int {
    case horizontal = 0   // 水平排列
    case vertical         // 垂直排列
}

@objc(ZLJustify)
public enum Justify: Int {
    case fill
    case fillEqually
    case start
    case center
    case end
    ///间距不包括stackView的内边距和view的margin，适用于view之间的纯间距
    case spaceBetween   // 两边没有间距，中间相等
    case spaceAround    // 两边是中间一半
    case spaceEvenly    // 所有间距都相等
}


@objc(ZLStackView)
open class StackView: UIView {
    
    
    /// 布局轴向，默认为水平排列
    @objc
    public var axis: StackViewAxis = .horizontal {
        didSet {
            if oldValue != axis {
                markedUpdateConstraints()
            }
        }
    }
    
    
    
    /// 交叉轴对齐方式，默认为 center
    @objc
    public var alignment: FlexItemCrossAlign = .center {
        didSet {
            if oldValue != alignment {
                markedUpdateConstraints()
            }
        }
    }
    
    
    
    ///  主轴对齐方式，默认为 fill
    @objc
    public var justifyContent: Justify = .fill {
        didSet {
            if oldValue != justifyContent {
                markedUpdateConstraints()
            }
        }
    }
    
    
    
    ///  内边距，默认为 .zero
    @objc
    public var insets: NSDirectionalEdgeInsets = .zero {
        didSet {
            if oldValue != insets {
                layoutManager.updateInsets(oldValue, insets)
            }
        }
    }
    
    
    
    /// 当前排列的 view 数组，隐藏的 view 不包含在内
    @objc
    public var arrangedViews: [UIView] {
        allViews.filter {!$0.isHidden}
    }
    
    
    
    /// 主轴方向的间距，默认为 -1，表示使用默认间距（0）
    @objc
    public var spacing: CGFloat = -1 {
        didSet {
            if oldValue != spacing {
                markedUpdateConstraints()
            }
        }
    }
    
    
    
    /// 布局管理器，负责根据 stackView 的属性和子 view 的属性生成约束
    lazy var layoutManager: FlexManager = {
        let flexManager = FlexManager()
        flexManager.stackView = self
        return flexManager
    }()
    
    
    
    private var allViews: [UIView] = []
    
    
    private var markedDirty: Bool = true
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layoutMargins = .zero
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    /// 使用 DSL 构建 StackView，支持在 builder 中直接添加 view 或者设置间距
    /// - Parameter builder: <#builder description#>
    public init(@StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(frame: .zero)
        addViews(builder: builder)
    }
    public  init(
                 axis: StackViewAxis? = nil,
                 justify: Justify? = nil,
                 align: FlexItemCrossAlign? = nil,
                 spacing: CGFloat? = nil,
                 insets: EdgeInsets? = nil,
                 @StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(frame: .zero)
        addViews(builder: builder)
        if let axis = axis {
            self.axis = axis
        }
                     
        if let justify = justify {
            self.justifyContent = justify
        }
        if let align = align {
            self.alignment = align
        }
        if let spacing = spacing {
            self.spacing = spacing
        }
        if let insets = insets {
            self.insets = insets.directionalEdgeInsets
        }
    }
    
    
    
    
    func markedUpdateConstraints() {
        if markedDirty { return }
        markedDirty = true
        setNeedsUpdateConstraints()
    }
    
    
    
    
    ///  设置 stackView 的轴向为垂直排列
    /// - Returns: <#description#>
    @objc
    public func vertical() -> Self {
        axis = .vertical
        return self
    }
    
    
    /// 设置 stackView 的轴向为水平排列
    /// - Returns: <#description#>
    @objc
    public func horizontal() -> Self {
        axis = .horizontal
        return self
    }
    
    
    
    /// 创建一个垂直排列的 stackView
    /// - Returns: <#description#>
    @objc
    public static func vertical() -> Self {
        let stackView = Self.init()
        stackView.axis = .vertical
        return stackView
    }
    
    
    
    ///  创建一个水平排列的 stackView
    /// - Returns: <#description#>
    @objc
    public static func horizontal() -> Self {
        let stackView = Self.init()
        stackView.axis = .horizontal
        return stackView
    }
    
    
    
    
    
    // MARK: - swift链式API
    
    
    /// 设置 stackView 的轴向
    /// - Parameter axis: <#axis description#>
    /// - Returns: <#description#>
    @discardableResult
    public func axis(_ axis: StackViewAxis) -> Self {
        self.axis = axis
        return self
    }
    
    
    
    ///  设置 stackView 的交叉轴对齐方式
    /// - Parameter alignment: <#alignment description#>
    /// - Returns: <#description#>
    @discardableResult
    public func align(_ alignment: FlexItemCrossAlign) -> Self {
        self.alignment = alignment
        return self
    }
    
    
    
    ///   设置 stackView 的主轴对齐方式
    /// - Parameter justifyContent: <#justifyContent description#>
    /// - Returns: <#description#>
    @discardableResult
    public func justify(_ justifyContent: Justify) -> Self {
        self.justifyContent = justifyContent
        return self
    }
    
    
    
    ///  设置 stackView 的内边距
    /// - Parameter insets: <#insets description#>
    /// - Returns: <#description#>
    @discardableResult
    public func insets(_ insets: NSDirectionalEdgeInsets) -> Self {
        self.insets = insets
        return self
    }
    
    @discardableResult
    public func insets(_ insets: EdgeInsets) -> Self {
        self.insets = insets.directionalEdgeInsets
        return self
    }
    
    
    
    ///  设置 stackView 的内边距 - top, leading, bottom, trailing
    /// - Parameter spacing: <#spacing description#>
    /// - Returns: <#description#>
    @discardableResult
    public func spacing(_ spacing: NumberConvertible) -> Self {
        self.spacing = spacing.cgFloat
        return self
    }
    
    
    
    ///  插入 一个间距 ，默认添加到最后
    /// - Parameter spacing: <#spacing description#>
    /// - Returns: <#description#>
    @discardableResult
    open func insertSpacing(_ spacing: NumberConvertible) -> Self {
        allViews.last?.flex.spacing = spacing.cgFloat
        return self
    }
    
    
    /// 插入一个最小间距，默认添加到最后
    /// - Parameter min: <#min description#>
    /// - Returns: <#description#>
    @discardableResult
    open func insertSpacing(min: NumberConvertible) -> Self {
        allViews.last?.flex.minSpacing = min.cgFloat
        return self
    }
    
    
    /// 插入一个最大间距，默认添加到最后
    /// - Parameter max: <#max description#>
    /// - Returns: <#description#>
    @discardableResult
    open func insertSpacing(max: NumberConvertible) -> Self {
        allViews.last?.flex.maxSpacing = max.cgFloat
        return self
    }
    
    
    ///  插入一个弹性间距，默认添加到最后，仅 ZLJustify.fill 生效
    /// - Parameter flexible: <#flexible description#>
    /// - Returns: <#description#>
    @discardableResult
    open func insertSpacing(flexible: Bool) -> Self {
        allViews.last?.flex.isFlexibleSpace = flexible
        return self
    }
    
    
    
    ///  添加 view 到 stackView，默认添加到最后
    /// - Parameter flexType: <#flexType description#>
    /// - Returns: <#description#>
    @discardableResult
    open func addView(_ flexType: FlexType?) -> Self {
        addArrangedSubview(flexType?.baseView)
        return self
    }
    
    
    
    /// 添加 view 到 stackView，满足条件时才添加，默认添加到最后
    /// - Parameters:
    ///   - condition: <#condition description#>
    ///   - view: <#view description#>
    /// - Returns: <#description#>
    @discardableResult
    open func addView(if condition: Bool, _ view: FlexType?) -> Self {
        if condition {
            addArrangedSubview(view?.baseView)
        }
        return self
    }
    
    
    
    /// 添加 view 到 stackView，使用闭包创建 view，默认添加到最后
    /// - Parameter make: <#make description#>
    /// - Returns: <#description#>
    @discardableResult
    open func addView<T>(make: @escaping (T) -> (FlexType)?) -> Self where T: StackView{
        let blockView = make(self as! T)
        addArrangedSubview(blockView?.baseView)
        return self
    }
    
    
    
    
    ///  添加 view 到 stackView，满足条件时才添加，使用闭包创建 view，默认添加到最后
    /// - Parameters:
    ///   - condition: <#condition description#>
    ///   - make: <#make description#>
    /// - Returns: <#description#>
    @discardableResult
    open func addView<T>(if condition: Bool, make: @escaping (T) -> FlexType?) -> Self where T: StackView  {
        if condition {
            let blockView = make(self as! T)
            addArrangedSubview(blockView?.baseView)
        }
        
        return self
    }
    
    
    
    
    
    /// 设置 特定view 的 margin，会与 stackView 的 insets(内边距) 叠加生效
    /// - Parameters:
    ///   - marge: <#marge description#>
    ///   - view: <#view description#>
    /// - Returns: <#description#>
    @discardableResult
    open func marge(_ marge: NSDirectionalEdgeInsets, for view: UIView?) -> Self {
        setMargin(marge, for: view)
        return self
    }
    
    
    ///  将 stackView 包裹在一个 UIScrollView 中，返回 UIScrollView，方便设置滚动相关属性
    /// - Returns: <#description#>
    @objc
    @discardableResult
    open func wrapScrollView() -> ScrollView {
        let scrollView = ScrollView()
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.box.edgesZero()
        let axisLayout: NSLayoutConstraint
        if self.axis == .horizontal {
            axisLayout = self.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            let equalWidth = scrollView.widthAnchor.constraint(equalTo: self.widthAnchor)
            equalWidth.priority = .defaultLow
            equalWidth.isActive = true
        } else {
            axisLayout = self.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            let equalHeight = scrollView.heightAnchor.constraint(equalTo: self.heightAnchor)
            equalHeight.priority = .defaultLow
            equalHeight.isActive = true
        }
        axisLayout.isActive = true
        return scrollView
    }
    
    @discardableResult
    open func assignToPtr(_ ptr: AutoreleasingUnsafeMutablePointer<StackView>?) -> StackView {
        if let ptr = ptr {
            ptr.pointee = self
        }
        return self
    }
    
    
    
    
}

// MARK: - OC链式API
extension StackView {
    
    /// 设置 stackView 的主轴对齐方式为 fillEqually
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifyFillEqually: StackView {
        self.justifyContent = .fillEqually
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 fill
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifyFill: StackView {
        self.justifyContent = .fill
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 start
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifyStart: StackView {
        self.justifyContent = .start
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 center
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifyCenter: StackView {
        self.justifyContent = .center
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 end
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifyEnd: StackView {
        self.justifyContent = .end
        return self
    }
    
    
    ///  设置 stackView 的主轴对齐方式为 spaceBetween
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifySpaceBetween: StackView {
        self.justifyContent = .spaceBetween
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 spaceAround
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifySpaceAround: StackView {
        self.justifyContent = .spaceAround
        return self
    }
    
    
    /// 设置 stackView 的主轴对齐方式为 spaceEvenly
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var justifySpaceEvenly: StackView {
        self.justifyContent = .spaceEvenly
        return self
    }
    
    
    ///   设置 stackView 的交叉轴对齐方式为 fill
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var alignFill: StackView {
        self.alignment = .fill
        return self
    }
    
    
    
    /// 设置 stackView 的交叉轴对齐方式为 start
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var alignStart: StackView {
        self.alignment = .start
        return self
    }
    
    
    /// 设置 stackView 的交叉轴对齐方式为 center
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var alignCenter: StackView {
        self.alignment = .center
        return self
    }
    
    
    /// 设置 stackView 的交叉轴对齐方式为 end
    @objc
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var alignEnd: StackView {
        self.alignment = .end
        return self
    }
    
    
    
    /// 设置 stackView 的轴向
    @objc(setAxis)
    @available(swift, obsoleted: 1, renamed: "axis(_:)")
    public var axisObjc: (_ axis: StackViewAxis) -> StackView {
        {
            axis in self.axis = axis;
            return self
        }
    }
    
    
    
    /// 设置 stackView 的交叉轴对齐方式
    @objc(setAlign)
    @available(swift, obsoleted: 1, renamed: "align(_:)")
    public var alignObjc: (_ alignment: FlexItemCrossAlign) -> StackView {
        {
            alignment in self.alignment = alignment;
            return self
        }
    }
    
    
    
    /// 设置 stackView 的主轴对齐方式
    @objc(setJustify)
    @available(swift, obsoleted: 1, renamed: "justify(_:)")
    public var justifyObjc: (_ justifyContent: Justify) -> StackView{
        {
            justifyContent in self.justifyContent = justifyContent;
            return self
        }
    }
    
    
    
    ///     stackView 的内边距 - top, leading, bottom, trailing
    @objc(setInsets)
    @available(swift, obsoleted: 1, renamed: "insets(_:)")
    public var insetsObjc: (_ top: CGFloat,_ leading: CGFloat,_ bottom: CGFloat, _ trailing: CGFloat) -> StackView {
        {
            top,leading,bottom,trailing in self.insets = .init(top: top, leading: leading, bottom: bottom, trailing: trailing);
            return self
        }
    }
    
    
    
    ///  设置 stackView 的主轴方向view之间的间距
    @objc(setSpacing)
    @available(swift, obsoleted: 1, renamed: "spacing(_:)")
    public var spacingObjc: (_ spacing: CGFloat) -> StackView {
        {
            spacing in self.spacing = spacing;
            return self
        }
    }
    
    
    
    /// 插入一个间距，默认添加到最后
    @objc(insertSpacing)
    @available(swift, obsoleted: 1, renamed: "insertSpacing(_:)")
    open var insertSpacingObjc: (_ spacing: CGFloat) -> StackView {
        {
            spacing in self.allViews.last?.flex.spacing = spacing;
            return self
        }
    }
    
    
    
    /// 插入一个最小间距，默认添加到最后
    @objc(insertMinSpacing)
    @available(swift, obsoleted: 1, renamed: "insertSpacing(min:)")
    open var insertMinSpacingObjc: (_ spacing: CGFloat) -> StackView {
        {
            spacing in self.allViews.last?.flex.minSpacing = spacing;
            return self
            
        }
    }
    
    
    
    ///  插入一个最大间距，默认添加到最后
    @objc(insertMaxSpacing)
    @available(swift, obsoleted: 1, renamed: "insertSpacing(max:)")
    open var insertMaxSpacingObjc: (_ spacing: CGFloat) -> StackView {
        {
            spacing in self.allViews.last?.flex.maxSpacing = spacing;
            return self
        }
    }
    
    
    
    ///  插入一个弹性间距，默认添加到最后，仅 ZLJustify.fill 生效
    @objc(insertFlexibleSpacing)
    @available(swift, obsoleted: 1, renamed: "insertSpacing(flexible:)")
    open var insertFlexibleSpacingObjc: (_ flexible: Bool) -> StackView {
        {
            flexible in self.allViews.last?.flex.isFlexibleSpace = flexible;
            return self
        }
    }
    
    
    
    ///  添加 view 到 stackView，默认添加到最后
    @objc(addView)
    @available(swift, obsoleted: 1, renamed: "addView(_:)")
    open var addViewObjc: (_ view: UIView?) -> StackView {
        {
            view in self.addArrangedSubview(view);
            return self
        }
    }
    
    
    
    ///   添加 view 到 stackView，满足条件时才添加，默认添加到最后
    @objc(addViewIf)
    @available(swift, obsoleted: 1, renamed: "addView(if:_:)")
    open var addViewIfObjc: (_ condition: Bool, _ view: UIView?) -> StackView {
        {
            condition, view in
            if condition {
                self.addArrangedSubview(view)
            }
            return self
        }
    }
    
    
    
    ///   添加 view 到 stackView，使用闭包创建 view，默认添加到最后
    @objc(addViewMake)
    @available(swift, obsoleted: 1, renamed: "addView(make:)")
    open var addViewMakeObjc: (_ make: @escaping (StackView) -> UIView?) -> StackView {
        {
            make in let blockView = make(self);
            self.addArrangedSubview(blockView);
            return self
        }
    }
    
    
    
    ///   添加 view 到 stackView，满足条件时才添加，使用闭包创建 view，默认添加到最后
    @objc(addViewIfMake)
    @available(swift, obsoleted: 1, renamed: "addView(if:make:)")
    open var addViewIfMakeObjc: (_ condition: Bool, _ make: @escaping (StackView) -> UIView?) -> StackView {
        {
            condition, make in
            if condition {
                let blockView = make(self);
                self.addArrangedSubview(blockView)
            }
            return self
        }
    }
    
    
    
    ///   设置 特定view 的 margin，会与 stackView 的 insets(内边距) 叠加生效
    @objc(setMarge)
    @available(swift, obsoleted: 1, renamed: "marge(_:forView:)")
    open var setMargeObjc: (_ top: CGFloat,_ leading: CGFloat,_ bottom: CGFloat, _ trailing: CGFloat, _ view: UIView?) -> StackView {
        {
            top,leading,bottom,trailing,view in
            self.setMargin(.init(top: top, leading: leading, bottom: bottom, trailing: trailing), for: view)
            return self
        }
    }
    
    
    
    @objc(assignToPtr)
    @available(swift, obsoleted: 1, renamed: "assignToPtr(_:)")
    open var assignToPtrObjc: (AutoreleasingUnsafeMutablePointer<StackView>?) -> StackView {
        return { ptr in
            if let ptr = ptr {
                ptr.pointee = self
            }
            return self
        }
    }
}

extension StackView {
    
    // MARK: - Add / Insert
    
    /// 添加 view 到 stackView，默认添加到最后
    @objc
    open func addArrangedSubview(_ view: UIView?) {
        guard let view = view, view.isKind(of: UIView.self) else { return }
        
        guard !allViews.contains(view) else { return }
        
        view.flex.stackView = self
        
        allViews.append(view)
        
        adjustLabelCompression(view)
        
        adjustStackView(view)
        
        addSubview(view)
        
        if view.isHidden { return }
        
        markedUpdateConstraints()
        
    }
    
    /// 添加 view 并配置 view 的布局属性
    @objc
    open func addArrangedSubview(
        _ view: UIView,
        layout config: ((_ view: UIView, _ flexItem: FlexItem) -> Void)?
    ) {
        addArrangedSubview(view)
        config?(view, view.flex)
    }
    
    /// 在某个位置插入 view
    @objc
    open func insertArrangedSubview(_ view: UIView?, at stackIndex: Int) {
        guard let view = view, view.isKind(of: UIView.self) else { return }
        
        guard !allViews.contains(view) else { return }
        
        adjustStackView(view)
        
        addSubview(view)
        
        view.flex.stackView = self
        
        allViews.insert(view, at: stackIndex)
        
        adjustLabelCompression(view)
        
        if view.isHidden { return }
        
        markedUpdateConstraints()
    }
    
    
    // MARK: - Remove
    
    /// 移除 view
    @objc
    open func removeArrangedSubview(_ view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard let index = allViews.firstIndex(of: view) else { return }
        
        view.removeFromSuperview()
        
        allViews.remove(at: index)
        
        markedUpdateConstraints()
    }
    
    
    // MARK: - Spacing Control
    
    /// 设置 view 在主轴方向的间距
    @objc
    open func setCustomSpacing(_ spacing: CGFloat, after view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        guard view.isKind(of: UIView.self) else { return }
        let viewCfg = view.flex
        guard viewCfg.spacing != spacing else { return }
        viewCfg._spacing = spacing
        guard !view.isHidden else { return }
        guard !layoutManager.constraints.isEmpty else { return }
        let matched = filterConstraint { constraint in
            let cfg = constraint.item
            return cfg.view == view && cfg.type == .spacing
        }
        if let constraint = matched.first {
            constraint.constant = max(0, spacing)
        } else {
            markedUpdateConstraints()
        }
    }
    
    /// 设置 view 在主轴方向的最小间距
    @objc
    open func setCustomMinSpacing(_ minSpacing: CGFloat, after view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        guard view.isKind(of: UIView.self) else { return }
        let viewCfg = view.flex
        guard viewCfg.minSpacing != minSpacing else { return }
        viewCfg._minSpacing = minSpacing
        guard !view.isHidden else { return }
        guard !layoutManager.constraints.isEmpty else { return }
        let matched = filterConstraint { constraint in
            let cfg = constraint.item
            return cfg.view == view && cfg.type == .minSpacing
        }
        if !matched.isEmpty {
            let value = max(0, minSpacing)
            matched.first?.constant = value
            matched.last?.constant = value
        } else {
            markedUpdateConstraints()
        }
    }
    
    /// 设置 view 在主轴方向的最大间距
    @objc
    open  func setCustomMaxSpacing(_ maxSpacing: CGFloat, after view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        
        guard !layoutManager.constraints.isEmpty else { return }
        
        let viewCfg = view.flex
        
        guard viewCfg.maxSpacing != maxSpacing else { return }
        viewCfg._maxSpacing = maxSpacing
        
        guard !view.isHidden else { return }
        
        let matched = filterConstraint {
            let cfg = $0.item
            return cfg.view == view && cfg.type == .maxSpacing
        }
        
        if let constraint = matched.first {
            constraint.constant = max(0, maxSpacing)
        } else {
            markedUpdateConstraints()
        }
    }
    
    
    // MARK: - Flex
    
    /// 设置 view 在主轴方向的权重
    @objc(setFlex:forView:)
    open func setFlex(_ flex: Int, for view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        
        let cfg = view.flex
        
        guard flex >= 0, cfg.flex != flex else { return }
        
        cfg.flex = flex
        
        guard !view.isHidden else { return }
        
        markedUpdateConstraints()
    }
    
    /// 是否弹性空间（仅 ZLJustify.fill 生效）
    @objc(setFlexibleSpacing:forView:)
    open func setFlexibleSpacing(_ flexible: Bool, after view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        
        let flex = view.flex
        
        guard flex.isFlexibleSpace != flexible else { return }
        
        flex.isFlexibleSpace = flexible
        
        guard !view.isHidden else { return }
        
        markedUpdateConstraints()
    }
    
    
    // MARK: - Alignment
    
    /// 设置 view 的 alignment（优先级高于 stackView）
    @objc(setAlignment:forView:)
    open func setAlignment(_ alignment: FlexItemCrossAlign, for view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        
        let cfg = view.flex
        
        guard cfg.alignSelf != alignment else { return }
        
        cfg.alignSelf = alignment
        
        guard !view.isHidden else { return }
        
        markedUpdateConstraints()
    }
    
    
    @objc(setMargin:forView:)
    open func setMargin(_ margin: NSDirectionalEdgeInsets, for view: UIView?) {
        guard let view = view,view.isKind(of: UIView.self) else { return }
        
        guard allViews.contains(view) else { return }
        
        let cfg = view.flex
        
        guard cfg.margin != margin else { return }
        
        cfg.margin = margin
        
        guard !view.isHidden else { return }
        
        markedUpdateConstraints()
    }






    
    
    
}

///DSL
extension StackView {
    @discardableResult
    public func addViews(
        @StackViewBuilder builder: () -> [StackViewDSL]
    ) -> Self {
        addViews(with: builder)
        return self
    }
    func addViews(with builder: () -> [StackViewDSL]) {
        let arr = builder()
        arr.forEach { component in
            if let view = component.getDslView() {
                addView(view)
            }else if let item = component as? Double {
                insertSpacing(CGFloat(item))
            }else if let item = component as? Int {
                insertSpacing(CGFloat(item))
            }else if let item = component as? Float {
                insertSpacing(CGFloat(item))
            }else if let item = component as? FlexItem {
                addView(item)
            }else if let item = component as? Spacer {
                switch item {
                case .normal:
                    insertSpacing(flexible: true)
                case .min(let value):
                    insertSpacing(min: value)
                case .max(let value):
                    insertSpacing(max: value)
                case .value(let value):
                    insertSpacing(value)
                }
            }
        }
    }
}


public protocol FlexType {}
extension FlexType {
    var baseView: UIView? {
        if let view = self as? UIView {
            return view
        } else if let item = self as? FlexItem {
            return item.view
        }
        return nil
    }
}
extension FlexItem: FlexType {}
extension UIView: FlexType {}


extension StackView {
    override public func updateConstraints() {
        
        guard markedDirty else {
            super.updateConstraints()
            return
        }
        
        layoutManager.removeAllSpacing()
        layoutManager.deactivateConstraints()
        layoutManager.addHorizontalLayoutConstraints()
        layoutManager.addVerticalLayoutConstraints()
        layoutManager.activateConstraints()
        
        markedDirty = false
        
        super.updateConstraints()
    }
    open override var intrinsicContentSize: CGSize {
        .zero
    }
}


extension StackView {
    private func adjustLabelCompression(_ view: UIView) {
        
        guard let label = view as? UILabel else { return }
        
        if label.numberOfLines == 1 { return }
        
        let axis: NSLayoutConstraint.Axis =
        (self.axis == .horizontal)
        ? .horizontal
        : .vertical
        
        let priority = view.contentCompressionResistancePriority(for: axis)
        
        if priority == .defaultHigh {
            view.setContentCompressionResistancePriority(priority - 0.1, for: axis)
        }
    }
    private func adjustStackView(_ view: UIView) {
        
        if view is StackView || view is UIStackView {
            // StackView 嵌套时避免约束冲突
            view.translatesAutoresizingMaskIntoConstraints = false
        }
       
    }
    
    private func filterConstraint(
        _ block: (NSLayoutConstraint) -> Bool
    ) -> [NSLayoutConstraint] {
        return layoutManager.constraints.filter { constraint in
            block(constraint.constraint)
        }.map {  $0.constraint}
    }
}



/// 垂直排列的 StackView，axis 固定为 .vertical
open class VStackView: StackView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public init() {
        super.init(frame: .zero)
    }
    
    
    public override var axis: StackViewAxis {
        get { .vertical }
        set {}
    }
    
   
    
    public override init(@StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(builder: builder)
    }
    public  init(justify: Justify? = nil,
                 align: FlexItemCrossAlign? = nil,
                 spacing: CGFloat? = nil,
                 insets: EdgeInsets? = nil,
                 @StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(builder: builder)
        if let justify = justify {
            self.justifyContent = justify
        }
        if let align = align {
            self.alignment = align
        }
        if let spacing = spacing {
            self.spacing = spacing
        }
        if let insets = insets {
            self.insets = insets.directionalEdgeInsets
        }
    }
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


/// 水平排列的 StackView，axis 固定为 .horizontal
open class HStackView: StackView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    public init() {
        super.init(frame: .zero)
    }
    public override var axis: StackViewAxis {
        get { .horizontal }
        set {}
    }
    
    public override init( @StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(builder: builder)
    }
    public  init(justify: Justify? = nil,
                 align: FlexItemCrossAlign? = nil,
                 spacing: CGFloat? = nil,
                 insets: EdgeInsets? = nil,
                 @StackViewBuilder builder: () -> [StackViewDSL]) {
        super.init(builder: builder)
        if let justify = justify {
            self.justifyContent = justify
        }
        if let align = align {
            self.alignment = align
        }
        if let spacing = spacing {
            self.spacing = spacing
        }
        if let insets = insets {
            self.insets = insets.directionalEdgeInsets
        }
    }
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

