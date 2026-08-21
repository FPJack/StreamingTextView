//
//  StreamingTextView.swift
//  StreamingTextView
//
//  一个封装了 UITextView 的视图，可逐帧打印文字（打字机 / 流式效果）。
//  同时支持纯文本（String）和富文本（NSAttributedString）。
//  使用 @objc / @objcMembers 标注以支持 Objective-C 调用。
//

import UIKit

/// CADisplayLink 会强引用它的 target，若直接用 self 作为 target 会造成引用环、
/// 甚至在视图/复用 cell 被销毁后回调到半析构对象导致崩溃。用弱引用代理打破环。
private final class DisplayLinkProxy: NSObject {
    weak var target: StreamingTextView?
    init(target: StreamingTextView) { self.target = target }
    @objc func onDisplayLink(_ link: CADisplayLink) {
        target?.zl_handleDisplayLink(link)
    }
}

/// 「块级」流式附件协议：文本流式打印到该附件时会**暂停文字**，
/// 交由附件自己完成一段动画（例如表格逐行打印），动画结束后再**继续打印后面的文字**。
///
/// 典型实现：`GridTableAttachment` —— 附件本身在文本里预留出表格的完整尺寸（占位空白），
/// 真正的表格视图作为覆盖层添加到 textView 上，位置与占位区域对齐。
public protocol StreamingBlockAttachment: AnyObject {
    /// 附件被揭示时调用：在 `hostView` 上按 `frame` 放置自己的视图并开始动画。
    /// - Parameters:
    ///   - hostView: 承载覆盖视图的父视图（通常是 textView 本身）。
    ///   - frame: 附件在 `hostView` 坐标系里的矩形（= 附件当前预留尺寸）。
    ///   - animated: 是否播放动画（`false` 表示一次性直接显示，如关闭流式 / 立即完成时）。
    ///   - onLayoutChange: 当附件自身尺寸变化（如表格逐行增高）时调用，
    ///     宿主据此重新排版文本，使 textView 高度与附件同步增长。
    ///   - completion: 动画结束回调；文字流式会在此之后继续。
    func beginStreaming(in hostView: UIView, frame: CGRect, animated: Bool,
                        onLayoutChange: @escaping () -> Void,
                        completion: @escaping () -> Void)

    /// 布局变化时重新定位覆盖视图（尺寸取附件当前预留尺寸）。
    func updateFrame(_ frame: CGRect, in hostView: UIView)

    /// 从视图层级移除覆盖视图（reset / 复用时调用）。
    func removeStreamingView()
}

/// 进度 / 完成 / 尺寸变化回调代理。
@objc
public protocol StreamingTextViewDelegate: NSObjectProtocol {
    /// 每当可见文字长度变化（即每帧）时回调。
    @objc optional func streamingTextView(_ textView: StreamingTextView,
                                          didUpdateVisibleLength visibleLength: Int,
                                          totalLength: Int)
    /// 当所有缓冲文字都显示完毕、流式停止时回调一次。
    @objc optional func streamingTextViewDidFinish(_ textView: StreamingTextView)
    /// 当渲染文字的内容尺寸（宽和/或高）发生变化时回调。
    @objc optional func streamingTextView(_ textView: StreamingTextView,
                                          didChangeContentSize contentSize: CGSize)
}

@objcMembers
public class StreamingTextView: UIView {

    // MARK: - 公开属性

    /// 底层的文本视图。你可以直接配置它（字体、颜色、内边距……）。
    public private(set) var textView: UITextView!

    /// 进度 / 完成回调的代理。
    public weak var delegate: StreamingTextViewDelegate?

    /// 每一帧（display link）显示的字符数。默认为 1。
    public var charactersPerFrame: Int = 1

    /// 每隔 N 个屏幕帧显示一帧文字。1 = 每帧都显示（最快）。默认为 1。
    public var frameInterval: Int = 1

    /// 纯文本流式时若未指定属性所使用的默认文字属性。
    public var defaultTextAttributes: [NSAttributedString.Key: Any]? = [
        .font: UIFont.systemFont(ofSize: 16.0),
        .foregroundColor: UIColor.black
    ]

