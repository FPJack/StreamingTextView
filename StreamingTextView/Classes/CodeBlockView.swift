//
//  CodeBlockView.swift
//  StreamingTextView
//
//  一个用于展示「代码块」的视图：
//    - 左侧行号栏（gutter），右侧代码区，各自是一个 UICollectionView；
//    - 两个 collectionView 垂直方向**双向联动**（滚动其一，另一个同步）；
//    - 布局使用 UICollectionViewCompositionalLayout，cell 高度自动估算（self-sizing）；
//    - 代码区可独立控制**水平 / 垂直**是否允许滚动；
//    - 支持设置代码行的最大宽度（超出则换行）；
//    - 外部传入一段富文本，按其中的换行符 `\n` **一一对应**生成行号；
//    - 可控制是否展示行号；
//    - 可设置整个视图的最大展示宽 / 高，并重写 `intrinsicContentSize` 自适应宽高；
//    - 支持自定义头部 / 尾部视图；
//    - 支持在不创建视图的情况下**提前计算整体尺寸**（`calculateSize(...)`）。
//

import UIKit

// MARK: - 度量模型

/// 单行代码的度量结果。
private struct CodeLineLayout {
    let number: Int                 // 行号（从 1 开始）
    let text: NSAttributedString    // 该行富文本（不含换行符）
    let height: CGFloat             // 该行渲染高度（含垂直内边距）
    let naturalWidth: CGFloat       // 该行文字自然宽度（不含水平内边距）
}

/// 整个代码块的度量结果（与是否显示、最大宽高等无关的「内容原始尺寸」）。
private struct CodeBlockMetrics {
    var lines: [CodeLineLayout] = []
    var gutterWidth: CGFloat = 0        // 行号栏宽度（含内边距）；不显示行号时为 0
    var codeContentWidth: CGFloat = 0   // 代码内容宽度（含水平内边距）
    var rowsHeight: CGFloat = 0         // 所有行高度之和
}

/// 度量所需的样式参数（供实例与静态方法共用）。
private struct CodeBlockStyle {
    var codeFont: UIFont
    var lineNumberFont: UIFont
    var gutterHPadding: CGFloat
    var cellHPadding: CGFloat
    var cellVPadding: CGFloat
    var minRowHeight: CGFloat
    /// 代码行最大宽度（>0 时超出则换行）；<=0 表示不限制（单行不换行）。
    var maxCellWidth: CGFloat
    var showsLineNumbers: Bool
    /// 代码区是否允许水平滚动。为 false 时，长行必须在代码区可用宽度内换行完整展示
    /// （行高随之增大，但行号仍只按 `\n` 计数，不增加）。
    var allowsHorizontalScroll: Bool
}

// MARK: - CodeBlockView

@available(iOS 13.0, *)
@objcMembers
public class CodeBlockView: UIView {

    // MARK: 公开配置

    /// 要展示的代码富文本。设置后自动重新度量并刷新。
    public var attributedText: NSAttributedString? {
        didSet { setNeedsReload() }
    }

    /// 是否展示左侧行号。默认 `true`。
    public var showsLineNumbers: Bool = true {
        didSet { if oldValue != showsLineNumbers { setNeedsReload() } }
    }

    /// 代码区是否允许**水平**滚动。默认 `true`。
    /// 关闭后：长行会在代码区可用宽度内换行完整展示（行高增大），行号仍按 `\n` 计数不变。
    public var allowsHorizontalScroll: Bool = true {
        didSet {
            if oldValue != allowsHorizontalScroll { setNeedsReload() }
            applyScrollFlags()
        }
    }

    /// 代码区是否允许**垂直**滚动。默认 `true`。
    public var allowsVerticalScroll: Bool = true {
        didSet { applyScrollFlags() }
    }

    /// 整个视图的最大宽度。`0` 表示不限制。默认 `0`。
    public var maxViewWidth: CGFloat = 0 {
        didSet { if oldValue != maxViewWidth { setNeedsReload() } }
    }

    /// 整个视图的最大高度。`0` 表示不限制。默认 `0`。
    public var maxViewHeight: CGFloat = 0 {
        didSet { if oldValue != maxViewHeight { setNeedsReload() } }
    }

