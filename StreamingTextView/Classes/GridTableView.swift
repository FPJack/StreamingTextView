//
//  GridTableView.swift
//  StreamingTextView
//
//  模仿 Flutter `Table` 的网格表格组件，基于 UICollectionView + Compositional Layout 实现。
//
//  特性：
//  1. 每个 item 的宽 / 高自动计算（同列共享宽度、同行共享高度），可设置最大 / 最小宽高；
//     可设置整体左右滑动或上下滑动。
//  2. 表头（首行）可单独设置样式。
//  3. 网格分割线可设置宽度与颜色。
//  4. 整个表格可设置边框（颜色 / 宽度 / 圆角）。
//  5. 通过 Model + Style + Configuration 分层设计，复用性 / 自定义性良好。
//

import UIKit

// MARK: - 样式

/// 单元格样式（表头与普通单元格可分别配置；单个 Model 也可覆盖）。
public struct GridCellStyle {

    /// 文字字体。
    public var font: UIFont = .systemFont(ofSize: 15)
    /// 文字颜色。
    public var textColor: UIColor = .darkText
    /// 单元格背景色。
    public var backgroundColor: UIColor = .white
    /// 文字对齐。
    public var textAlignment: NSTextAlignment = .left
    /// 文字最大行数（0 表示不限制）。
    public var numberOfLines: Int = 0
    /// 文字四周内边距。
    public var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    public init() {}
}

/// 网格分割线样式。
public struct GridSeparatorStyle {
    /// 分割线粗细（即单元格之间的间隙宽度）。
    public var width: CGFloat = 1.0 / UIScreen.main.scale
    /// 分割线颜色。
    public var color: UIColor = UIColor(white: 0.85, alpha: 1.0)

    public init() {}
    public init(width: CGFloat, color: UIColor) {
        self.width = width
        self.color = color
    }
}

/// 表格外边框样式。
public struct GridBorderStyle {
    /// 边框宽度。
    public var width: CGFloat = 1.0 / UIScreen.main.scale
    /// 边框颜色。
    public var color: UIColor = UIColor(white: 0.82, alpha: 1.0)
    /// 边框圆角。
    public var cornerRadius: CGFloat = 8.0

    public init() {}
    public init(width: CGFloat, color: UIColor, cornerRadius: CGFloat) {
        self.width = width
        self.color = color
        self.cornerRadius = cornerRadius
    }
}

/// 表格滑动模式。
public enum GridScrollMode {
    /// 同时支持左右 + 上下滑动。
    case both
    /// 仅左右滑动（锁定纵向）。
    case horizontal
    /// 仅上下滑动（锁定横向）。
    case vertical
}

/// 表格整体配置。
public struct GridTableConfiguration {

    /// 滑动模式：`.both` 双向、`.horizontal` 仅左右、`.vertical` 仅上下。
    public var scrollMode: GridScrollMode = .both

    /// 列最大宽度（0 表示不限制，宽度完全由内容决定）。
    public var maxColumnWidth: CGFloat = 0
    /// 列最小宽度（0 表示不限制）。
    public var minColumnWidth: CGFloat = 0
    /// 行最大高度（0 表示不限制）。
    public var maxRowHeight: CGFloat = 0
    /// 行最小高度（0 表示不限制）。
    public var minRowHeight: CGFloat = 0

    /// 当内容总宽度小于表格可用宽度时，是否把剩余宽度按各列内容宽度比例分摊，填满宽度。
    public var stretchColumnsToFill: Bool = false
    /// 当内容总高度小于表格可用高度时，是否把剩余高度按各行内容高度比例分摊，填满高度。
    public var stretchRowsToFill: Bool = false

    /// 是否支持双指捏合缩放整个表格。
    public var zoomEnabled: Bool = false
    /// 最小缩放系数。
    public var minZoomScale: CGFloat = 0.5
    /// 最大缩放系数。
    public var maxZoomScale: CGFloat = 3.0

    /// 表格自适应的最大宽度（0 表示不限制）。用于 `intrinsicContentSize`。
    public var maxTableWidth: CGFloat = 0
    /// 表格自适应的最小宽度（0 表示不限制）。
    public var minTableWidth: CGFloat = 0
    /// 表格自适应的最大高度（0 表示不限制）。超出后内容可滚动。
    public var maxTableHeight: CGFloat = 0
    /// 表格自适应的最小高度（0 表示不限制）。
    public var minTableHeight: CGFloat = 0

    /// 是否把首行作为表头（使用 `headerStyle`）。
    public var hasHeaderRow: Bool = true

    /// 表头是否吸顶（滚动时首行固定在顶部，仅在 `hasHeaderRow == true` 时生效）。
    public var stickyHeader: Bool = false

    /// 普通单元格默认样式。
    public var cellStyle = GridCellStyle()
    /// 表头样式（`hasHeaderRow == true` 时用于首行）。
    public var headerStyle: GridCellStyle = {
        var s = GridCellStyle()
        s.font = .boldSystemFont(ofSize: 15)
        s.textColor = .black
        s.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
        return s
    }()

    /// 分割线样式。
    public var separator = GridSeparatorStyle()
    /// 外边框样式。
    public var border = GridBorderStyle()

    public init() {}
}

// MARK: - 数据模型

/// 单元格数据模型。
public struct GridCellModel {
    /// 纯文本内容（与 `attributedText` 二选一）。
    public var text: String?
    /// 富文本内容（优先于 `text`）。
    public var attributedText: NSAttributedString?
    /// 单元格样式覆盖（为 nil 时使用表格配置里的默认 / 表头样式）。
    public var styleOverride: GridCellStyle?

