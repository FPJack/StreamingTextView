//
//  ViewController.swift
//  StreamingTextView_Example
//

import UIKit
import StreamingTextView

class ViewController: UIViewController, @MainActor StreamingTextViewDelegate {

    private var streamingView: StreamingTextView!
    private let statusLabel = UILabel()
    private var streamingWidthConstraint: NSLayoutConstraint?
    private var streamingHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Streaming TextView"
        view.backgroundColor = .white
        setupStreamingView()
        setupControls()
    }

    // MARK: - Setup

    private func setupStreamingView() {
        streamingView = StreamingTextView()
        streamingView.translatesAutoresizingMaskIntoConstraints = false
        streamingView.delegate = self
        streamingView.charactersPerFrame = 1     // 每帧显示 1 个字
        streamingView.frameInterval = 2          // 每 2 个屏幕帧显示一次（60Hz 约 30 字/秒）
        streamingView.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        streamingView.layer.borderWidth = 1.0
        streamingView.layer.cornerRadius = 8.0
        streamingView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        streamingView.textView.font = .systemFont(ofSize: 17.0)

        streamingView.maxTextWidth = UIScreen.main.bounds.width - 32.0
        streamingView.maxTextHeight = 320.0
        streamingView.minTextWidth = 100
        streamingView.minTextHeight = 34
        view.addSubview(streamingView)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 12.0)
        statusLabel.textColor = .gray
        statusLabel.textAlignment = .center
        statusLabel.text = "Ready"
        view.addSubview(statusLabel)

        streamingView.onComplete = { [weak self] in
            self?.statusLabel.text = "Done ✅"
        }

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            streamingView.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            streamingView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            statusLabel.topAnchor.constraint(equalTo: streamingView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
        ])
    }

    private func setupControls() {
        let plainButton = button(title: "Plain Text", action: #selector(onPlainText))
        let richButton = button(title: "Rich Text", action: #selector(onRichText))
        let streamButton = button(title: "Simulate Stream", action: #selector(onSimulateStream))
        let skipButton = button(title: "Skip", action: #selector(onSkip))
        let resetButton = button(title: "Reset", action: #selector(onReset))
        let chatButton = button(title: "AI Chat (Down Markdown)", action: #selector(onOpenChat))
        let sizeButton = button(title: "Pre-calc Size", action: #selector(onOpenSizeCalc))
        let offsetButton = button(title: "Start From Offset", action: #selector(onStartFromOffset))
        let tableButton = button(title: "TableView Streaming", action: #selector(onOpenTableStream))
        let gridButton = button(title: "Grid Table (Compositional)", action: #selector(onOpenGridTable))

        let row1 = UIStackView(arrangedSubviews: [plainButton, richButton, streamButton])
        row1.axis = .horizontal
        row1.distribution = .fillEqually
        row1.spacing = 12

        let row2 = UIStackView(arrangedSubviews: [skipButton, resetButton])
        row2.axis = .horizontal
        row2.distribution = .fillEqually
        row2.spacing = 12

        let stack = UIStackView(arrangedSubviews: [row1, row2, chatButton, sizeButton, offsetButton, tableButton, gridButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
        ])
    }

    private func button(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15.0)
        button.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        button.layer.cornerRadius = 6.0
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    @objc private func onPlainText() {
        statusLabel.text = "Streaming plain text..."
        let text = "这是一个逐帧打印的示例。StreamingTextView 使用 CADisplayLink 按帧逐字显示文本，"
            + "支持纯文本与富文本，也支持模拟网络流式追加。\n\n"
            + "Hello! This text is printed frame by frame, character by character, like a typewriter. 🚀"
        streamingView.startStreamingText(text)
    }

    @objc private func onRichText() {
        statusLabel.text = "Streaming rich text..."
        let rich = NSMutableAttributedString()

        let title: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.blue]
        rich.append(NSAttributedString(string: "富文本标题\n", attributes: title))

        let body: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.darkGray]
        rich.append(NSAttributedString(string: "这段文字是普通正文，", attributes: body))

        let highlight: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.magenta]
        rich.append(NSAttributedString(string: "这里是高亮", attributes: highlight))

        if let image = UIImage(named: "image") {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -4, width: 28, height: 66)
            rich.append(NSAttributedString(attachment: attachment))
        }

        let underline: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 17),
            .foregroundColor: UIColor.green,
            .underlineStyle: NSUnderlineStyle.single.rawValue]
        rich.append(NSAttributedString(string: "，还有下划线斜体。\n", attributes: underline))

        rich.append(NSAttributedString(string: "Rich text streams frame by frame too! ✨", attributes: body))

        streamingView.startStreamingAttributedText(rich)
    }

    @objc private func onSimulateStream() {
        statusLabel.text = "Simulating network stream..."
        streamingView.reset()
        let chunks = ["正在思考", "……\n", "根据你的问题，", "我认为答案是：",
                      "逐帧流式输出", "可以带来", "更好的交互体验。", "\n\n完成。✅"]
        appendChunks(chunks, at: 0)
    }

    private func appendChunks(_ chunks: [String], at index: Int) {
        guard index < chunks.count else { return }
        streamingView.appendText(chunks[index])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.appendChunks(chunks, at: index + 1)
        }
    }

    @objc private func onSkip() {
        streamingView.finishImmediately()
    }

    @objc private func onReset() {
        streamingView.reset()
        statusLabel.text = "Ready"
    }

    @objc private func onOpenChat() {
        let chat = ChatViewController()
        let nav = UINavigationController(rootViewController: chat)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func onOpenSizeCalc() {
        let vc = SizeCalcViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func onOpenTableStream() {
        let vc = TableStreamViewController()
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    @objc private func onOpenGridTable() {
        if #available(iOS 13.0, *) {
            let vc = GridTableViewController()
            if let nav = navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            }
        }
    }

    @objc private func onStartFromOffset() {
        // 前缀直接展示，从 startLength 开始逐帧流式输出。
        let prefix = "【已加载】前面这段文字直接展示，"
        let rest = "从这里开始逐帧打字机式地流式输出剩余内容～ ✨\n适合断点续传 / 恢复上次进度的场景。"
        let text = prefix + rest
        statusLabel.text = "从第 \(prefix.count) 个字符开始流式"
        streamingView.charactersPerFrame = 1
        streamingView.frameInterval = 2
        streamingView.startStreamingText(text, fromLength: (prefix as NSString).length)
    }

    // MARK: - StreamingTextViewDelegate

    func streamingTextView(_ textView: StreamingTextView,
                           didUpdateVisibleLength visibleLength: Int,
                           totalLength: Int) {
        statusLabel.text = "\(visibleLength) / \(totalLength)"
    }

    func streamingTextViewDidFinish(_ textView: StreamingTextView) {
        statusLabel.text = "Done ✅"
    }

    func streamingTextView(_ textView: StreamingTextView, didChangeContentSize contentSize: CGSize) {
        title = String(format: "W %.0f  H %.0f", contentSize.width, contentSize.height)
        streamingWidthConstraint?.constant = contentSize.width
        streamingHeightConstraint?.constant = contentSize.height
    }
}

// MARK: - 预计算宽高演示

class SizeCalcViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pre-calc Size"
        view.backgroundColor = .white
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self, action: #selector(close))

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        let maxWidth = min(UIScreen.main.bounds.width - 32.0, 320.0)

        stack.addArrangedSubview(card(title: "纯文本（短）",
                                      attributed: plainAttributed("Hello 世界 👋"),
                                      maxWidth: maxWidth))
        stack.addArrangedSubview(card(title: "纯文本（换行）",
                                      attributed: plainAttributed("提前计算宽高：先测量得到尺寸，再据此布局，避免闪动。"),
                                      maxWidth: maxWidth))
        stack.addArrangedSubview(card(title: "富文本（混排）",
                                      attributed: richAttributed(),
                                      maxWidth: maxWidth))
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    // MARK: - Sample content

    private func plainAttributed(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 17.0),
            .foregroundColor: UIColor.darkGray])
    }

    private func richAttributed() -> NSAttributedString {
        let rich = NSMutableAttributedString()
        rich.append(NSAttributedString(string: "标题大字\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.blue]))
        rich.append(NSAttributedString(string: "正文加上", attributes: [
            .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.darkGray]))
        rich.append(NSAttributedString(string: "高亮", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.magenta]))
        rich.append(NSAttributedString(string: "，混排富文本也能精确测量。", attributes: [
            .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.darkGray]))
        return rich
    }

    // MARK: - Card

    private func card(title: String, attributed: NSAttributedString, maxWidth: CGFloat) -> UIView {
        let inset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let padding: CGFloat = 5.0

        // 1) 预计算尺寸。
        var size = CGSize.zero
        let sizing = StreamingTextView(textView: nil)
        sizing.maxTextWidth = maxWidth
        sizing.textView.attributedText = attributed
        sizing.textView.textContainerInset = inset
        sizing.textView.textContainer.lineFragmentPadding = padding
        size = sizing.textContentSize

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.numberOfLines = 0
        caption.font = .systemFont(ofSize: 13.0)
        caption.textColor = .gray
        caption.text = String(format: "%@\n预计算尺寸(maxWidth=%.0f): %.0f × %.0f",
                              title, maxWidth, size.width, size.height)
        card.addSubview(caption)

        // 2) 按预计算尺寸约束并展示。
        let display = StreamingTextView()
        display.translatesAutoresizingMaskIntoConstraints = false
        display.textView.textContainerInset = inset
        display.textView.textContainer.lineFragmentPadding = padding
        display.textView.isScrollEnabled = false
        display.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor
        display.layer.borderWidth = 1.0
        display.layer.cornerRadius = 6.0
        display.charactersPerFrame = 1
        display.frameInterval = 2
        display.maxTextWidth = size.width
        display.startStreamingAttributedText(attributed)
        card.addSubview(display)

        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: card.topAnchor),
            caption.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            caption.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            display.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 6),
            display.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            display.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            display.widthAnchor.constraint(equalToConstant: size.width),
            display.heightAnchor.constraint(equalToConstant: size.height),
        ])
        return card
    }
}
