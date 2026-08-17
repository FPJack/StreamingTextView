//
//  GridTableAttachment.swift
//  StreamingTextView
//
//  一个「块级」流式文本附件：在富文本里为表格预留空间（占位空白，不绘制内容），
//  真正的 `GridTableView` 作为覆盖视图叠加在占位区域上方。配合 `StreamingTextView`：
//  当文字流式打印到该附件时会暂停文字，先让表格逐行流式打印，表格打印完成后再继续打印
//  后面的文字。
//
//  高度同步：附件初始高度为 0，表格每揭示一行、其内容尺寸变化时，附件会把 `bounds`
//  更新为表格「当前可见部分」的尺寸，并通过 `onLayoutChange` 通知宿主重新排版，
//  使 textView 的高度与表格高度**同步逐行增长**（而不是一开始就撑满整表高度）。
//

import UIKit

@available(iOS 13.0, *)
public class GridTableAttachment: NSTextAttachment, StreamingBlockAttachment {

    /// 表格数据（二维单元格模型）。
    public let rows: [[GridCellModel]]
    /// 表格配置。
    public var configuration: GridTableConfiguration
    /// 逐行流式打印时每行出现的时间间隔（秒）。
    public var rowInterval: TimeInterval = 0.12

    /// 表格完整尺寸（全部行显示时），用于非动画一次性展示。
    private let fullSize: CGSize
    /// 覆盖在占位区域上的真实表格视图。
    private weak var hostedTable: GridTableView?
    /// 尺寸变化时通知宿主重新排版的回调（由 `beginStreaming` 注入）。
    private var onLayoutChange: (() -> Void)?

    /// - Parameters:
    ///   - rows: 二维单元格模型。
    ///   - configuration: 表格配置（列宽 / 分割线 / 边框 / 滑动模式等）。
    public init(rows: [[GridCellModel]], configuration: GridTableConfiguration) {
        self.rows = rows
        self.configuration = configuration
        self.fullSize = GridTableView.calculateFittingSize(for: rows, configuration: configuration)
        super.init(data: nil, ofType: nil)
        // 初始高度为 0（宽度按完整宽度预留），随表格逐行流式增长。
        self.bounds = CGRect(x: 0, y: 0, width: fullSize.width, height: 0)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 附件本身不绘制任何内容（真正的表格由覆盖视图展示），返回透明占位图以稳定排版空间。
    public override func image(forBounds imageBounds: CGRect,
                               textContainer: NSTextContainer?,
                               characterIndex charIndex: Int) -> UIImage? {
        return GridTableAttachment.transparentImage(of: imageBounds.size)
    }

    private static func transparentImage(of size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in }
    }

    private func makeTable() -> GridTableView {
        let table = GridTableView()
        table.backgroundColor = .clear
        table.clipsToBounds = true
        return table
    }

    // MARK: - StreamingBlockAttachment

    public func beginStreaming(in hostView: UIView, frame: CGRect, animated: Bool,
                               onLayoutChange: @escaping () -> Void,
                               completion: @escaping () -> Void) {
        self.onLayoutChange = onLayoutChange

        let table = hostedTable ?? makeTable()
        hostedTable = table
        if table.superview !== hostView { hostView.addSubview(table) }

        // 表格内容尺寸变化时（逐行增高）：同步更新附件 bounds 并请求宿主重新排版。
        // 附件 bounds 变化后，宿主会 invalidate 布局并通过 `updateFrame` 把表格 frame
        // 更新为新的尺寸与位置，实现 textView 高度与表格高度同步增长。
        table.onContentSizeChanged = { [weak self] size in
            guard let self = self else { return }
            self.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            self.onLayoutChange?()
        }

        if animated {
            // 初始摆放在占位起点（高度 0），随逐行回调增长。
            table.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: fullSize.width, height: 0)
            table.onRowStreamingFinished = completion
            table.setRows(rows, configuration: configuration)
            table.startRowStreaming(rowInterval: rowInterval, animated: true)
        } else {
            // 非动画：一次性显示完整表格。
            bounds = CGRect(origin: .zero, size: fullSize)
            table.frame = CGRect(origin: frame.origin, size: fullSize)
            table.setRows(rows, configuration: configuration)
            onLayoutChange()
            completion()
        }
    }

    public func updateFrame(_ frame: CGRect, in hostView: UIView) {
        guard let table = hostedTable else { return }
        if table.superview !== hostView { hostView.addSubview(table) }
        // 只更新位置；尺寸取附件当前预留尺寸（随流式增长）。
        table.frame = CGRect(origin: frame.origin, size: bounds.size)
    }

    public func removeStreamingView() {
        hostedTable?.onContentSizeChanged = nil
        hostedTable?.removeFromSuperview()
        hostedTable = nil
        onLayoutChange = nil
    }
}