    /// 单行代码的最大宽度（>0 超出换行；<=0 不换行，单行可水平滚动）。默认 `0`。
    public var maxCellWidth: CGFloat = 0 {
        didSet { if oldValue != maxCellWidth { setNeedsReload() } }
    }

    /// 代码字体（用于空行测高与默认样式）。默认等宽字体 13。
    public var codeFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13) {
        didSet { setNeedsReload() }
    }

    /// 行号字体。默认等宽字体 13。
    public var lineNumberFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13) {
        didSet { setNeedsReload() }
    }

    /// 行号文字颜色。
    public var lineNumberColor: UIColor = UIColor(white: 0.55, alpha: 1) {
        didSet { gutterCollectionView.reloadData() }
    }

    /// 行号栏背景色。
    public var gutterBackgroundColor: UIColor = UIColor(white: 0.96, alpha: 1) {
        didSet { gutterCollectionView.backgroundColor = gutterBackgroundColor }
    }

    /// 代码区背景色。
    public var codeBackgroundColor: UIColor = UIColor(white: 0.98, alpha: 1) {
        didSet { codeCollectionView.backgroundColor = codeBackgroundColor }
    }

    /// 头部自定义视图（固定在代码区上方，参与整体尺寸）。
    public var headerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let h = headerView { addSubview(h) }
            setNeedsReload()
        }
    }

    /// 尾部自定义视图（固定在代码区下方，参与整体尺寸）。
    public var footerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let f = footerView { addSubview(f) }
            setNeedsReload()
        }
    }

    // MARK: 样式常量（内边距等）

    private let gutterHPadding: CGFloat = 8
    private let cellHPadding: CGFloat = 10
    private let cellVPadding: CGFloat = 3
    private let minRowHeight: CGFloat = 18

    // MARK: 子视图

    private lazy var gutterCollectionView = makeCollectionView(background: gutterBackgroundColor)
    private lazy var codeCollectionView = makeCollectionView(background: codeBackgroundColor)

    // MARK: 内部状态

    private var metrics = CodeBlockMetrics()
    /// 计算后的显示尺寸缓存。
    private var resolvedSize: CGSize = .zero
    private var resolvedCodeDisplayWidth: CGFloat = 0
    private var resolvedHeaderHeight: CGFloat = 0
    private var resolvedFooterHeight: CGFloat = 0
    /// 防止双向联动回调递归。
    private var isSyncingScroll = false
    private var needsReload = true

    // MARK: 初始化

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        addSubview(gutterCollectionView)
        addSubview(codeCollectionView)
        registerCells()
        applyScrollFlags()
    }

    private func registerCells() {
        gutterCollectionView.register(CodeLineNumberCell.self,
                                      forCellWithReuseIdentifier: CodeLineNumberCell.reuseID)
        codeCollectionView.register(CodeLineCell.self,
                                    forCellWithReuseIdentifier: CodeLineCell.reuseID)
    }

    private func makeCollectionView(background: UIColor) -> UICollectionView {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        cv.backgroundColor = background
        cv.dataSource = self
        cv.delegate = self
        cv.showsHorizontalScrollIndicator = true
        cv.showsVerticalScrollIndicator = true
        cv.contentInsetAdjustmentBehavior = .never
        cv.bounces = true
        cv.insetsLayoutMarginsFromSafeArea = false
        return cv
    }

    // MARK: 滚动开关

    private func applyScrollFlags() {
        // 行号栏只跟随，不主动展示指示器。
        gutterCollectionView.showsVerticalScrollIndicator = false
        gutterCollectionView.showsHorizontalScrollIndicator = false
        gutterCollectionView.isScrollEnabled = allowsVerticalScroll

        // 代码区：任一方向允许即开启滚动，具体方向在 didScroll 里夹取。
        codeCollectionView.isScrollEnabled = allowsHorizontalScroll || allowsVerticalScroll
        codeCollectionView.showsHorizontalScrollIndicator = allowsHorizontalScroll
        codeCollectionView.showsVerticalScrollIndicator = allowsVerticalScroll
        codeCollectionView.alwaysBounceVertical = allowsVerticalScroll
        codeCollectionView.alwaysBounceHorizontal = allowsHorizontalScroll
    }

    // MARK: 刷新调度

    private func setNeedsReload() {
        needsReload = true
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    private func reloadIfNeeded() {
        guard needsReload else { return }
        needsReload = false
        recompute()
        rebuildLayouts()
        gutterCollectionView.reloadData()
        codeCollectionView.reloadData()
    }

    /// 重新度量内容并计算显示尺寸。
    private func recompute() {
        let style = currentStyle()
        // 可用宽度需在度量前确定：不允许水平滚动时，代码要在此宽度内换行完整展示。
        let availableWidth = availableViewWidth()
        metrics = CodeBlockView.measure(attributedText: attributedText,
                                        style: style,
                                        availableWidth: availableWidth)

        // 头部 / 尾部高度：按可用宽度自适应。
        resolvedHeaderHeight = measureAccessoryHeight(headerView, width: availableWidth)
        resolvedFooterHeight = measureAccessoryHeight(footerView, width: availableWidth)

        // 代码显示宽度：受最大宽度约束时裁到可用宽度，否则等于内容宽度（视图自适应变宽）。
        // 是否水平滚动由「布局 group 宽度」决定（见 rebuildLayouts）：
        //   - 允许水平滚动且内容宽度 > 显示宽度时，group 用完整内容宽度 → 可横向滚动；
        //   - 否则 group 用显示宽度 → 不滚动。
        let gutter = metrics.gutterWidth
        let codeAvailable = max(0, availableWidth - gutter)
        let fullCodeWidth = metrics.codeContentWidth
        resolvedCodeDisplayWidth = maxViewWidth > 0 ? min(fullCodeWidth, codeAvailable) : fullCodeWidth
        if resolvedCodeDisplayWidth < 0 { resolvedCodeDisplayWidth = 0 }

        // 整体尺寸。
        var totalWidth = gutter + resolvedCodeDisplayWidth
        if maxViewWidth > 0 { totalWidth = min(totalWidth, maxViewWidth) }

        var totalHeight = resolvedHeaderHeight + resolvedFooterHeight + metrics.rowsHeight
        if maxViewHeight > 0 { totalHeight = min(totalHeight, maxViewHeight) }

        resolvedSize = CGSize(width: ceil(totalWidth), height: ceil(totalHeight))
    }

    /// 当前可用于排版的视图宽度。
    private func availableViewWidth() -> CGFloat {
        if maxViewWidth > 0 { return maxViewWidth }
        if bounds.width > 0 { return bounds.width }
        return UIScreen.main.bounds.width
    }

    private func currentStyle() -> CodeBlockStyle {
        CodeBlockStyle(codeFont: codeFont,
                       lineNumberFont: lineNumberFont,
                       gutterHPadding: gutterHPadding,
                       cellHPadding: cellHPadding,
                       cellVPadding: cellVPadding,
                       minRowHeight: minRowHeight,
                       maxCellWidth: maxCellWidth,
                       showsLineNumbers: showsLineNumbers,
                       allowsHorizontalScroll: allowsHorizontalScroll)
    }

    private func measureAccessoryHeight(_ view: UIView?, width: CGFloat) -> CGFloat {
        guard let view = view else { return 0 }
        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let size = view.systemLayoutSizeFitting(target,
                                                withHorizontalFittingPriority: .required,
                                                verticalFittingPriority: .fittingSizeLevel)
        return ceil(size.height)
    }

    // MARK: 布局构建（Compositional Layout）

    private func rebuildLayouts() {
        // 行号栏：item 占满栏宽。
        gutterCollectionView.setCollectionViewLayout(
            makeListLayout(width: .fractionalWidth(1.0), estimatedHeight: minRowHeight),
            animated: false)

        // 代码区：允许水平滚动且内容比显示区宽时，用「完整内容宽度」→ 可横向滚动；
        // 否则用显示宽度（不横向溢出）。
        let fullCodeWidth = metrics.codeContentWidth
        let useFull = allowsHorizontalScroll && fullCodeWidth > resolvedCodeDisplayWidth + 0.5
        let codeGroupWidth: NSCollectionLayoutDimension = useFull
            ? .absolute(max(1, fullCodeWidth))
            : .absolute(max(1, resolvedCodeDisplayWidth))
        codeCollectionView.setCollectionViewLayout(
            makeListLayout(width: codeGroupWidth, estimatedHeight: minRowHeight),
            animated: false)
    }

    /// 纵向列表布局：item 宽度由 `width` 指定，高度自动估算（self-sizing）。
    /// - 传 `.fractionalWidth(1.0)`：占满 collectionView 宽度（行号栏用）；
    /// - 传 `.absolute(w)`：固定宽度，w 大于 collectionView 时可横向滚动（代码区用）。
    private func makeListLayout(width: NSCollectionLayoutDimension,
                               estimatedHeight: CGFloat) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: width,
                                              heightDimension: .estimated(estimatedHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: width,
                                               heightDimension: .estimated(estimatedHeight))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: 布局

    public override func layoutSubviews() {
        super.layoutSubviews()
        reloadIfNeeded()

        let width = bounds.width
        let height = bounds.height

        // 头部
        var y: CGFloat = 0
        if let header = headerView {
            header.frame = CGRect(x: 0, y: 0, width: width, height: resolvedHeaderHeight)
            y = resolvedHeaderHeight
        }

        // 尾部
        let footerH = footerView == nil ? 0 : resolvedFooterHeight
        if let footer = footerView {
            footer.frame = CGRect(x: 0, y: height - footerH, width: width, height: footerH)
        }

        // 中间：行号栏 + 代码区
        let midHeight = max(0, height - y - footerH)
        let gutter = metrics.gutterWidth
        gutterCollectionView.frame = CGRect(x: 0, y: y, width: gutter, height: midHeight)
        gutterCollectionView.isHidden = !showsLineNumbers || gutter <= 0

        let codeX = gutter
        let codeWidth = max(0, width - gutter)
        codeCollectionView.frame = CGRect(x: codeX, y: y, width: codeWidth, height: midHeight)
    }

    // MARK: intrinsicContentSize

    public override var intrinsicContentSize: CGSize {
        // 确保度量最新。
        if needsReload { recompute() }
        return resolvedSize.width > 0 || resolvedSize.height > 0 ? resolvedSize
                                                                 : CGSize(width: UIView.noIntrinsicMetric,
                                                                          height: UIView.noIntrinsicMetric)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        if needsReload { recompute() }
        return resolvedSize
    }

    // MARK: - 提前计算尺寸（无需创建/展示视图）

    /// 提前计算整块 `CodeBlockView` 的整体尺寸（不创建实际视图）。
    /// - Parameters:
    ///   - attributedText: 代码富文本。
    ///   - showsLineNumbers: 是否含行号栏。
    ///   - maxViewWidth: 视图最大宽度（0 不限制）。
    ///   - maxViewHeight: 视图最大高度（0 不限制）。
    ///   - maxCellWidth: 单行代码最大宽度（>0 换行）。
    ///   - allowsHorizontalScroll: 代码区是否允许水平滚动（影响宽度是否被裁剪）。
    ///   - codeFont / lineNumberFont: 字体（用于空行测高与行号栏宽度）。
    ///   - headerHeight / footerHeight: 头 / 尾视图高度（外部已知时传入）。
    /// - Returns: 建议的整体尺寸。
    public static func calculateSize(attributedText: NSAttributedString?,
                                     showsLineNumbers: Bool = true,
                                     maxViewWidth: CGFloat = 0,
                                     maxViewHeight: CGFloat = 0,
                                     maxCellWidth: CGFloat = 0,
                                     allowsHorizontalScroll: Bool = true,
                                     codeFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13),
                                     lineNumberFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13),
                                     headerHeight: CGFloat = 0,
                                     footerHeight: CGFloat = 0) -> CGSize {
        let style = CodeBlockStyle(codeFont: codeFont,
                                   lineNumberFont: lineNumberFont,
                                   gutterHPadding: 8,
                                   cellHPadding: 10,
                                   cellVPadding: 3,
                                   minRowHeight: 18,
                                   maxCellWidth: maxCellWidth,
                                   showsLineNumbers: showsLineNumbers,
                                   allowsHorizontalScroll: allowsHorizontalScroll)
        // 不允许水平滚动时，需要一个可用宽度来换行；没有 maxViewWidth 则无从换行（视为不换行）。
        let availableWidth = maxViewWidth > 0 ? maxViewWidth : .greatestFiniteMagnitude
        let m = measure(attributedText: attributedText, style: style, availableWidth: availableWidth)

        let displayAvailableWidth = maxViewWidth > 0 ? maxViewWidth : (m.gutterWidth + m.codeContentWidth)
        let codeAvailable = max(0, displayAvailableWidth - m.gutterWidth)
        let codeDisplay: CGFloat
        if maxViewWidth > 0 {
            codeDisplay = min(m.codeContentWidth, codeAvailable)
        } else {
            codeDisplay = m.codeContentWidth
        }

        var totalWidth = m.gutterWidth + codeDisplay
        if maxViewWidth > 0 { totalWidth = min(totalWidth, maxViewWidth) }

        var totalHeight = headerHeight + footerHeight + m.rowsHeight
        if maxViewHeight > 0 { totalHeight = min(totalHeight, maxViewHeight) }

        return CGSize(width: ceil(totalWidth), height: ceil(totalHeight))
    }

    // MARK: - 度量核心

    private static func measure(attributedText: NSAttributedString?,
                                style: CodeBlockStyle,
                                availableWidth: CGFloat) -> CodeBlockMetrics {
        var metrics = CodeBlockMetrics()
        guard let full = attributedText, full.length >= 0 else { return metrics }

        // 1) 按 `\n` 拆行（与换行符一一对应；末尾若有 \n 会多出一空行）。
        let ns = full.string as NSString
        var ranges: [NSRange] = []
        var lineStart = 0
        let newline: unichar = 10 // \n
        for i in 0..<ns.length {
            if ns.character(at: i) == newline {
                ranges.append(NSRange(location: lineStart, length: i - lineStart))
                lineStart = i + 1
            }
        }
        ranges.append(NSRange(location: lineStart, length: ns.length - lineStart))

        // 2) 行号栏宽度（按最大行号字符串宽度）。行号数量 = 换行符数 + 1，不受换行影响。
        let lineCount = ranges.count
        var gutterWidth: CGFloat = 0
        if style.showsLineNumbers {
            let maxNumberString = "\(max(1, lineCount))" as NSString
            let numberSize = maxNumberString.size(withAttributes: [.font: style.lineNumberFont])
            gutterWidth = ceil(numberSize.width) + 2 * style.gutterHPadding
        }

        // 3) 决定「换行宽度」：
        //    - 允许水平滚动：按 maxCellWidth 换行（未设则不换行，长行改为水平滚动）；
        //    - 不允许水平滚动：必须在代码区可用宽度内把整行换行展示完整
        //      （行高随内容增大，但行号仍只按 `\n` 计数，不增加）。
        let codeInnerAvailable: CGFloat = availableWidth.isFinite
            ? max(1, availableWidth - gutterWidth - 2 * style.cellHPadding)
            : .greatestFiniteMagnitude
        let maxCellInner: CGFloat = style.maxCellWidth > 0
            ? max(1, style.maxCellWidth - 2 * style.cellHPadding)
            : .greatestFiniteMagnitude
        let wrapWidth: CGFloat = style.allowsHorizontalScroll
            ? maxCellInner
            : min(maxCellInner, codeInnerAvailable)

        // 4) 逐行度量。
        var maxNaturalWidth: CGFloat = 0
        var rowsHeight: CGFloat = 0
        var lines: [CodeLineLayout] = []
        lines.reserveCapacity(ranges.count)

        for (idx, range) in ranges.enumerated() {
            let sub = full.attributedSubstring(from: range)
            // 空行用一个空格 + 代码字体测出单行高度。
            let measureText: NSAttributedString = sub.length > 0
                ? sub
                : NSAttributedString(string: " ", attributes: [.font: style.codeFont])
            let bounds = measureText.boundingRect(
                with: CGSize(width: wrapWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil)
            let h = max(ceil(bounds.height) + 2 * style.cellVPadding, style.minRowHeight)
            let w = ceil(bounds.width)
            lines.append(CodeLineLayout(number: idx + 1, text: sub, height: h, naturalWidth: w))
            maxNaturalWidth = max(maxNaturalWidth, w)
            rowsHeight += h
        }

        metrics.lines = lines
        metrics.gutterWidth = gutterWidth
        metrics.codeContentWidth = maxNaturalWidth + 2 * style.cellHPadding
        metrics.rowsHeight = rowsHeight
        return metrics
    }
}