    /// 自定义视图提供者（返回一个 UIView 填充到单元格内）。设置后优先于文本内容。
    public var customView: (() -> UIView)?
    /// 使用自定义视图时的内容尺寸（用于自动布局测量；不含内边距）。
    public var customViewSize: CGSize?

    public init(text: String?, styleOverride: GridCellStyle? = nil) {
        self.text = text
        self.styleOverride = styleOverride
    }

    public init(attributedText: NSAttributedString, styleOverride: GridCellStyle? = nil) {
        self.attributedText = attributedText
        self.styleOverride = styleOverride
    }

    /// 使用自定义视图初始化。
    /// - Parameters:
    ///   - customView: 返回自定义视图的闭包（每次配置单元格时调用）。
    ///   - size: 自定义视图内容尺寸（用于测量布局）。
    ///   - styleOverride: 可选样式（主要用背景色 / 内边距）。
    public init(customView: @escaping () -> UIView, size: CGSize, styleOverride: GridCellStyle? = nil) {
        self.customView = customView
        self.customViewSize = size
        self.styleOverride = styleOverride
    }
}

// MARK: - 单元格

final class GridTextCell: UICollectionViewCell {

    static let reuseID = "GridTextCell"

    private let label = UILabel()
    private var insetConstraints: [NSLayoutConstraint] = []
    /// 当前承载的自定义视图（复用时移除）。
    private var hostedView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        let top = label.topAnchor.constraint(equalTo: contentView.topAnchor)
        let left = label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        let right = label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        let bottom = label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        insetConstraints = [top, left, right, bottom]
        NSLayoutConstraint.activate(insetConstraints)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostedView?.removeFromSuperview()
        hostedView = nil
        label.isHidden = false
    }

    func configure(model: GridCellModel, style: GridCellStyle, zoom: CGFloat = 1) {
        contentView.backgroundColor = style.backgroundColor

        // 应用内边距（随缩放）。
        insetConstraints[0].constant = style.contentInsets.top * zoom
        insetConstraints[1].constant = style.contentInsets.left * zoom
        insetConstraints[2].constant = -style.contentInsets.right * zoom
        insetConstraints[3].constant = -style.contentInsets.bottom * zoom

        // 自定义视图优先。
        if let provider = model.customView {
            label.isHidden = true
            let v = provider()
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: contentView.topAnchor, constant: style.contentInsets.top * zoom),
                v.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: style.contentInsets.left * zoom),
                v.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -style.contentInsets.right * zoom),
                v.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -style.contentInsets.bottom * zoom),
            ])
            hostedView = v
            return
        }

        label.isHidden = false
        label.numberOfLines = style.numberOfLines
        label.textAlignment = style.textAlignment
        if let attributed = model.attributedText {
            label.attributedText = zoom == 1 ? attributed : GridTextCell.scaledAttributedString(attributed, zoom: zoom)
        } else {
            label.text = model.text
            label.font = style.font.withSize(style.font.pointSize * zoom)
            label.textColor = style.textColor
        }
    }

    /// 把富文本里的字号按缩放系数放大 / 缩小。
    static func scaledAttributedString(_ attributed: NSAttributedString, zoom: CGFloat) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: attributed)
        m.enumerateAttribute(.font, in: NSRange(location: 0, length: m.length), options: []) { value, range, _ in
            if let font = value as? UIFont {
                m.addAttribute(.font, value: font.withSize(font.pointSize * zoom), range: range)
            }
        }
        return m
    }
}

// MARK: - 表格视图

@available(iOS 13.0, *)
public class GridTableView: UIView, UICollectionViewDataSource {

    // MARK: 公开接口

    /// 表格配置。修改后需调用 `reload()` 生效。
    public var configuration = GridTableConfiguration()

    /// 表格数据：二维数组 `rows[row][column]`。要求每行列数一致。
    public private(set) var rows: [[GridCellModel]] = []

    /// 单元格点击回调（行、列、模型）。
    public var onSelectCell: ((_ row: Int, _ column: Int, _ model: GridCellModel) -> Void)?

    /// 表格自适应尺寸（`intrinsicContentSize`）发生变化时的回调。
    /// 常用于流式打印过程中随行数增长实时拿到新的宽高，外部据此更新约束 / 布局。
    public var onContentSizeChanged: ((CGSize) -> Void)?

    /// 上次已通知的尺寸，用于去重（仅在变化时回调）。
    private var lastNotifiedSize: CGSize = .zero

    /// 设置数据并刷新。
    /// - Parameters:
    ///   - rows: 二维单元格数据。
    ///   - configuration: 可选，新的表格配置。
    public func setRows(_ rows: [[GridCellModel]], configuration: GridTableConfiguration? = nil) {
        if let configuration = configuration { self.configuration = configuration }
        self.rows = rows
        // 重置逐行流式状态（如需流式，调用 startRowStreaming）。
        stopRowStreamingTimer()
        isStreamingRows = false
        streamedRowLimit = rows.count
        reload()
    }

    /// 重新计算尺寸并刷新布局。
    public func reload() {
        recomputeCounts()
        computeSizes()
        applyStretch(availableWidth: collectionView.bounds.width, availableHeight: collectionView.bounds.height)
        applyBorderAndSeparatorColor()
        applyScrollMode()
        buildStickyHeader()
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
        lastLaidOutSize = collectionView.bounds.size
        notifyContentSizeChangeIfNeeded()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // 尺寸变化且开启了填充时，重新按新的可用尺寸分摊剩余空间并刷新布局。
        let size = collectionView.bounds.size
        guard size != lastLaidOutSize else { return }
        lastLaidOutSize = size
        guard configuration.stretchColumnsToFill || configuration.stretchRowsToFill,
              columnCount > 0 else { return }
        applyStretch(availableWidth: size.width, availableHeight: size.height)
        buildStickyHeader()
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        invalidateIntrinsicContentSize()
        notifyContentSizeChangeIfNeeded()
    }

