//
//  CodeBlockDemoViewController.swift
//  StreamingTextView_Example
//
//  演示 CodeBlockView：左侧行号 + 右侧代码，双向联动、可控水平/垂直滚动、
//  自定义头尾视图、最大宽高限制、自适应 intrinsicContentSize、提前计算尺寸。
//

import UIKit
import StreamingTextView

@available(iOS 13.0, *)
final class CodeBlockDemoViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let container = UIView()
    private let codeBlock = CodeBlockView()
    private let sizeLabel = UILabel()

    // 开关
    private let lineNumberSwitch = UISwitch()
    private let hScrollSwitch = UISwitch()
    private let vScrollSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CodeBlockView"
        view.backgroundColor = .white
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                           target: self, action: #selector(close))
        setupUI()
        configureCodeBlock()
        updateSizeLabel()
    }

    // MARK: - UI

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)

        // 三个开关行
        let lineRow = switchRow("显示行号", lineNumberSwitch, on: true, action: #selector(onToggle))
        let hRow = switchRow("代码区水平滚动", hScrollSwitch, on: true, action: #selector(onToggle))
        let vRow = switchRow("代码区垂直滚动", vScrollSwitch, on: true, action: #selector(onToggle))

        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = .systemFont(ofSize: 12)
        sizeLabel.textColor = .darkGray
        sizeLabel.numberOfLines = 0

        codeBlock.translatesAutoresizingMaskIntoConstraints = false
        codeBlock.setContentHuggingPriority(.required, for: .vertical)
        codeBlock.layer.borderColor = UIColor(white: 0.85, alpha: 1).cgColor
        codeBlock.layer.borderWidth = 1
        codeBlock.layer.cornerRadius = 8
        codeBlock.clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [lineRow, hRow, vRow, sizeLabel, codeBlock])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
    }

    private func switchRow(_ title: String, _ sw: UISwitch, on: Bool, action: Selector) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14)
        sw.isOn = on
        sw.addTarget(self, action: action, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [label, sw])
        row.axis = .horizontal
        row.spacing = 8
        return row
    }

    // MARK: - CodeBlock 配置

    private func configureCodeBlock() {
        codeBlock.attributedText = Self.sampleCode()
        codeBlock.showsLineNumbers = lineNumberSwitch.isOn
        codeBlock.allowsHorizontalScroll = hScrollSwitch.isOn
        codeBlock.allowsVerticalScroll = vScrollSwitch.isOn
        codeBlock.maxViewWidth = UIScreen.main.bounds.width - 32
        codeBlock.maxViewHeight = 260
        codeBlock.maxCellWidth = 0            // 0 = 不换行，长行可横向滚动
        codeBlock.headerView = makeHeader()
        codeBlock.footerView = makeFooter()
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.backgroundColor = UIColor(white: 0.93, alpha: 1)
        let dot: (UIColor) -> UIView = { color in
            let v = UIView(); v.backgroundColor = color; v.layer.cornerRadius = 6
            v.translatesAutoresizingMaskIntoConstraints = false
            v.widthAnchor.constraint(equalToConstant: 12).isActive = true
            v.heightAnchor.constraint(equalToConstant: 12).isActive = true
            return v
        }
        let lang = UILabel()
        lang.text = "swift"
        lang.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        lang.textColor = .darkGray
        let dots = UIStackView(arrangedSubviews: [dot(.systemRed), dot(.systemYellow), dot(.systemGreen)])
        dots.axis = .horizontal; dots.spacing = 6
        let row = UIStackView(arrangedSubviews: [dots, lang, UIView()])
        row.axis = .horizontal; row.spacing = 10; row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        row.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: header.topAnchor),
            row.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: header.bottomAnchor),
        ])
        return header
    }

    private func makeFooter() -> UIView {
        let footer = UIView()
        footer.backgroundColor = UIColor(white: 0.93, alpha: 1)
        let label = UILabel()
        label.text = "共 \(Self.sampleCode().string.components(separatedBy: "\n").count) 行 · 点击右上角关闭"
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footer.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: footer.trailingAnchor, constant: -12),
        ])
        return footer
    }

    // MARK: - Actions

    @objc private func onToggle() {
        codeBlock.showsLineNumbers = lineNumberSwitch.isOn
        codeBlock.allowsHorizontalScroll = hScrollSwitch.isOn
        codeBlock.allowsVerticalScroll = vScrollSwitch.isOn
        updateSizeLabel()
    }

    private func updateSizeLabel() {
        // 演示「提前计算尺寸」：不依赖已创建的视图即可算出建议尺寸。
        let precalc = CodeBlockView.calculateSize(
            attributedText: Self.sampleCode(),
            showsLineNumbers: lineNumberSwitch.isOn,
            maxViewWidth: UIScreen.main.bounds.width - 32,
            maxViewHeight: 260,
            maxCellWidth: 0,
            headerHeight: 32,
            footerHeight: 24)
        sizeLabel.text = "预计算尺寸(calculateSize)：\(Int(precalc.width)) × \(Int(precalc.height))"
    }

    @objc private func close() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - 示例代码富文本（简单着色）

    private static func sampleCode() -> NSAttributedString {
        let lines: [String] = [
            "import UIKit",
            "",
            "// 一个很长的注释行，用来演示代码区在关闭换行时可以水平滚动 —— scroll horizontally when wrapping is off",
            "struct MarkdownToHTML: DownHTMLRenderable {",
            "    public var markdownString: String",
            "",
            "    func render() -> String {",
            "        return markdownString.uppercased()",
            "    }",
            "}",
            "",
            "let a = 1",
            "let b = 2",
            "print(a + b)",
        ]
        let mono = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13)
        let result = NSMutableAttributedString()
        for (i, line) in lines.enumerated() {
            let attr = NSMutableAttributedString(string: line, attributes: [
                .font: mono,
                .foregroundColor: UIColor(white: 0.15, alpha: 1)
            ])
            colorize(attr)
            result.append(attr)
            if i != lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: mono]))
            }
        }
        return result
    }

    /// 极简「语法着色」：关键字蓝、注释绿、字符串橙。
    private static func colorize(_ attr: NSMutableAttributedString) {
        let text = attr.string
        let ns = text as NSString

        // 注释：以 // 开头到行尾。
        if let r = text.range(of: "//.*", options: .regularExpression) {
            attr.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: NSRange(r, in: text))
            return
        }
        let keywords = ["import", "struct", "public", "var", "let", "func", "return"]
        for kw in keywords {
            var searchRange = NSRange(location: 0, length: ns.length)
            while true {
                let found = ns.range(of: kw, options: [], range: searchRange)
                if found.location == NSNotFound { break }
                // 词边界校验（前后都不是字母）。
                let beforeIsLetter: Bool = {
                    guard found.location > 0 else { return false }
                    let c = ns.substring(with: NSRange(location: found.location - 1, length: 1))
                    return c.rangeOfCharacter(from: .letters) != nil
                }()
                let afterLoc = found.location + found.length
                let afterIsLetter: Bool = {
                    guard afterLoc < ns.length else { return false }
                    let c = ns.substring(with: NSRange(location: afterLoc, length: 1))
                    return c.rangeOfCharacter(from: .letters) != nil
                }()
                if !beforeIsLetter && !afterIsLetter {
                    attr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: found)
                }
                searchRange = NSRange(location: afterLoc, length: ns.length - afterLoc)
            }
        }
        // 字符串字面量。
        if let r = text.range(of: "\"[^\"]*\"", options: .regularExpression) {
            attr.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: NSRange(r, in: text))
        }
    }
}
