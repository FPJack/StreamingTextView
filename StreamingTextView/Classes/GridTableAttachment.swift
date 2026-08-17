//
//  GridTableAttachment.swift
//  StreamingTextView
//
//  一个「块级」流式文本附件：在富文本里预留出表格的完整尺寸（占位空白，不绘制内容），
//  真正的 `GridTableView` 作为覆盖视图叠加在占位区域上方。配合 `StreamingTextView`：
//  当文字流式打印到该附件时会暂停文字，先让表格逐行流式打印，表格打印完成后再继续打印
//  后面的文字。
//
//  设计要点（性能）：
//  - 附件在创建时就用 `GridTableView.calculateFittingSize` 预先算出表格的完整尺寸，
//    并写入 `bounds`。这样文本排版一开始就为表格预留了固定空间，表格逐行动画期间
//    **不会引起文本回流**，整个滚动内容高度保持稳定，只是表格内部逐行填充。
//  - 覆盖视图作为 textView 的子视图（随内容一起滚动），位置由 `StreamingTextView`
//    根据附件的 glyph 矩形实时对齐。
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

    /// 覆盖在占位区域上的真实表格视图。
    private weak var hostedTable: GridTableView?

    /// - Parameters:
    ///   - rows: 二维单元格模型。
    ///   - configuration: 表格配置（列宽 / 分割线 / 边框 / 滑动模式等）。
    public init(rows: [[GridCellModel]], configuration: GridTableConfiguration) {
        self.rows = rows
        self.configuration = configuration
        super.init(data: nil, ofType: nil)
        // 预先算出表格完整尺寸，写入 bounds，让文本排版为其预留固定空间。
        let size = GridTableView.calculateFittingSize(for: rows, configuration: configuration)
        self.bounds = CGRect(origin: .zero, size: size)
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
        return table
    }

    // MARK: - StreamingBlockAttachment

    public func beginStreaming(in hostView: UIView, frame: CGRect, animated: Bool,
                               completion: @escaping () -> Void) {
        let table = hostedTable ?? makeTable()
        hostedTable = table
        table.frame = frame
        if table.superview !== hostView { hostView.addSubview(table) }

        table.setRows(rows, configuration: configuration)

        if animated {
            table.onRowStreamingFinished = completion
            table.startRowStreaming(rowInterval: rowInterval, animated: true)
        } else {
            // 非动画：直接完整显示，随即回调。
            completion()
        }
    }

    public func updateFrame(_ frame: CGRect, in hostView: UIView) {
        guard let table = hostedTable else { return }
        if table.superview !== hostView { hostView.addSubview(table) }
        // 只更新位置；尺寸保持附件预留的固定尺寸，避免回流。
        table.frame = CGRect(origin: frame.origin, size: bounds.size)
    }

    public func removeStreamingView() {
        hostedTable?.removeFromSuperview()
        hostedTable = nil
    }
}