// MARK: - 数据源 / 代理
@available(iOS 13.0, *)
extension CodeBlockView: UICollectionViewDataSource, UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
        metrics.lines.count
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let line = metrics.lines[indexPath.item]
        if collectionView === gutterCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CodeLineNumberCell.reuseID, for: indexPath) as! CodeLineNumberCell
            cell.configure(number: line.number,
                           height: line.height,
                           font: lineNumberFont,
                           color: lineNumberColor,
                           topPadding: cellVPadding,
                           hPadding: gutterHPadding)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CodeLineCell.reuseID, for: indexPath) as! CodeLineCell
            cell.configure(text: line.text,
                           height: line.height,
                           width: resolvedCodeDisplayWidth,
                           wraps: maxCellWidth > 0 || !allowsHorizontalScroll,
                           topPadding: cellVPadding,
                           hPadding: cellHPadding)
            return cell
        }
    }

    // 双向联动：垂直方向同步两个 collectionView 的偏移；代码区按开关夹取方向。
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        defer { isSyncingScroll = false }

        if scrollView === codeCollectionView {
            if !allowsHorizontalScroll && scrollView.contentOffset.x != 0 {
                scrollView.contentOffset.x = 0
            }
            if !allowsVerticalScroll && scrollView.contentOffset.y != 0 {
                scrollView.contentOffset.y = 0
            }
            if gutterCollectionView.contentOffset.y != scrollView.contentOffset.y {
                gutterCollectionView.contentOffset.y = scrollView.contentOffset.y
            }
        } else if scrollView === gutterCollectionView {
            if codeCollectionView.contentOffset.y != scrollView.contentOffset.y {
                codeCollectionView.contentOffset.y = scrollView.contentOffset.y
            }
        }
    }
}

