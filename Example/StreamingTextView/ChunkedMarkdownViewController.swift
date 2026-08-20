//
//  ChunkedMarkdownViewController.swift
//  ZLStreamingTextView_Example
//
//  模拟「按字符长度分块读取」Test.md，并把分块到达的原始 Markdown 正确、增量地流式渲染
//  到同一个 StreamingTextView。
//
//  为什么不能「切一块渲染一块再 append」：Markdown 是块级、上下文相关的语法，按固定字符
//  长度切割会把标题 / 表格 / 代码块 / 图片 / 链接等语法拦腰截断，每块独立解析必然失败。
//
//  这里采用「方案 A（累积 + 整体重渲染 + 从已揭示处继续）」，并做了三点性能 / 体验优化：
//   1. 累积原始 markdown，每次都对「完整前缀」整体解析 —— 所有 markdown 特性都能正确渲染；
//   2. 只渲染「已到行边界」的前缀，避免把半行 markdown 渲染成破碎文本（收尾时再渲染尾巴）；
//   3. 只在流式空闲（未在逐字揭示 / 表格动画中）时才重渲染，从当前已揭示长度继续，
//      既不打断进行中的动画，也把重渲染次数降到最低。
//
//  分块读取的单次长度由 `chunkLength` 控制（也可通过界面 Stepper 实时调整）。
//

import UIKit
import StreamingTextView

class ChunkedMarkdownViewController: UIViewController {

    // MARK: - 可调参数

    /// 单次读取的字符长度（模拟一次「分块」读取的大小）。可通过界面 Stepper 实时调整。
    var chunkLength: Int = 12 {
        didSet { updateInfoLabel() }
    }

    /// 每次读取之间的时间间隔（秒）。
    var readInterval: TimeInterval = 0.1

    // MARK: - 视图

    private let streamingView = StreamingTextView()
    private let infoLabel = UILabel()
    private let stepper = UIStepper()

    // MARK: - 状态

    /// 源 Markdown（用 NSString 以便按 UTF-16 长度精确切片，正确处理 emoji 等）。
    private var source: NSString = ""
    /// 当前已读取到的偏移。
    private var readOffset: Int = 0
    /// 当前已揭示的富文本字符数（用于信息展示）。
    private var revealedLength: Int = 0
    private var timer: Timer?

    /// 实例化的 DownBridge：负责累积保留原文、整体重新解析、赋值给 streamingView，
    /// 并从上次已显示处继续流式打印。
    private var bridge: DownBridge!

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
        setupBridge()
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
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = .systemFont(ofSize: 13.0)
        infoLabel.textColor = .darkGray
        infoLabel.numberOfLines = 0
        view.addSubview(infoLabel)

        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.minimumValue = 1
        stepper.maximumValue = 500
        stepper.stepValue = 2
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

    private func setupBridge() {
        // Markdown 渲染选项。
        let options = MarkdownRenderOptions()
        options.fontSize = 16.0
        options.textColor = UIColor(white: 0.15, alpha: 1.0)
        options.maxImageWidth = min(UIScreen.main.bounds.width - 32.0, 300.0) - 24.0

        // 实例化 DownBridge，绑定到 streamingView，做增量流式解析。
        bridge = DownBridge(streamingView: streamingView, options: options)
        bridge.onStreamProgress = { [weak self] displayed, _ in
            guard let self = self else { return }
            self.revealedLength = displayed
            self.updateInfoLabel()
            self.scrollToBottom()
        }
    }

    private func updateInfoLabel() {
        infoLabel.text = "单次读取长度：\(chunkLength) 字符"
            + "\n已读取原文：\(readOffset)/\(source.length)　已渲染显示：\(revealedLength) 字"
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

    /// 开始分块读取并流式渲染。
    @objc private func start() {
        timer?.invalidate()
        readOffset = 0
        revealedLength = 0
        bridge.resetStreaming()
        updateInfoLabel()

        timer = Timer.scheduledTimer(withTimeInterval: readInterval, repeats: true) { [weak self] _ in
            // Timer 在主线程 run loop 触发，这里断言主 actor 隔离，
            // 以便调用被 @MainActor 隔离的 readNextChunk()。
            MainActor.assumeIsolated {
                self?.readNextChunk()
            }
        }
    }

    /// 读取下一块原始 markdown 交给 DownBridge（累积保留 → 整体重解析 → 续播由内部调度）。
    private func readNextChunk() {
        guard readOffset < source.length else {
            timer?.invalidate()
            timer = nil
            return
        }

        // 按字符长度截取一块（最后一块可能不足 chunkLength）。
        let length = min(chunkLength, source.length - readOffset)
        let piece = source.substring(with: NSRange(location: readOffset, length: length))
        readOffset += length

        // 交给 DownBridge 累积并增量解析；到达末尾时通知「结束」，让尾巴也被解析。
        bridge.appendMarkdown(piece)
        if readOffset >= source.length {
            bridge.finishStreaming()
            timer?.invalidate()
            timer = nil
        }
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