    // MARK: 私有状态

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: bounds, collectionViewLayout: UICollectionViewFlowLayout())
        cv.backgroundColor = .white
        cv.dataSource = self
        cv.delegate = self
        cv.register(GridTextCell.self, forCellWithReuseIdentifier: GridTextCell.reuseID)
        cv.alwaysBounceVertical = false
        cv.alwaysBounceHorizontal = false
        cv.bounces = false   // 关闭滑动到边界时的弹性效果
        return cv
    }()

    /// 吸顶表头容器（横向可随内容同步偏移，但不接收交互）。
    private lazy var headerScroll: UIScrollView = {
        let sv = UIScrollView()
        sv.isUserInteractionEnabled = false
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    private let headerContent = UIView()

    private var rowCount = 0
    private var columnCount = 0
    /// 内容测量得到的原始列宽 / 行高（未拉伸）。
    private var baseColumnWidths: [CGFloat] = []
    private var baseRowHeights: [CGFloat] = []
    /// 最终展示用列宽 / 行高（可能包含拉伸后的分摊）。
    private var columnWidths: [CGFloat] = []
    private var rowHeights: [CGFloat] = []
    /// 上次布局时集合视图的尺寸，用于在尺寸变化时重新分摊剩余空间。
    private var lastLaidOutSize: CGSize = .zero
    /// 当前缩放系数（捏合缩放）。
    private var zoomScale: CGFloat = 1
    private weak var pinchGesture: UIPinchGestureRecognizer?

    /// 逐行流式打印状态。
    private var isStreamingRows = false
    /// 当前已揭示的行数（含表头行）。
    private var streamedRowLimit = 0
    private var streamTimer: Timer?
    private var streamRowInterval: TimeInterval = 0.15
    private var streamAnimated = true
    /// 全部行揭示完成回调。
    public var onRowStreamingFinished: (() -> Void)?

    /// 当前实际参与渲染的行数（流式时受 `streamedRowLimit` 限制）。
    private var effectiveRowCount: Int {
        guard isStreamingRows else { return rowCount }
        return min(max(streamedRowLimit, 0), rowCount)
    }

    /// 吸顶生效时，网格渲染从第 1 行开始（第 0 行由吸顶表头单独渲染）。
    private var gridRowOffset: Int {
        (configuration.stickyHeader && configuration.hasHeaderRow && rowCount > 0) ? 1 : 0
    }
    /// 参与网格渲染的行数（流式时受 `effectiveRowCount` 限制）。
    private var gridRowCount: Int { max(effectiveRowCount - gridRowOffset, 0) }

    private var headerHeightConstraint: NSLayoutConstraint!
    private var collectionTopConstraint: NSLayoutConstraint!

    /// 表格头部自定义视图（位于吸顶表头之上，固定不随内容滚动；可放复制等操作控件）。
    public private(set) var tableHeaderView: UIView?
    /// 表格尾部自定义视图（位于内容底部，固定不随内容滚动）。
    public private(set) var tableFooterView: UIView?
    private var tableHeaderHeight: CGFloat = 0
    private var tableFooterHeight: CGFloat = 0
    /// 头 / 尾视图 + 垂直约束链（随头尾视图变化重建）。
    private var accessoryConstraints: [NSLayoutConstraint] = []

    // MARK: 初始化

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        streamTimer?.invalidate()
    }

    private func setup() {
        clipsToBounds = true

        headerScroll.translatesAutoresizingMaskIntoConstraints = false
        headerScroll.addSubview(headerContent)
        addSubview(headerScroll)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)

        // 捏合缩放手势（默认不启用，reload 时按配置开关）。
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collectionView.addGestureRecognizer(pinch)
        pinchGesture = pinch

        headerHeightConstraint = headerScroll.heightAnchor.constraint(equalToConstant: 0)
        collectionTopConstraint = collectionView.topAnchor.constraint(equalTo: headerScroll.bottomAnchor)

        // 静态的水平约束 + 吸顶表头高度 + 集合视图相对吸顶表头的间距。
        NSLayoutConstraint.activate([
            headerScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerScroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerHeightConstraint,
            collectionTopConstraint,
        ])

        rebuildVerticalChain()
    }

    // MARK: 头 / 尾自定义视图

    /// 设置表格头部自定义视图（固定在最顶部）。
    /// - Parameters:
    ///   - view: 自定义视图；传 nil 表示移除。
    ///   - height: 固定高度（<=0 时由视图自身的 Auto Layout 约束决定高度）。
    public func setTableHeaderView(_ view: UIView?, height: CGFloat = 0) {
        tableHeaderView?.removeFromSuperview()
        tableHeaderView = view
        tableHeaderHeight = height
        if let v = view {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        rebuildVerticalChain()
    }

    /// 设置表格尾部自定义视图（固定在最底部）。
    /// - Parameters:
    ///   - view: 自定义视图；传 nil 表示移除。
    ///   - height: 固定高度（<=0 时由视图自身的 Auto Layout 约束决定高度）。
    public func setTableFooterView(_ view: UIView?, height: CGFloat = 0) {
        tableFooterView?.removeFromSuperview()
        tableFooterView = view
        tableFooterHeight = height
        if let v = view {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        rebuildVerticalChain()
    }

    /// 重建「头部视图 → 吸顶表头 → 集合视图 → 尾部视图」的垂直约束链。
    private func rebuildVerticalChain() {
        NSLayoutConstraint.deactivate(accessoryConstraints)
        accessoryConstraints.removeAll()

        // 顶部：可选头部视图 → 吸顶表头。
        var topRef = topAnchor
        if let h = tableHeaderView {
            accessoryConstraints.append(contentsOf: [
                h.topAnchor.constraint(equalTo: topAnchor),
                h.leadingAnchor.constraint(equalTo: leadingAnchor),
                h.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            if tableHeaderHeight > 0 {
                accessoryConstraints.append(h.heightAnchor.constraint(equalToConstant: tableHeaderHeight))
            }
            topRef = h.bottomAnchor
        }
        accessoryConstraints.append(headerScroll.topAnchor.constraint(equalTo: topRef))

        // 底部：集合视图 → 可选尾部视图。
        var bottomRef = bottomAnchor
        if let f = tableFooterView {
            accessoryConstraints.append(contentsOf: [
                f.bottomAnchor.constraint(equalTo: bottomAnchor),
                f.leadingAnchor.constraint(equalTo: leadingAnchor),
                f.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            if tableFooterHeight > 0 {
                accessoryConstraints.append(f.heightAnchor.constraint(equalToConstant: tableFooterHeight))
            }
            bottomRef = f.topAnchor
        }
        accessoryConstraints.append(collectionView.bottomAnchor.constraint(equalTo: bottomRef))

        NSLayoutConstraint.activate(accessoryConstraints)
    }

    // MARK: 尺寸计算

    private func recomputeCounts() {
        rowCount = rows.count
        columnCount = rows.map { $0.count }.max() ?? 0
    }

    /// 取某行某列的有效样式（Model 覆盖 > 表头 / 默认样式）。
    private func effectiveStyle(row: Int, column: Int) -> GridCellStyle {
        if let override = model(row: row, column: column)?.styleOverride { return override }
        if configuration.hasHeaderRow && row == 0 { return configuration.headerStyle }
        return configuration.cellStyle
    }

    private func model(row: Int, column: Int) -> GridCellModel? {
        guard row >= 0, row < rows.count else { return nil }
        let cols = rows[row]
        guard column >= 0, column < cols.count else { return nil }
        return cols[column]
    }

    /// 计算列宽（同列取最大内容宽，受 min/max 约束）与行高（同行取最大内容高）。
    private func computeSizes() {
        guard rowCount > 0, columnCount > 0 else {
            baseColumnWidths = []; baseRowHeights = []
            columnWidths = []; rowHeights = []; return
        }
        // 复用静态计算（zoom = 1 得到原始内容尺寸）。
        let sizes = GridTableView.calculateColumnRowSizes(rows: rows, configuration: configuration, zoom: 1)
        baseColumnWidths = sizes.columnWidths
        baseRowHeights = sizes.rowHeights
        // 初始展示尺寸 = 原始尺寸（拉伸在 applyStretch 中按可用尺寸计算）。
        columnWidths = baseColumnWidths
        rowHeights = baseRowHeights
    }

    /// 计算展示尺寸：先按缩放系数缩放内容尺寸，再（可选）把剩余空间按比例分摊填充。
    private func applyStretch(availableWidth: CGFloat, availableHeight: CGFloat) {
        guard columnCount > 0 else { return }
        // 1) 先按 zoom 缩放原始内容尺寸。
        columnWidths = baseColumnWidths.map { ceil($0 * zoomScale) }
        rowHeights = baseRowHeights.map { ceil($0 * zoomScale) }
        let sep = configuration.separator.width

        // 2) 列：分摊剩余宽度（以缩放后的尺寸为基准）。
        if configuration.stretchColumnsToFill {
            let zoomed = columnWidths
            let content = zoomed.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))
            let extra = availableWidth - content
            if extra > 0.5 {
                let baseSum = zoomed.reduce(0, +)
                if baseSum > 0 {
                    for i in 0..<columnCount {
                        columnWidths[i] = zoomed[i] + extra * (zoomed[i] / baseSum)
                    }
                } else {
                    let each = extra / CGFloat(columnCount)
                    columnWidths = zoomed.map { $0 + each }
                }
            }
        }

        // 3) 行：仅对参与网格渲染的行分摊剩余高度（吸顶表头行不拉伸）。
        if configuration.stretchRowsToFill, gridRowCount > 0 {
            let start = gridRowOffset
            let zoomed = Array(rowHeights[start...])
            let content = zoomed.reduce(0, +) + sep * CGFloat(max(gridRowCount - 1, 0))
            let extra = availableHeight - content
            if extra > 0.5 {
                let baseSum = zoomed.reduce(0, +)
                if baseSum > 0 {
                    for (idx, i) in (start..<rowCount).enumerated() {
                        rowHeights[i] = zoomed[idx] + extra * (zoomed[idx] / baseSum)
                    }
                } else {
                    let each = extra / CGFloat(gridRowCount)
                    for i in start..<rowCount { rowHeights[i] = rowHeights[i] + each }
                }
            }
        }
    }

    // MARK: 缩放

    /// 捏合缩放手势处理。
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard configuration.zoomEnabled, columnCount > 0 else { return }
        switch gesture.state {
        case .changed:
            let newScale = min(max(zoomScale * gesture.scale, configuration.minZoomScale), configuration.maxZoomScale)
            gesture.scale = 1
            guard abs(newScale - zoomScale) > 0.001 else { return }
            zoomScale = newScale
            applyStretch(availableWidth: collectionView.bounds.width, availableHeight: collectionView.bounds.height)
            buildStickyHeader()
            collectionView.setCollectionViewLayout(makeLayout(), animated: false)
            collectionView.reloadData()
            invalidateIntrinsicContentSize()
            notifyContentSizeChangeIfNeeded()
        default:
            break
        }
    }

    /// 测量单元格内容尺寸（含内边距）。
    private func measure(_ model: GridCellModel, style: GridCellStyle, maxWidth: CGFloat) -> CGSize {
        GridTableView.measureCell(model, style: style, maxWidth: maxWidth)
    }

    // MARK: 逐行流式打印

    /// 开始逐行流式打印表格：按行依次揭示（每行淡入 + 表格高度动态增长）。
    /// 需在 `setRows(_:configuration:)` 之后调用。
    /// - Parameters:
    ///   - rowInterval: 每行出现的时间间隔（秒）。
    ///   - animated: 是否使用插入淡入 / 高度增长动画。
    public func startRowStreaming(rowInterval: TimeInterval = 0.15, animated: Bool = true) {
        stopRowStreamingTimer()
        guard rowCount > 0 else { return }
        isStreamingRows = true
        streamRowInterval = max(rowInterval, 0.01)
        streamAnimated = animated
        // 表头行（若有）先显示；否则从 0 行开始。
        streamedRowLimit = configuration.hasHeaderRow ? min(1, rowCount) : 0
        reload()

        if streamedRowLimit >= rowCount {
            finishRowStreaming()
            return
        }
        streamTimer = Timer.scheduledTimer(withTimeInterval: streamRowInterval, repeats: true) { [weak self] _ in
            self?.revealNextRow()
        }
    }

    /// 立即结束流式，揭示全部行。
    public func stopRowStreaming() {
        guard isStreamingRows else { return }
        stopRowStreamingTimer()
        streamedRowLimit = rowCount
        reload()
        finishRowStreaming()
    }

    private func stopRowStreamingTimer() {
        streamTimer?.invalidate()
        streamTimer = nil
    }

    private func finishRowStreaming() {
        isStreamingRows = false
        onRowStreamingFinished?()
    }

    /// 揭示下一行（带插入动画）。
    private func revealNextRow() {
        guard streamedRowLimit < rowCount else {
            stopRowStreamingTimer()
            finishRowStreaming()
            return
        }
        let oldItemCount = gridRowCount * columnCount
        streamedRowLimit += 1
        let newItemCount = gridRowCount * columnCount
        guard newItemCount > oldItemCount else { return }

        let indexPaths = (oldItemCount..<newItemCount).map { IndexPath(item: $0, section: 0) }

        // 仅在「视图已在窗口层级 && App 处于前台」时才做批量插入动画；
        // 否则（如 App 退后台 / 视图不在窗口）UICollectionView 的 performBatchUpdates
        // 可能崩溃，降级为 reloadData 以保证安全。
        if streamAnimated && canAnimateCollectionUpdates {
            collectionView.performBatchUpdates({
                collectionView.insertItems(at: indexPaths)
            }, completion: nil)
            // 表格整体高度随之增长（动画）。
            invalidateIntrinsicContentSize()
            notifyContentSizeChangeIfNeeded()
            UIView.animate(withDuration: streamRowInterval) { self.superview?.layoutIfNeeded() }
        } else {
            collectionView.reloadData()
            invalidateIntrinsicContentSize()
            notifyContentSizeChangeIfNeeded()
        }

        if streamedRowLimit >= rowCount {
            stopRowStreamingTimer()
            finishRowStreaming()
        }
    }

    /// 是否可以安全地对集合视图做批量更新动画：
    /// 需要视图已加入窗口层级，且 App 处于前台（后台时 UICollectionView 批量更新会崩溃）。
    private var canAnimateCollectionUpdates: Bool {
        guard window != nil else { return false }
        return UIApplication.shared.applicationState == .active
    }

    // MARK: 布局

    private func makeLayout() -> UICollectionViewLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        // `.horizontal` 模式主轴设为横向；`.both` / `.vertical` 用纵向（横向溢出由绝对宽度自然产生可滚动内容）。
        config.scrollDirection = (configuration.scrollMode == .horizontal) ? .horizontal : .vertical

        // 双向滑动时用会在任意方向 bounds 变化都重算可见属性的子类，避免斜向快速滑动漏掉 cell。
        let layout = GridCompositionalLayout(sectionProvider: { [weak self] _, _ in
            self?.makeSection()
        }, configuration: config)
        return layout
    }

    /// 按滑动模式设置集合视图的滚动 / 回弹 / 指示器行为。
    private func applyScrollMode() {
        // 关闭边界弹性（水平 + 垂直）。
        collectionView.bounces = false
        collectionView.alwaysBounceHorizontal = false
        collectionView.alwaysBounceVertical = false
        switch configuration.scrollMode {
        case .both:
            collectionView.showsHorizontalScrollIndicator = true
            collectionView.showsVerticalScrollIndicator = true
        case .horizontal:
            collectionView.showsHorizontalScrollIndicator = true
            collectionView.showsVerticalScrollIndicator = false
        case .vertical:
            collectionView.showsHorizontalScrollIndicator = false
            collectionView.showsVerticalScrollIndicator = true
        }
    }

    private func makeSection() -> NSCollectionLayoutSection? {
        guard gridRowCount > 0, columnCount > 0 else { return nil }
        let sep = configuration.separator.width
        let start = gridRowOffset

        // 每一行是一个横向 group，group 内每个 item 用「绝对列宽 × 绝对行高」。
        var rowGroups: [NSCollectionLayoutItem] = []
        for r in start..<effectiveRowCount {
            let rowHeight = rowHeights[r]
            var items: [NSCollectionLayoutItem] = []
            for c in 0..<columnCount {
                let size = NSCollectionLayoutSize(widthDimension: .absolute(max(columnWidths[c], 1)),
                                                  heightDimension: .absolute(max(rowHeight, 1)))
                items.append(NSCollectionLayoutItem(layoutSize: size))
            }
            let totalWidth = columnWidths.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))
            let rowSize = NSCollectionLayoutSize(widthDimension: .absolute(max(totalWidth, 1)),
                                                 heightDimension: .absolute(max(rowHeight, 1)))
            let rowGroup = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: items)
            rowGroup.interItemSpacing = .fixed(sep)
            rowGroups.append(rowGroup)
        }

        let totalWidth = columnWidths.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))
        let gridHeights = rowHeights[start..<effectiveRowCount]
        let totalHeight = gridHeights.reduce(0, +) + sep * CGFloat(max(gridRowCount - 1, 0))
        let containerSize = NSCollectionLayoutSize(widthDimension: .absolute(max(totalWidth, 1)),
                                                   heightDimension: .absolute(max(totalHeight, 1)))
        let outer = NSCollectionLayoutGroup.vertical(layoutSize: containerSize, subitems: rowGroups)
        outer.interItemSpacing = .fixed(sep)

        return NSCollectionLayoutSection(group: outer)
    }

    /// 构建吸顶表头（把第 0 行单独渲染到 headerScroll 内）。
    private func buildStickyHeader() {
        headerContent.subviews.forEach { $0.removeFromSuperview() }

        guard gridRowOffset == 1, columnCount > 0 else {
            // 不吸顶：隐藏表头容器。
            headerHeightConstraint.constant = 0
            collectionTopConstraint.constant = 0
            headerScroll.isHidden = true
            return
        }

        headerScroll.isHidden = false
        let sep = configuration.separator.width
        let h = rowHeights[0]
        headerScroll.backgroundColor = configuration.separator.color
        headerContent.backgroundColor = configuration.separator.color

        var x: CGFloat = 0
        for c in 0..<columnCount {
            let w = columnWidths[c]
            let style = effectiveStyle(row: 0, column: c)
            let cellView = makeHeaderCellView(model: model(row: 0, column: c), style: style,
                                              frame: CGRect(x: x, y: 0, width: w, height: h))
            headerContent.addSubview(cellView)
            x += w + sep
        }

        let totalWidth = columnWidths.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))
        headerContent.frame = CGRect(x: 0, y: 0, width: totalWidth, height: h)
        headerScroll.contentSize = CGSize(width: totalWidth, height: h)
        headerHeightConstraint.constant = h
        collectionTopConstraint.constant = sep   // 表头与首行之间留一条分割线
        headerScroll.contentOffset = CGPoint(x: collectionView.contentOffset.x, y: 0)
    }

    /// 生成一个吸顶表头单元格视图。
    private func makeHeaderCellView(model: GridCellModel?, style: GridCellStyle, frame: CGRect) -> UIView {
        let container = UIView(frame: frame)
        container.backgroundColor = style.backgroundColor
        let insets = UIEdgeInsets(top: style.contentInsets.top * zoomScale,
                                  left: style.contentInsets.left * zoomScale,
                                  bottom: style.contentInsets.bottom * zoomScale,
                                  right: style.contentInsets.right * zoomScale)

        if let provider = model?.customView {
            let v = provider()
            v.frame = CGRect(x: insets.left, y: insets.top,
                             width: frame.width - insets.left - insets.right,
                             height: frame.height - insets.top - insets.bottom)
            container.addSubview(v)
            return container
        }

        let label = UILabel(frame: CGRect(x: insets.left, y: insets.top,
                                          width: frame.width - insets.left - insets.right,
                                          height: frame.height - insets.top - insets.bottom))
        label.numberOfLines = style.numberOfLines
        label.textAlignment = style.textAlignment
        if let attributed = model?.attributedText {
            label.attributedText = zoomScale == 1 ? attributed : GridTextCell.scaledAttributedString(attributed, zoom: zoomScale)
        } else {
            label.text = model?.text
            label.font = style.font.withSize(style.font.pointSize * zoomScale)
            label.textColor = style.textColor
        }
        container.addSubview(label)
        return container
    }

    /// 应用外边框与「用背景色模拟分割线」。
    private func applyBorderAndSeparatorColor() {
        // 分割线：单元格之间留 `separator.width` 的间隙，露出背景色即为分割线颜色。
        collectionView.backgroundColor = configuration.separator.color
        backgroundColor = .white

        // 外边框 + 圆角（作用在整个表格容器上，裁剪四角）。
        let border = configuration.border
        layer.borderWidth = border.width
        layer.borderColor = border.color.cgColor
        layer.cornerRadius = border.cornerRadius
        layer.masksToBounds = true

        // 容器已负责边框圆角，集合视图自身不再重复。
        collectionView.layer.borderWidth = 0
        collectionView.layer.cornerRadius = 0
    }

    // MARK: 尺寸自适应

    /// 网格内容总尺寸（含分割线间隙，不含头 / 尾视图）。
    public var contentSize: CGSize {
        let sep = configuration.separator.width
        let w = columnWidths.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))
        let h = rowHeights.reduce(0, +) + sep * CGFloat(max(rowCount - 1, 0))
        return CGSize(width: w, height: h)
    }

    /// 头 / 尾自定义视图的高度（优先用显式高度，否则用视图自身的合适高度）。
    private func accessoryHeight(_ view: UIView?, explicit: CGFloat) -> CGFloat {
        guard let view = view else { return 0 }
        if explicit > 0 { return explicit }
        let intrinsic = view.intrinsicContentSize.height
        if intrinsic > 0, intrinsic != UIView.noIntrinsicMetric { return intrinsic }
        let fitting = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return fitting > 0 ? fitting : view.bounds.height
    }

    /// 表格自适应尺寸：网格内容 + 头 / 尾视图，并限制到最大 / 最小宽高。
    public override var intrinsicContentSize: CGSize {
        let sep = configuration.separator.width

        var w = columnWidths.reduce(0, +) + sep * CGFloat(max(columnCount - 1, 0))

        // 网格高度（仅统计已揭示的行；吸顶时表头与首行之间多一条分割线间隙）。
        let visRows = effectiveRowCount
        var gridHeight = rowHeights.prefix(visRows).reduce(0, +) + sep * CGFloat(max(visRows - 1, 0))
        if gridRowOffset == 1 { gridHeight += sep }

        var h = gridHeight
            + accessoryHeight(tableHeaderView, explicit: tableHeaderHeight)
            + accessoryHeight(tableFooterView, explicit: tableFooterHeight)

        // 限制到最大 / 最小。
        if configuration.maxTableWidth > 0 { w = min(w, configuration.maxTableWidth) }
        if configuration.minTableWidth > 0 { w = max(w, configuration.minTableWidth) }
        if configuration.maxTableHeight > 0 { h = min(h, configuration.maxTableHeight) }
        if configuration.minTableHeight > 0 { h = max(h, configuration.minTableHeight) }

        if !w.isFinite { w = 0 }
        if !h.isFinite { h = 0 }
        return CGSize(width: ceil(w), height: ceil(h))
    }

    /// 若表格自适应尺寸发生变化，则回调通知外部（去重）。
    private func notifyContentSizeChangeIfNeeded() {
        let size = intrinsicContentSize
        guard size != lastNotifiedSize else { return }
        lastNotifiedSize = size
        onContentSizeChanged?(size)
    }

    // MARK: - 提前计算尺寸（无需实例化 / 加入视图层级）

    /// 提前计算「网格内容」尺寸（列宽合计 × 行高合计，含分割线；不含头 / 尾视图，不裁剪 min/max）。
    /// - Parameters:
    ///   - rows: 二维单元格数据。
    ///   - configuration: 表格配置。
    ///   - zoom: 缩放系数（默认 1）。
    public static func calculateContentSize(for rows: [[GridCellModel]],
                                            configuration: GridTableConfiguration,
                                            zoom: CGFloat = 1) -> CGSize {
        let (cols, rowsH) = calculateColumnRowSizes(rows: rows, configuration: configuration, zoom: zoom)
        let sep = configuration.separator.width
        let w = cols.reduce(0, +) + sep * CGFloat(max(cols.count - 1, 0))
        let h = rowsH.reduce(0, +) + sep * CGFloat(max(rowsH.count - 1, 0))
        return CGSize(width: ceil(w), height: ceil(h))
    }

    /// 提前计算表格整体自适应尺寸（= 网格内容 + 头 / 尾视图高度，并裁剪到 min/max）。
    /// 与实例的 `intrinsicContentSize` 结果一致，可用于「先算尺寸再布局」避免闪动。
    /// - Parameters:
    ///   - rows: 二维单元格数据。
    ///   - configuration: 表格配置。
    ///   - tableHeaderHeight: 表格头部视图高度（无则传 0）。
    ///   - tableFooterHeight: 表格尾部视图高度（无则传 0）。
    ///   - zoom: 缩放系数（默认 1）。
    public static func calculateFittingSize(for rows: [[GridCellModel]],
                                            configuration: GridTableConfiguration,
                                            tableHeaderHeight: CGFloat = 0,
                                            tableFooterHeight: CGFloat = 0,
                                            zoom: CGFloat = 1) -> CGSize {
        let (cols, rowsH) = calculateColumnRowSizes(rows: rows, configuration: configuration, zoom: zoom)
        let sep = configuration.separator.width
        var w = cols.reduce(0, +) + sep * CGFloat(max(cols.count - 1, 0))
        var h = rowsH.reduce(0, +) + sep * CGFloat(max(rowsH.count - 1, 0))

        // 吸顶时表头与首行之间多一条分割线间隙。
        if configuration.stickyHeader && configuration.hasHeaderRow && !rowsH.isEmpty { h += sep }
        h += max(tableHeaderHeight, 0) + max(tableFooterHeight, 0)

        if configuration.maxTableWidth > 0 { w = min(w, configuration.maxTableWidth) }
        if configuration.minTableWidth > 0 { w = max(w, configuration.minTableWidth) }
        if configuration.maxTableHeight > 0 { h = min(h, configuration.maxTableHeight) }
        if configuration.minTableHeight > 0 { h = max(h, configuration.minTableHeight) }

        return CGSize(width: ceil(w), height: ceil(h))
    }

    /// 提前计算每列宽度与每行高度（提前计算的核心，纯函数）。
    public static func calculateColumnRowSizes(rows: [[GridCellModel]],
                                               configuration: GridTableConfiguration,
                                               zoom: CGFloat = 1) -> (columnWidths: [CGFloat], rowHeights: [CGFloat]) {
        let rowCount = rows.count
        let columnCount = rows.map { $0.count }.max() ?? 0
        guard rowCount > 0, columnCount > 0 else { return ([], []) }

        func model(_ r: Int, _ c: Int) -> GridCellModel? {
            guard r < rows.count, c < rows[r].count else { return nil }
            return rows[r][c]
        }
        func style(_ r: Int, _ c: Int) -> GridCellStyle {
            if let o = model(r, c)?.styleOverride { return o }
            if configuration.hasHeaderRow && r == 0 { return configuration.headerStyle }
            return configuration.cellStyle
        }

        // 1) 原始列宽（未缩放）。
        var baseCol = Array(repeating: CGFloat(0), count: columnCount)
        for c in 0..<columnCount {
            var maxW: CGFloat = 0
            for r in 0..<rowCount {
                guard let m = model(r, c) else { continue }
                let limit = configuration.maxColumnWidth > 0 ? configuration.maxColumnWidth : .greatestFiniteMagnitude
                maxW = max(maxW, measureCell(m, style: style(r, c), maxWidth: limit).width)
            }
            if configuration.maxColumnWidth > 0 { maxW = min(maxW, configuration.maxColumnWidth) }
            if configuration.minColumnWidth > 0 { maxW = max(maxW, configuration.minColumnWidth) }
            baseCol[c] = ceil(maxW)
        }

        // 2) 原始行高（未缩放，用原始列宽测量）。
        var baseRow = Array(repeating: CGFloat(0), count: rowCount)
        for r in 0..<rowCount {
            var maxH: CGFloat = 0
            for c in 0..<columnCount {
                guard let m = model(r, c) else { continue }
                maxH = max(maxH, measureCell(m, style: style(r, c), maxWidth: baseCol[c]).height)
            }
            if configuration.maxRowHeight > 0 { maxH = min(maxH, configuration.maxRowHeight) }
            if configuration.minRowHeight > 0 { maxH = max(maxH, configuration.minRowHeight) }
            baseRow[r] = ceil(maxH)
        }

        // 3) 应用缩放。
        if zoom == 1 { return (baseCol, baseRow) }
        return (baseCol.map { ceil($0 * zoom) }, baseRow.map { ceil($0 * zoom) })
    }

    /// 测量单个单元格内容尺寸（含内边距）。
    static func measureCell(_ model: GridCellModel, style: GridCellStyle, maxWidth: CGFloat) -> CGSize {
        let insets = style.contentInsets

        // 自定义视图：直接用给定内容尺寸 + 内边距。
        if let custom = model.customViewSize {
            var w = custom.width + insets.left + insets.right
            if maxWidth != .greatestFiniteMagnitude { w = min(w, maxWidth) }
            return CGSize(width: ceil(w), height: ceil(custom.height + insets.top + insets.bottom))
        }

        let textMaxWidth: CGFloat = maxWidth == .greatestFiniteMagnitude
            ? maxWidth
            : max(0, maxWidth - insets.left - insets.right)

        let attributed = attributedForMeasure(model, style: style)
        let bounding = attributed.boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil)

        return CGSize(width: ceil(bounding.width) + insets.left + insets.right,
                      height: ceil(bounding.height) + insets.top + insets.bottom)
    }

    /// 生成单元格用于测量的富文本。
    private static func attributedForMeasure(_ model: GridCellModel, style: GridCellStyle) -> NSAttributedString {
        if let attributed = model.attributedText { return attributed }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.textAlignment
        return NSAttributedString(string: model.text ?? "", attributes: [
            .font: style.font,
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraph,
        ])
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gridRowCount * columnCount
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GridTextCell.reuseID,
                                                      for: indexPath) as! GridTextCell
        let (r, c) = position(for: indexPath.item)
        if let m = model(row: r, column: c) {
            cell.configure(model: m, style: effectiveStyle(row: r, column: c), zoom: zoomScale)
        }
        return cell
    }

    /// 线性 item 下标 → (行, 列)。行主序，与布局分组顺序一致；吸顶时需加上偏移。
    private func position(for item: Int) -> (row: Int, column: Int) {
        guard columnCount > 0 else { return (0, 0) }
        return (item / columnCount + gridRowOffset, item % columnCount)
    }
}

