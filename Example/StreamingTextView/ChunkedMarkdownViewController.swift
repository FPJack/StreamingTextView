//
//  ChunkedMarkdownViewController.swift
//  ZLStreamingTextView_Example
//
//  模拟「按字符长度分块读取」Test.md：每次从源 Markdown 中读取 `chunkLength` 个字符，
//  把这一小段渲染成富文本，再流式拼接（append）到同一个 StreamingTextView。
//  单次读取的长度由变量 `chunkLength` 控制（也可通过界面上的 Stepper 实时调整）。
//

import UIKit
import StreamingTextView

class ChunkedMarkdownViewController: UIViewController {

    // MARK: - 可调参数

    /// 单次读取的字符长度（模拟一次「分块」读取的大小）。可通过界面 Stepper 实时调整。
    var chunkLength: Int = 30 {
        didSet { updateInfoLabel() }
    }

    /// 每次读取之间的时间间隔（秒）。
    var readInterval: TimeInterval = 0.2

    // MARK: - 视图

    private let streamingView = StreamingTextView()
    private let infoLabel = UILabel()
    private let stepper = UIStepper()

    // MARK: - 状态

    /// 源 Markdown（用 NSString 以便按 UTF-16 长度精确切片，正确处理 emoji 等）。
    private var source: NSString = ""
    /// 当前已读取到的偏移。
    private var readOffset: Int = 0
    private var timer: Timer?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "分块读取 Markdown"
        view.backgroundColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "开始", style: .plain,
                                                            target: self, action: #selector(start))

        source = readmeMarkdown() as NSString
        setupUI()
        updateInfoLabel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 离开页面时停止定时器，避免 self 释放后定时器仍在触发。
        timer?.invalidate()
        timer = nil
    }

    // MARK: - UI

    private func setupUI() {
        // 控制条：chunkLength 调节 + 说明。
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = .systemFont(ofSize: 13.0)
        infoLabel.textColor = .darkGray
        infoLabel.numberOfLines = 0
        view.addSubview(infoLabel)

        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.minimumValue = 1
        stepper.maximumValue = 500
        stepper.stepValue = 5
        stepper.value = Double(chunkLength)
        stepper.addTarget(self, action: #selector(onStepperChanged), for: .valueChanged)
        view.addSubview(stepper)

        // 流式富文本展示区（内部可滚动，承载超长内容）。
        streamingView.translatesAutoresizingMaskIntoConstraints = false
        streamingView.textView.isScrollEnabled = true
        streamingView.textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        streamingView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        streamingView.layer.cornerRadius = 10.0
        streamingView.layer.borderWidth = 1.0
        streamingView.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        streamingView.charactersPerFrame = 1
        streamingView.frameInterval = 1
        streamingView.maxTextWidth = UIScreen.main.bounds.width - 32.0
        // 追加过程中自动滚动到底部，跟随最新内容。
        streamingView.onContentSizeChange = { [weak self] _ in
            self?.scrollToBottom()
        }
        view.addSubview(streamingView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            infoLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -12),

            stepper.centerYAnchor.constraint(equalTo: infoLabel.centerYAnchor),
            stepper.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),

            streamingView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 12),
            streamingView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            streamingView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            streamingView.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
        ])
    }

    private func updateInfoLabel() {
        infoLabel.text = "单次读取长度：\(chunkLength) 字符\n已读取：\(readOffset)/\(source.length)"
    }

    // MARK: - 数据

    /// 读取 bundle 里的 Markdown 资源。
    private func readmeMarkdown() -> String {
        if let path = Bundle.main.path(forResource: "Test", ofType: "md"),
           let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
            return content
        }
        return "# Test.md 未找到"
    }

    // MARK: - 控制

    @objc private func onStepperChanged() {
        chunkLength = Int(stepper.value)
    }

    /// 开始分块读取并流式拼接。
    @objc private func start() {
        timer?.invalidate()
        readOffset = 0
        streamingView.reset()
        updateInfoLabel()

        timer = Timer.scheduledTimer(withTimeInterval: readInterval, repeats: true) { [weak self] _ in
            self?.readNextChunk()
        }
    }

    /// 读取下一块：截取 `chunkLength` 个字符 → 渲染富文本 → 追加到流式视图。
    private func readNextChunk() {
        guard readOffset < source.length else {
            timer?.invalidate()
            timer = nil
            return
        }

        // 1) 按字符长度截取一块（最后一块可能不足 chunkLength）。
        let length = min(chunkLength, source.length - readOffset)
        let piece = source.substring(with: NSRange(location: readOffset, length: length))
        readOffset += length

        // 2) 把这一小段 Markdown 渲染成富文本。
        let options = MarkdownRenderOptions()
        options.fontSize = 16.0
        options.textColor = UIColor(white: 0.15, alpha: 1.0)
        options.maxImageWidth = min(UIScreen.main.bounds.width - 32.0, 300.0) - 24.0
        let attributed = DownBridge.attributedString(fromMarkdown: piece, options: options)
            ?? NSAttributedString(string: piece, attributes: [.font: UIFont.systemFont(ofSize: 16.0)])

        // 3) 流式拼接到同一个 StreamingTextView。
        streamingView.appendAttributedText(attributed)

        updateInfoLabel()
    }

    private func scrollToBottom() {
        guard let tv = streamingView.textView, tv.isScrollEnabled,
              tv.contentSize.height > tv.bounds.height else { return }
        let bottom = tv.contentSize.height - tv.bounds.height + tv.adjustedContentInset.bottom
        tv.setContentOffset(CGPoint(x: 0, y: max(bottom, 0)), animated: false)
    }

    @objc private func close() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
