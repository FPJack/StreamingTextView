//
//  CodeBlockAttachment.swift
//  StreamingTextView
//
//  一个「块级」流式文本附件：在富文本里为「代码块」预留空间（占位空白，不绘制内容），
//  真正的 `CodeBlockView`（左侧行号 + 右侧代码）作为覆盖视图叠加在占位区域上方。
//  配合 `StreamingTextView`：当文字流式打印到该附件时会暂停文字，先把整块代码展示出来，
//  再继续打印后面的文字。
//
//  头部：
//    - 若检测出语言（`language` 非空），头部左侧展示语言名；
//    - 若未检测出语言，头部左侧展示默认文字（`defaultTitle`，如「代码」）；
//    - 头部右侧始终展示一个「复制」按钮，点击复制整段代码文本。
//
//  用法可参考 `GridTableAttachment` / `GridTableView`。
//

import UIKit

// MARK: - 配置

/// `CodeBlockAttachment` / `CodeBlockView` 的样式与行为配置。
@available(iOS 13.0, *)
public struct CodeBlockConfiguration {

    /// 代码块最大宽度（<=0 表示用宿主可用宽度）。
    public var maxWidth: CGFloat = 0
    /// 代码块最大高度（<=0 表示不限制，超出可垂直滚动）。
    public var maxHeight: CGFloat = 0
    /// 单行代码最大宽度（>0 超出换行）。
    public var maxCellWidth: CGFloat = 0

    /// 是否展示行号。
    public var showsLineNumbers: Bool = true
    /// 代码区是否允许水平滚动（关闭后长行会换行完整展示，行号仍按 `\n` 计数）。
    public var allowsHorizontalScroll: Bool = true
    /// 代码区是否允许垂直滚动。
    public var allowsVerticalScroll: Bool = true

    /// 代码字体。
    public var codeFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13)
    /// 行号字体。
    public var lineNumberFont: UIFont = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13)
    /// 行号文字颜色。
    public var lineNumberColor: UIColor = UIColor(white: 0.55, alpha: 1)
    /// 行号栏背景色。
    public var gutterBackgroundColor: UIColor = UIColor(white: 0.96, alpha: 1)
    /// 代码区背景色。
    public var codeBackgroundColor: UIColor = UIColor(white: 0.98, alpha: 1)

    /// 头部背景色。
    public var headerBackgroundColor: UIColor = UIColor(white: 0.93, alpha: 1)
    /// 头部语言 / 默认文字颜色。
    public var headerTextColor: UIColor = .darkGray
    /// 头部字体。
    public var headerFont: UIFont = .monospacedSystemFont(ofSize: 12, weight: .semibold)
    /// 未检测出语言时头部展示的默认文字。
    public var defaultTitle: String = "代码"
    /// 复制按钮标题。
    public var copyTitle: String = "复制"
    /// 复制成功后的临时标题。
    public var copiedTitle: String = "已复制"
    /// 复制按钮的着色。
    public var copyButtonTintColor: UIColor = .systemBlue
    /// 边框颜色。
    public var borderColor: UIColor = UIColor(white: 0.85, alpha: 1)
    /// 圆角。
    public var cornerRadius: CGFloat = 8

    /// 复制回调（默认已写入系统剪贴板；此回调用于额外处理，如埋点 / 自定义提示）。
    public var onCopy: ((_ code: String) -> Void)?

    public init() {}
}

// MARK: - 附件

@available(iOS 13.0, *)
public class CodeBlockAttachment: NSTextAttachment, StreamingBlockAttachment {

    /// 代码富文本（通常为语法高亮后的结果）。
    public let code: NSAttributedString
    /// 用于复制的纯文本代码。
    public let plainCode: String
    /// 检测出的语言（nil / 空表示未检测出）。
    public let language: String?
    /// 配置。
    public var configuration: CodeBlockConfiguration

    /// 覆盖在占位区域上的真实代码块视图。
    private weak var hostedView: CodeBlockView?
    /// 尺寸变化时通知宿主重新排版的回调（由 `beginStreaming` 注入）。
    private var onLayoutChange: (() -> Void)?