    /// 是否启用逐帧打字机效果。设为 `false` 时，任何 start.../append... 调用都会立即完整显示。默认 `true`。
    public var isStreamingEnabled: Bool = true {
        didSet {
            guard oldValue != isStreamingEnabled else { return }
            // 若在文字仍未显示完时关闭流式，则立即显示剩余内容。
            if !isStreamingEnabled && visibleLength < bufferedText.length {
                finishImmediately()
            }
        }
    }

    /// 排版 / 换行所使用的最大宽度。`0` 表示使用视图当前宽度。默认 `0`。
    public var maxTextWidth: CGFloat = 0 {
        didSet { if oldValue != maxTextWidth { notifyContentSizeChangeIfNeeded() } }
    }

    /// 最大高度。上报的内容尺寸高度会被限制到此值（超出部分由文本视图滚动显示）。`0` 表示不限制。默认 `0`。
    public var maxTextHeight: CGFloat = 0 {
        didSet { if oldValue != maxTextHeight { notifyContentSizeChangeIfNeeded() } }
    }

    /// 最小宽度。上报的内容尺寸宽度不会小于此值。`0` 表示不限制。默认 `0`。
    public var minTextWidth: CGFloat = 0 {
        didSet { if oldValue != minTextWidth { notifyContentSizeChangeIfNeeded() } }
    }

    /// 最小高度。上报的内容尺寸高度不会小于此值。`0` 表示不限制。默认 `0`。
    public var minTextHeight: CGFloat = 0 {
        didSet { if oldValue != minTextHeight { notifyContentSizeChangeIfNeeded() } }
    }

    /// 打印过程中（及之后）底层文本视图是否可以滚动。默认 `true`。
    public var isScrollEnabled: Bool {
        get { textView.isScrollEnabled }
        set { textView.isScrollEnabled = newValue }
    }

    /// 正在逐帧显示文字时为 true。
    public private(set) var isStreaming: Bool = false

    /// 当前已显示的字符数。
    public private(set) var visibleLength: Int = 0

    /// 缓冲区中的总字符数（已显示 + 待显示）。
    public var totalLength: Int { bufferedText.length }

    /// 进度回调（代理的替代方案）。
    public var onProgress: ((_ visibleLength: Int, _ totalLength: Int) -> Void)?

    /// 完成回调（代理的替代方案）。
    public var onComplete: (() -> Void)?

    /// 流式过程中，当渲染文字的内容尺寸（宽 / 高）变化时回调。
    public var onContentSizeChange: ((_ contentSize: CGSize) -> Void)?

    // MARK: - 私有状态

    /// 完整的缓冲内容（最终要显示的全部文字）。
    private var bufferedText = NSMutableAttributedString()
    private var displayLink: CADisplayLink?
    /// 强持有弱引用代理，保证它在流式期间不被释放（否则 displayLink 目标为空，不会走帧回调）。
    private var displayLinkProxy: DisplayLinkProxy?
    private var frameCounter: Int = 0
    /// 上一次上报的内容尺寸，用于检测宽 / 高变化。
    private var lastContentSize: CGSize = .zero

    /// 已开始的块级附件（如表格），记录其字符位置与实例，用于重新定位覆盖视图 / 去重。
    private var startedBlocks: [(loc: Int, att: StreamingBlockAttachment)] = []

    // MARK: - 初始化

    /// 使用指定 frame 与外部传入的自定义 UITextView 进行初始化。
    /// 传入的 textView 会被强制设为不可编辑，其余配置保持不变。
    public init(frame: CGRect, textView: UITextView?) {
        super.init(frame: frame)
        commonInit(with: textView)
    }