// MARK: - UICollectionViewDelegate

@available(iOS 13.0, *)
extension GridTableView: UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let (r, c) = position(for: indexPath.item)
        guard let m = model(row: r, column: c) else { return }
        onSelectCell?(r, c, m)
    }

    /// 横向滚动时，让吸顶表头与内容保持列对齐；单方向模式下锁定另一轴。
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else { return }

        // 单方向锁定：把被锁定轴的偏移强制归零。
        switch configuration.scrollMode {
        case .vertical:
            if collectionView.contentOffset.x != 0 {
                collectionView.contentOffset.x = 0
            }
        case .horizontal:
            if collectionView.contentOffset.y != 0 {
                collectionView.contentOffset.y = 0
            }
        case .both:
            break
        }

        // 吸顶表头与内容横向对齐。
        if !headerScroll.isHidden {
            headerScroll.contentOffset = CGPoint(x: collectionView.contentOffset.x, y: 0)
        }
    }
}

// MARK: - 支持双向滑动的 Compositional Layout

/// Compositional Layout 默认围绕主轴（这里是纵向）计算可见区域，
/// 斜向 / 快速双向滑动时横向新进入可见区的 cell 不会被重新准备，导致空白。
/// 重写 `shouldInvalidateLayout(forBoundsChange:)`，让任意方向的偏移变化都触发
/// 重新计算可见属性，从而修复漏 cell 的问题。
@available(iOS 13.0, *)
final class GridCompositionalLayout: UICollectionViewCompositionalLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}