// MARK: - 行号 Cell

private final class CodeLineNumberCell: UICollectionViewCell {
    static let reuseID = "CodeLineNumberCell"

    private let label = UILabel()
    private var heightConstraint: NSLayoutConstraint!
    private var topConstraint: NSLayoutConstraint!
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.numberOfLines = 1
        contentView.addSubview(label)

        heightConstraint = contentView.heightAnchor.constraint(equalToConstant: 18)
        heightConstraint.priority = .required
        topConstraint = label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3)
        leadingConstraint = label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
        trailingConstraint = label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        NSLayoutConstraint.activate([heightConstraint, topConstraint, leadingConstraint, trailingConstraint])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(number: Int, height: CGFloat, font: UIFont, color: UIColor,
                   topPadding: CGFloat, hPadding: CGFloat) {
        label.font = font
        label.textColor = color
        label.text = "\(number)"
        heightConstraint.constant = height
        topConstraint.constant = topPadding
        leadingConstraint.constant = hPadding
        trailingConstraint.constant = -hPadding
    }
}

// MARK: - 代码行 Cell

private final class CodeLineCell: UICollectionViewCell {
    static let reuseID = "CodeLineCell"

    private let label = UILabel()
    private var heightConstraint: NSLayoutConstraint!
    private var topConstraint: NSLayoutConstraint!
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        contentView.addSubview(label)

        heightConstraint = contentView.heightAnchor.constraint(equalToConstant: 18)
        heightConstraint.priority = .required
        topConstraint = label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3)
        leadingConstraint = label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10)
        trailingConstraint = label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10)
        NSLayoutConstraint.activate([heightConstraint, topConstraint, leadingConstraint, trailingConstraint])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: NSAttributedString, height: CGFloat, width: CGFloat, wraps: Bool,
                   topPadding: CGFloat, hPadding: CGFloat) {
        label.numberOfLines = wraps ? 0 : 1
        label.lineBreakMode = wraps ? .byWordWrapping : .byClipping
        if wraps, width > 0 {
            label.preferredMaxLayoutWidth = max(1, width - 2 * hPadding)
        } else {
            label.preferredMaxLayoutWidth = 0
        }
        label.attributedText = text
        heightConstraint.constant = height
        topConstraint.constant = topPadding
        leadingConstraint.constant = hPadding
        trailingConstraint.constant = -hPadding
    }
}
