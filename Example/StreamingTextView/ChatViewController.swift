//
//  ChatViewController.swift
//  StreamingTextView_Example
//
//  流式 AI 聊天：用 Down 把 Markdown 解析成富文本，再逐帧揭示；图片异步下载。
//

import UIKit
import StreamingTextView

class ChatViewController: UIViewController, StreamingTextViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var userBubble: UIView!
    private var assistantBubble: UIView!
    private let typingLabel = UILabel()
    private var streamingView: StreamingTextView!

    
    private var isResponding = false
    /// 每次重新生成自增，用于忽略上一轮流式遗留的图片下载回调。
    private var streamGeneration = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AI Chat"
        view.backgroundColor = UIColor(white: 0.96, alpha: 1.0)

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Regenerate", style: .plain,
                                                            target: self, action: #selector(startStreaming))
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isResponding && streamingView.totalLength == 0 {
            startStreaming()
        }
    }

    @objc private func close() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - UI

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // 用户气泡（蓝色，右对齐）。
        userBubble = bubble(color: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0))
        let userLabel = UILabel()
        userLabel.translatesAutoresizingMaskIntoConstraints = false
        userLabel.numberOfLines = 0
        userLabel.textColor = .white
        userLabel.font = .systemFont(ofSize: 17.0)
        userLabel.text = "用 Markdown 介绍一下这个流式文本组件"
        userBubble.addSubview(userLabel)
        contentView.addSubview(userBubble)

        // 助手气泡（白色，左对齐），内含流式富文本。
        assistantBubble = bubble(color: .white)
        assistantBubble.layer.borderWidth = 1.0
        assistantBubble.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor

        // 使用 Down 的 DownLayoutManager 承载文本，才能绘制代码块背景等 block 样式。
        streamingView = StreamingTextView(textView: DownBridge.makeDownTextView())
        streamingView.translatesAutoresizingMaskIntoConstraints = false
        streamingView.delegate = self
        streamingView.charactersPerFrame = 1
        streamingView.frameInterval = 60
        streamingView.textView.isScrollEnabled = false
        streamingView.textView.textContainerInset = .zero
        streamingView.textView.textContainer.lineFragmentPadding = 0
        assistantBubble.addSubview(streamingView)
        contentView.addSubview(assistantBubble)

        typingLabel.translatesAutoresizingMaskIntoConstraints = false
        typingLabel.font = .systemFont(ofSize: 12.0)
        typingLabel.textColor = .gray
        contentView.addSubview(typingLabel)

        let bubbleContentWidth = min(UIScreen.main.bounds.width - 32.0, 300.0) - 24.0
        streamingView.maxTextWidth = bubbleContentWidth

        NSLayoutConstraint.activate([
            userLabel.topAnchor.constraint(equalTo: userBubble.topAnchor, constant: 10),
            userLabel.bottomAnchor.constraint(equalTo: userBubble.bottomAnchor, constant: -10),
            userLabel.leadingAnchor.constraint(equalTo: userBubble.leadingAnchor, constant: 12),
            userLabel.trailingAnchor.constraint(equalTo: userBubble.trailingAnchor, constant: -12),

            streamingView.topAnchor.constraint(equalTo: assistantBubble.topAnchor, constant: 10),
            streamingView.bottomAnchor.constraint(equalTo: assistantBubble.bottomAnchor, constant: -10),
            streamingView.leadingAnchor.constraint(equalTo: assistantBubble.leadingAnchor, constant: 12),
            streamingView.trailingAnchor.constraint(equalTo: assistantBubble.trailingAnchor, constant: -12),
            streamingView.widthAnchor.constraint(equalToConstant: bubbleContentWidth),
        ])


        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            userBubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            userBubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            userBubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),

            typingLabel.topAnchor.constraint(equalTo: userBubble.bottomAnchor, constant: 12),
            typingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            assistantBubble.topAnchor.constraint(equalTo: typingLabel.bottomAnchor, constant: 6),
            assistantBubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            assistantBubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func bubble(color: UIColor) -> UIView {
        let bubble = UIView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.backgroundColor = color
        bubble.layer.cornerRadius = 14.0
        bubble.layer.masksToBounds = true
        return bubble
    }

    // MARK: - Streaming

    /// 读取 bundle 里的 Markdown 资源。
    private func readmeMarkdown() -> String {
        if let path = Bundle.main.path(forResource: "Test", ofType: "md"),
           let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
            return content
        }
        return "# Test.md 未找到"
    }

    @objc private func startStreaming() {
        if isResponding { return }
        isResponding = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        typingLabel.text = "AI 正在输入…"
        streamingView.reset()

        let markdown = readmeMarkdown()
        let maxImageWidth = min(UIScreen.main.bounds.width - 32.0, 300.0) - 24.0

        // 1) 解析 Markdown 并在方法内部直接完成图片下载（下载完成后回调刷新对应区域）。
        streamGeneration += 1
        let generation = streamGeneration
        let options = MarkdownRenderOptions()
        options.fontSize = 16.0
        options.textColor = UIColor(white: 0.15, alpha: 1.0)
        options.maxImageWidth = maxImageWidth
        options.onImageLoaded = { [weak self] attach in
            guard let self = self,
                  generation == self.streamGeneration else {
                return
            }
            self.refreshImage(at: attach.range)
        }
        guard let rich = DownBridge.attributedString(fromMarkdown: markdown, options: options),
              rich.length > 0 else {
            typingLabel.text = "解析失败"
            isResponding = false
            navigationItem.rightBarButtonItem?.isEnabled = true
            return
        }

        // 立即开始流式打印（图片在附件内部异步下载，完成后回调刷新）。
        typingLabel.text = "AI 正在输入…"
        streamingView.charactersPerFrame = 1
        streamingView.frameInterval = 2
        streamingView.startStreamingAttributedText(rich)
    }

    /// 图片下载完成后刷新指定附件所在区域。
    private func refreshImage(at range: NSRange) {
        let tv = streamingView.textView!
        if NSMaxRange(range) > tv.textStorage.length { return }
        tv.layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        tv.layoutManager.invalidateDisplay(forCharacterRange: range)
        scrollToBottom()
    }

    // MARK: - StreamingTextViewDelegate

    func streamingTextView(_ textView: StreamingTextView, didChangeContentSize contentSize: CGSize) {
        scrollToBottom()
    }

    func streamingTextViewDidFinish(_ textView: StreamingTextView) {
        isResponding = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        typingLabel.text = "完成 ✅"
    }

    private func scrollToBottom() {
        let bottom = scrollView.contentSize.height - scrollView.bounds.size.height
        if bottom > 0 {
            scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
        }
    }
}