    /// 使用外部传入的自定义 UITextView 进行初始化。
    public convenience init(textView: UITextView?) {
        self.init(frame: .zero, textView: textView)
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit(with: nil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit(with: nil)
    }

    private func commonInit(with textView: UITextView?) {
        if let tv = textView {
            // 采用外部传入的自定义文本视图，尽量保留其原有配置。
            tv.frame = bounds
            tv.isEditable = false // 流式展示视图不可编辑
            self.textView = tv
        } else {
            let tv = UITextView(frame: bounds)
            tv.isEditable = false
            tv.isScrollEnabled = true
            tv.backgroundColor = .clear
            tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            self.textView = tv
        }
        self.textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(self.textView)
    }

    deinit {
        stopDisplayLink()
    }

    // MARK: - 纯文本

    /// 重置缓冲区，并使用 `defaultTextAttributes` 开始流式显示给定的纯文本。
    public func startStreamingText(_ text: String) {
        startStreamingText(text, attributes: defaultTextAttributes)
    }

    /// 重置缓冲区，并使用指定属性开始流式显示给定的纯文本。
    public func startStreamingText(_ text: String, attributes: [NSAttributedString.Key: Any]?) {
        let attrs = attributes ?? defaultTextAttributes ?? [:]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        startStreamingAttributedText(attributed)
    }

    // MARK: - 富文本

    /// 重置缓冲区，并开始流式显示给定的富文本。
    public func startStreamingAttributedText(_ attributedText: NSAttributedString) {
        resetBuffer()
        if attributedText.length > 0 {
            bufferedText.append(attributedText)
        }
        startDisplayLinkIfNeeded()
    }

    // MARK: - 从指定偏移开始

    /// 将缓冲区重置为给定纯文本，立即显示前 `startLength` 个字符，然后从该处开始流式显示剩余内容。
    public func startStreamingText(_ text: String, fromLength startLength: Int) {
        let attributed = NSAttributedString(string: text, attributes: defaultTextAttributes ?? [:])
        startStreamingAttributedText(attributed, fromLength: startLength)
    }

    /// 将缓冲区重置为给定富文本，立即显示前 `startLength` 个字符，然后从该处开始流式显示剩余内容。
    public func startStreamingAttributedText(_ attributedText: NSAttributedString, fromLength startLength: Int) {
        resetBuffer()
        if attributedText.length > 0 {
            bufferedText.append(attributedText)
        }
        // 立即显示前缀，然后从该处开始流式显示剩余内容。
        visibleLength = min(startLength, bufferedText.length)
        applyVisibleText()
        // 前缀里若已包含块级附件，立即（非动画）显示它们。
        startVisibleUnstartedBlocks(animated: false)
        startDisplayLinkIfNeeded()
    }

    // MARK: - 增量追加（例如网络流式分块）

    /// 向缓冲区追加纯文本；流式会自动继续 / 开始。
    public func appendText(_ text: String) {
        guard !text.isEmpty else { return }
        let attributed = NSAttributedString(string: text, attributes: defaultTextAttributes ?? [:])
        appendAttributedText(attributed)
    }

    /// 向缓冲区追加富文本；流式会自动继续 / 开始。
    public func appendAttributedText(_ attributedText: NSAttributedString) {
        guard attributedText.length > 0 else { return }
        bufferedText.append(attributedText)
        startDisplayLinkIfNeeded()
    }

    // MARK: - 控制

    /// 暂停显示（保留缓冲区）。
    public func pause() {
        isStreaming = false
        stopDisplayLink()
    }

    /// 暂停后继续显示。
    public func resume() {
        startDisplayLinkIfNeeded()
    }

    /// 立即显示全部缓冲文字并停止。
    public func finishImmediately() {
        visibleLength = bufferedText.length
        applyVisibleText()
        // 立即（非动画）启动尚未开始的块级附件。
        startVisibleUnstartedBlocks(animated: false)
        stopStreaming()
    }

    /// 清空所有内容（缓冲区 + 已显示文字）并停止。
    public func reset() {
        stopDisplayLink()
        clearBlocks()
        resetBuffer()
        visibleLength = 0
        textView.attributedText = NSAttributedString()
        isStreaming = false
        notifyContentSizeChangeIfNeeded()
    }

    private func resetBuffer() {
        stopDisplayLink()
        clearBlocks()
        bufferedText = NSMutableAttributedString()
        visibleLength = 0
        textView.attributedText = NSAttributedString()
        notifyContentSizeChangeIfNeeded()
    }

    // MARK: - Display Link 驱动

    private func startDisplayLinkIfNeeded() {
        // 没有可显示的剩余内容。
        if visibleLength >= bufferedText.length { return }
        // 流式已关闭：一次性显示全部并立即完成。
        if !isStreamingEnabled {
            isStreaming = true // 保证完成回调依然会触发
            finishImmediately()
            return
        }
        isStreaming = true
        if displayLink != nil { return }
        frameCounter = 0
        // 用弱引用代理，避免 CADisplayLink 强引用 self 造成的引用环 / 崩溃。
        // 注意：代理必须被 self 强持有，否则会立即释放，导致 displayLink 不回调、无法流式。
        let proxy = DisplayLinkProxy(target: self)
        displayLinkProxy = proxy
        let link = CADisplayLink(target: proxy,
                                 selector: #selector(DisplayLinkProxy.onDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    /// 供弱引用代理转发调用（不要直接从外部调用）。
    @objc fileprivate func zl_handleDisplayLink(_ link: CADisplayLink) {
        handleDisplayLink(link)
    }

    private func handleDisplayLink(_ link: CADisplayLink) {
        let interval = max(frameInterval, 1)
        frameCounter += 1
        if frameCounter < interval { return }
        frameCounter = 0

        let step = max(charactersPerFrame, 1)
        var newVisible = min(visibleLength + step, bufferedText.length)
        if newVisible == visibleLength {
            // 已追平缓冲区。停止，等待更多文字到达。
            stopStreaming()
            return
        }

        // 若本次将揭示的范围内存在「块级附件」（如表格），只揭示到该附件（含）为止，
        // 随后暂停文字流式，等待其自身动画（逐行打印）完成后再继续。
        var pendingBlock: (loc: Int, att: StreamingBlockAttachment)? = nil
        if let hit = firstUnstartedBlock(in: NSRange(location: visibleLength, length: newVisible - visibleLength)) {
            newVisible = hit.loc + 1
            pendingBlock = hit
        }

        visibleLength = newVisible
        applyVisibleText()

        delegate?.streamingTextView?(self, didUpdateVisibleLength: visibleLength, totalLength: bufferedText.length)
        onProgress?(visibleLength, bufferedText.length)

        if let block = pendingBlock {
            // 暂停文字流式，交给块级附件播放动画，完成后再继续。
            startBlock(block, pausingStream: true)
            return
        }

        if visibleLength >= bufferedText.length {
            stopStreaming()
        }
    }

    private func stopStreaming() {
        stopDisplayLink()
        if isStreaming {
            isStreaming = false
            delegate?.streamingTextViewDidFinish?(self)
            onComplete?()
        }
    }

    // MARK: - 渲染

    private func applyVisibleText() {
        let length = min(visibleLength, bufferedText.length)
        let slice = bufferedText.attributedSubstring(from: NSRange(location: 0, length: length))
        textView.attributedText = slice
        repositionBlocks()
        notifyContentSizeChangeIfNeeded()
    }

    // MARK: - 内容尺寸跟踪

    public override func layoutSubviews() {
        super.layoutSubviews()
        // 视图缩放时宽度可能变化，进而影响换行后的文字高度。
        notifyContentSizeChangeIfNeeded()
        // 布局变化后重新定位块级附件（如表格）的覆盖视图。
        repositionBlocks()
    }

    // MARK: - 块级附件（如表格）流式协调

    /// 在指定范围内查找第一个「尚未开始」的块级附件。
    private func firstUnstartedBlock(in range: NSRange) -> (loc: Int, att: StreamingBlockAttachment)? {
        guard range.length > 0, NSMaxRange(range) <= bufferedText.length else { return nil }
        var found: (Int, StreamingBlockAttachment)?
        bufferedText.enumerateAttribute(.attachment, in: range, options: []) { value, r, stop in
            if let att = value as? StreamingBlockAttachment, !isBlockStarted(att) {
                found = (r.location, att)
                stop.pointee = true
            }
        }
        guard let f = found else { return nil }
        return (f.0, f.1)
    }

    private func isBlockStarted(_ att: StreamingBlockAttachment) -> Bool {
        startedBlocks.contains { $0.att === att }
    }

    /// 开始一个块级附件的动画。
    /// - Parameter pausingStream: 是否暂停文字流式，等其完成后再继续（`true` 用于动画流式）。
    private func startBlock(_ block: (loc: Int, att: StreamingBlockAttachment), pausingStream: Bool) {
        startedBlocks.append(block)
        let rect = rectForAttachment(at: block.loc)
        let onLayoutChange: () -> Void = { [weak self] in
            self?.invalidateBlockLayout(at: block.loc)
        }
        if pausingStream && isStreamingEnabled {
            stopDisplayLink()   // 暂停文字（isStreaming 仍为 true）
            block.att.beginStreaming(in: textView, frame: rect, animated: true,
                                     onLayoutChange: onLayoutChange) { [weak self] in
                self?.resumeAfterBlock()
            }
        } else {
            block.att.beginStreaming(in: textView, frame: rect, animated: false,
                                     onLayoutChange: onLayoutChange) {}
        }
    }

    /// 块级附件自身尺寸变化后，重新排版其占位区域，使 textView 高度与之同步增长。
    private func invalidateBlockLayout(at loc: Int) {
        guard loc < textView.textStorage.length else { return }
        let range = NSRange(location: loc, length: 1)
        let lm = textView.layoutManager
        lm.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        lm.ensureLayout(for: textView.textContainer)
        repositionBlocks()
        notifyContentSizeChangeIfNeeded()
    }

    /// 块级附件动画完成后，继续文字流式（或收尾）。
    private func resumeAfterBlock() {
        if visibleLength >= bufferedText.length {
            stopStreaming()
        } else {
            startDisplayLinkIfNeeded()
        }
    }

    /// 立即（非动画）启动当前已可见但尚未开始的块级附件。
    private func startVisibleUnstartedBlocks(animated: Bool) {
        let range = NSRange(location: 0, length: min(visibleLength, bufferedText.length))
        guard range.length > 0 else { return }
        var blocks: [(Int, StreamingBlockAttachment)] = []
        bufferedText.enumerateAttribute(.attachment, in: range, options: []) { value, r, _ in
            if let att = value as? StreamingBlockAttachment, !isBlockStarted(att) {
                blocks.append((r.location, att))
            }
        }
        for b in blocks { startBlock((loc: b.0, att: b.1), pausingStream: animated) }
    }

    /// 重新定位所有已开始块级附件的覆盖视图。
    private func repositionBlocks() {
        guard !startedBlocks.isEmpty else { return }
        for block in startedBlocks where block.loc < bufferedText.length {
            let rect = rectForAttachment(at: block.loc)
            block.att.updateFrame(rect, in: textView)
        }
    }

    /// 移除所有块级附件的覆盖视图并清空记录。
    private func clearBlocks() {
        for block in startedBlocks { block.att.removeStreamingView() }
        startedBlocks.removeAll()
    }

    /// 计算某个字符（附件）在 textView 坐标系里的矩形。
    private func rectForAttachment(at index: Int) -> CGRect {
        guard index < textView.textStorage.length else { return .zero }
        let lm = textView.layoutManager
        let tc = textView.textContainer
        lm.ensureLayout(for: tc)
        let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: index, length: 1),
                                       actualCharacterRange: nil)
        var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        rect.origin.x += textView.textContainerInset.left
        rect.origin.y += textView.textContainerInset.top
        return rect
    }

    /// 已显示文字实际占用的尺寸（适配当前 / 最大宽度，并限制到最大 / 最小宽高）。
    public var textContentSize: CGSize {
        var width = maxTextWidth > 0 ? maxTextWidth : textView.bounds.width
        if width <= 0 { width = bounds.width }
        if width <= 0 { width = .greatestFiniteMagnitude }

        var height = maxTextHeight > 0 ? maxTextHeight : textView.bounds.height
        if height <= 0 { height = bounds.height }
        if height <= 0 { height = .greatestFiniteMagnitude }

        let fitting = textView.sizeThatFits(CGSize(width: width, height: height))
        var w = ceil(fitting.width)
        var h = ceil(fitting.height)
        if maxTextWidth > 0 { w = min(w, maxTextWidth) }
        if maxTextHeight > 0 { h = min(h, maxTextHeight) }
        if minTextWidth > 0 { w = max(w, minTextWidth) }
        if minTextHeight > 0 { h = max(h, minTextHeight) }
        // 防止把 NaN / 无穷大 传给 Auto Layout（会直接崩溃）。
        if !w.isFinite { w = 0 }
        if !h.isFinite { h = 0 }
        
        return CGSize(width: w, height: h)
    }

    private func notifyContentSizeChangeIfNeeded() {
        let size = textContentSize
        if size.equalTo(lastContentSize) { return }
        lastContentSize = size
        invalidateContentSize()
        delegate?.streamingTextView?(self, didChangeContentSize: size)
        onContentSizeChange?(size)
    }

    private func invalidateContentSize() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    public override var intrinsicContentSize: CGSize {
        lastContentSize
    }
}
