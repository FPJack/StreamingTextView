//
//  GridTableViewController.swift
//  StreamingTextView_Example
//
//  GridTableView 演示：展示自动宽高、表头样式、分割线、边框圆角、滑动方向等配置。
//

import UIKit
import StreamingTextView

@available(iOS 13.0, *)
class GridTableViewController: UIViewController {

    private let gridTable = GridTableView()
    /// 三种滑动模式循环切换：双向 → 仅横向 → 仅纵向。
    private var scrollMode: GridScrollMode = .both
    /// 是否把剩余宽高按比例分摊填满。
    private var stretchToFill = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grid Table"
        view.backgroundColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: modeTitle(), style: .plain,
                                                            target: self, action: #selector(toggleMode))

        gridTable.translatesAutoresizingMaskIntoConstraints = false
        gridTable.onSelectCell = { row, col, model in
            print("点击了 (\(row), \(col)) = \(model.text ?? "")")
        }
        // 流式打印 / 缩放 / 布局变化时，表格自适应宽高变化的回调。
        gridTable.onContentSizeChanged = { size in
            print("表格尺寸变化：\(size)")
        }
        // 表格头部工具条（固定，用于复制 / 导出等操作）。
        gridTable.setTableHeaderView(makeToolbar(), height: 44)
        // 表格尾部统计视图（固定）。
        gridTable.setTableFooterView(makeFooter(), height: 36)
        view.addSubview(gridTable)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            gridTable.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            gridTable.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            gridTable.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            // 不固定高度：由 GridTableView 的 intrinsicContentSize 自适应（受 maxTableHeight 限制）。
        ])

        applyData()
    }

    /// 当前模式的中文标题。
    private func modeTitle() -> String {
        switch scrollMode {
        case .both:       return "双向滑动"
        case .horizontal: return "仅左右"
        case .vertical:   return "仅上下"
        }
    }

    private func applyData() {
        // 配置：分割线、边框圆角、最大列宽、表头样式、滑动模式。
        var config = GridTableConfiguration()
        config.scrollMode = scrollMode
        config.maxColumnWidth = 160      // 列最大宽度，超出则换行撑高
        config.minColumnWidth = 60
        config.hasHeaderRow = true
        config.stickyHeader = true       // 表头吸顶
        // 内容不足以填满表格时，按比例分摊剩余宽/高。
        config.stretchColumnsToFill = stretchToFill
        config.stretchRowsToFill = stretchToFill
        // 支持双指捏合缩放整个表格。
        config.zoomEnabled = true
        config.minZoomScale = 0.6
        config.maxZoomScale = 2.5
        // 表格自适应宽高：高度随内容增长，但不超过 420；不足 120 时按 120。
        config.maxTableHeight = 420
        config.minTableHeight = 120

        config.separator = GridSeparatorStyle(width: 1, color: UIColor(white: 0.85, alpha: 1))
        config.border = GridBorderStyle(width: 1, color: UIColor(white: 0.75, alpha: 1), cornerRadius: 10)

        // 表头样式：加粗、居中、蓝底白字。
        var header = GridCellStyle()
        header.font = .boldSystemFont(ofSize: 15)
        header.textColor = .white
        header.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        header.textAlignment = .center
        config.headerStyle = header

        // 普通单元格样式。
        var cell = GridCellStyle()
        cell.font = .systemFont(ofSize: 14)
        cell.textColor = .darkText
        cell.backgroundColor = .white
        config.cellStyle = cell

        // 构造数据（首行为表头）。列数较多以便左右滑动。
        let header0 = ["姓名", "部门", "职级", "城市", "邮箱", "电话", "简介", "分数"]
        let names = ["张三", "李四", "王五", "赵六", "钱七", "孙八", "周九", "吴十",
                     "郑十一", "王十二", "冯十三", "陈十四", "褚十五", "卫十六"]
        let departments = ["研发", "设计", "产品", "测试", "运营", "市场", "财务", "行政"]
        let levels = ["P5", "P6", "P7", "P8", "M1", "M2"]
        let cities = ["北京", "上海", "广州", "深圳", "杭州", "成都", "武汉"]
        let intros = [
            "负责 iOS 客户端开发，熟悉 UIKit 与 SwiftUI，关注性能优化。",
            "视觉设计。",
            "负责产品需求梳理、竞品分析与版本规划，是团队核心成员。",
            "自动化测试与质量保障。",
            "活动策划与用户增长，数据驱动运营。",
            "品牌市场推广。",
        ]

        var rows: [[GridCellModel]] = []

        if stretchToFill {
            // 填充演示：用较少的行列，让内容小于表格，从而观察剩余空间被按比例分摊。
            rows.append(["姓名", "部门", "分数"].map { GridCellModel(text: $0) })
            let small: [[String]] = [
                ["张三", "研发", "92"],
                ["李四", "设计", "88"],
                ["王五", "产品", "95"],
                ["赵六", "测试", "80"],
            ]
            for r in small { rows.append(r.map { GridCellModel(text: $0) }) }
            gridTable.setRows(rows, configuration: config)
            return
        }

        // 生成 40 行数据，行多以便上下滑动。
        rows.append(header0.map { GridCellModel(text: $0) })
        for i in 0..<40 {
            let name = names[i % names.count] + "\(i)"
            let dept = departments[i % departments.count]
            let level = levels[i % levels.count]
            let city = cities[i % cities.count]
            let email = "user\(i)@example.com"
            let phone = "138-0000-\(String(format: "%04d", i))"
            let intro = intros[i % intros.count]
            let score = "\(60 + (i * 7) % 40)"

            var row: [GridCellModel] = [
                GridCellModel(text: name),
                GridCellModel(text: dept),
                GridCellModel(text: level),
                GridCellModel(text: city),
                GridCellModel(text: email),
                GridCellModel(text: phone),
                GridCellModel(text: intro),
            ]
            // 分数列用自定义视图（彩色进度条）演示。
            let ratio = CGFloat((60 + (i * 7) % 40)) / 100.0
            row.append(GridCellModel(customView: {
                let track = UIView()
                track.backgroundColor = UIColor(white: 0.9, alpha: 1)
                track.layer.cornerRadius = 4
                let bar = UIView(frame: CGRect(x: 0, y: 0, width: 40 * ratio, height: 16))
                bar.backgroundColor = UIColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1)
                bar.layer.cornerRadius = 4
                track.addSubview(bar)
                return track
            }, size: CGSize(width: 40, height: 16)))
            rows.append(row)
        }

        gridTable.setRows(rows, configuration: config)

        // 演示「提前计算」：无需等待布局即可算出表格自适应尺寸（头/尾视图各 44 / 36）。
        let preSize = GridTableView.calculateFittingSize(for: rows,
                                                         configuration: config,
                                                         tableHeaderHeight: 44,
                                                         tableFooterHeight: 36)
        print("提前计算表格尺寸：\(preSize)")
        title = String(format: "Grid %.0f×%.0f", preSize.width, preSize.height)
    }

    @objc private func toggleMode() {
        switch scrollMode {
        case .both:       scrollMode = .horizontal
        case .horizontal: scrollMode = .vertical
        case .vertical:   scrollMode = .both
        }
        navigationItem.rightBarButtonItem?.title = modeTitle()
        applyData()
    }

    @objc private func close() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - 头 / 尾自定义视图

    /// 头部工具条：放「复制」「导出」等操作按钮。
    private func makeToolbar() -> UIView {
        let bar = UIView()
        bar.backgroundColor = UIColor(white: 0.97, alpha: 1)

        let titleLabel = UILabel()
        titleLabel.text = "员工表"
        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.textColor = .darkText

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("复制", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 14)
        copyButton.addTarget(self, action: #selector(onCopy), for: .touchUpInside)

        let exportButton = UIButton(type: .system)
        exportButton.setTitle("导出", for: .normal)
        exportButton.titleLabel?.font = .systemFont(ofSize: 14)
        exportButton.addTarget(self, action: #selector(onExport), for: .touchUpInside)

        let fillButton = UIButton(type: .system)
        fillButton.setTitle("填充:关", for: .normal)
        fillButton.titleLabel?.font = .systemFont(ofSize: 14)
        fillButton.addTarget(self, action: #selector(onToggleFill(_:)), for: .touchUpInside)

        let streamButton = UIButton(type: .system)
        streamButton.setTitle("流式", for: .normal)
        streamButton.titleLabel?.font = .systemFont(ofSize: 14)
        streamButton.addTarget(self, action: #selector(onStreamRows), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), streamButton, fillButton, copyButton, exportButton])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
        return bar
    }

    /// 尾部统计视图。
    private func makeFooter() -> UIView {
        let footer = UIView()
        footer.backgroundColor = UIColor(white: 0.97, alpha: 1)
        let label = UILabel()
        label.text = "共 40 条记录"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -12),
        ])
        return footer
    }

    @objc private func onCopy() {
        print("复制表格数据")
    }

    @objc private func onExport() {
        print("导出表格数据")
    }

    @objc private func onToggleFill(_ sender: UIButton) {
        stretchToFill.toggle()
        sender.setTitle(stretchToFill ? "填充:开" : "填充:关", for: .normal)
        applyData()
    }

    /// 逐行流式打印表格。
    @objc private func onStreamRows() {
        gridTable.onRowStreamingFinished = { print("表格流式打印完成 ✅") }
        gridTable.startRowStreaming(rowInterval: 0.12, animated: true)
    }
}