    /// - Parameters:
    ///   - code: 代码富文本（可为语法高亮结果）。
    ///   - language: 检测出的语言；nil / 空表示未检测出，头部展示默认文字。
    ///   - configuration: 样式与行为配置。
    public init(code: NSAttributedString, language: String?, configuration: CodeBlockConfiguration) {
        self.code = code
        self.plainCode = code.string
        self.language = language
        self.configuration = configuration
        super.init(data: nil, ofType: nil)
        // 用空图 + 0 尺寸占位，真实尺寸在 beginStreaming 里按宿主宽度计算后回填。
        self.image = UIImage()
        self.bounds = CGRect(x: 0, y: 0, width: 0, height: 0)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: 构建代码块视图

    private func makeCodeBlockView() -> CodeBlockView {
        let cb = CodeBlockView()
        cb.clipsToBounds = true
        cb.layer.cornerRadius = configuration.cornerRadius
        cb.layer.borderWidth = 1
        cb.layer.borderColor = configuration.borderColor.cgColor
        applyConfiguration(to: cb)
        return cb
    }

    private func applyConfiguration(to cb: CodeBlockView) {
        cb.attributedText = code
        cb.showsLineNumbers = configuration.showsLineNumbers
        cb.allowsHorizontalScroll = configuration.allowsHorizontalScroll
        cb.allowsVerticalScroll = configuration.allowsVerticalScroll
        cb.maxCellWidth = configuration.maxCellWidth
        cb.maxViewHeight = configuration.maxHeight
        cb.codeFont = configuration.codeFont
        cb.lineNumberFont = configuration.lineNumberFont
        cb.lineNumberColor = configuration.lineNumberColor
        cb.gutterBackgroundColor = configuration.gutterBackgroundColor
        cb.codeBackgroundColor = configuration.codeBackgroundColor
        // 头部：语言名（或默认文字）+ 右侧复制按钮。
        cb.headerView = makeHeaderView()
    }

    private func makeHeaderView() -> UIView {
        let title = (language?.isEmpty == false) ? language! : configuration.defaultTitle
        let header = CodeBlockHeaderView(title: title,
                                         config: configuration,
                                         onCopy: { [weak self] in
                                             guard let self = self else { return }
                                             UIPasteboard.general.string = self.plainCode
                                             self.configuration.onCopy?(self.plainCode)
                                         })
        return header
    }

    // MARK: - StreamingBlockAttachment

    public func beginStreaming(in hostView: UIView, frame: CGRect, animated: Bool,
                               onLayoutChange: @escaping () -> Void,
                               completion: @escaping () -> Void) {
        self.onLayoutChange = onLayoutChange

        let cb = hostedView ?? makeCodeBlockView()
        hostedView = cb
        if cb.superview !== hostView { hostView.addSubview(cb) }

        // 以「配置的最大宽度」或「占位区域宽度」作为可用宽度，计算代码块整体尺寸。
        let available = configuration.maxWidth > 0 ? configuration.maxWidth : frame.width
        cb.maxViewWidth = available
        applyConfiguration(to: cb)

        let size = cb.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude))
        self.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        cb.frame = CGRect(origin: frame.origin, size: size)

        // 代码块一次性整体展示（块级附件：暂停文字 → 展示代码 → 继续文字）。
        onLayoutChange()
        completion()
    }

    public func updateFrame(_ frame: CGRect, in hostView: UIView) {
        guard let cb = hostedView else { return }
        if cb.superview !== hostView { hostView.addSubview(cb) }
        // 只更新位置；尺寸取附件当前预留尺寸。
        cb.frame = CGRect(origin: frame.origin, size: bounds.size)
    }

    public func removeStreamingView() {
        hostedView?.removeFromSuperview()
        hostedView = nil
        onLayoutChange = nil
    }

    // MARK: - 语言检测

    /// 由 Markdown 围栏代码块的 info 字符串（```之后的内容，如 `swift` / `js`）推断语言。
    /// - 返回归一化后的语言名；识别不到则返回 nil（调用方据此走「默认展示代码文字」分支）。
    public static func detectLanguage(fromInfoString info: String?) -> String? {
        guard let raw = info?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).first?
            .lowercased(), !raw.isEmpty else { return nil }

        // 常见别名归一化。
        let aliases: [String: String] = [
            "js": "javascript", "ts": "typescript", "objc": "objective-c",
            "objective_c": "objective-c", "py": "python", "rb": "ruby",
            "sh": "shell", "bash": "shell", "zsh": "shell", "yml": "yaml",
            "md": "markdown", "kt": "kotlin", "cpp": "c++", "cs": "c#",
            "h": "c", "hpp": "c++"
        ]
        return aliases[raw] ?? raw
    }
}

// MARK: - 头部视图（语言标题 + 复制按钮）

@available(iOS 13.0, *)
private final class CodeBlockHeaderView: UIView {

    private let titleLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let onCopy: () -> Void
    private let copyTitle: String
    private let copiedTitle: String
    private var resetWorkItem: DispatchWorkItem?

    init(title: String, config: CodeBlockConfiguration, onCopy: @escaping () -> Void) {
        self.onCopy = onCopy
        self.copyTitle = config.copyTitle
        self.copiedTitle = config.copiedTitle
        super.init(frame: .zero)

        backgroundColor = config.headerBackgroundColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = config.headerFont
        titleLabel.textColor = config.headerTextColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(titleLabel)

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.setTitle(config.copyTitle, for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        copyButton.tintColor = config.copyButtonTintColor
        copyButton.setTitleColor(config.copyButtonTintColor, for: .normal)
        if let doc = UIImage(systemName: "doc.on.doc") {
            copyButton.setImage(doc, for: .normal)
            copyButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 0)
        }
        copyButton.addTarget(self, action: #selector(onTapCopy), for: .touchUpInside)
        copyButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(copyButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 34),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 6),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),

            copyButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func onTapCopy() {
        onCopy()
        // 临时反馈「已复制」。
        copyButton.setTitle(copiedTitle, for: .normal)
        resetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.copyButton.setTitle(self.copyTitle, for: .normal)
        }
        resetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
