//
//  TableStreamViewController.swift
//  ZLStreamingTextView_Example
//
//  UITableView，cell 内嵌 ZLStreamingTextView，逐条流式打印，行高随文字增长并自动跟随滚动。
//

import UIKit
import StreamingTextView

private let kCellHInset: CGFloat = 12.0   // 气泡与 cell 左右间距
private let kCellVInset: CGFloat = 10.0   // 气泡与 cell 上下间距

// MARK: - Model

/// 一条流式消息
private class StreamItem {
    var attributedText: NSAttributedString
    var cachedHeight: CGFloat = 0    // 已知的 cell 高度
    var started = false              // 是否已经开始过流式（避免复用时重启）
    var finished = false             // 是否已经打印完成

    init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }
}

// MARK: - Cell

private class StreamCell: UITableViewCell {

    let streamingView = StreamingTextView()
    /// 当内部文字内容高度变化时回调（用于驱动 tableView 更新行高）。
    var onContentHeightChange: ((CGFloat) -> Void)?
    /// 点击到图片附件时回调（被点图片 + 全部图片）。
    var onImageTapped: ((ImageTextAttachment, [ImageTextAttachment]) -> Void)?
    /// 点击到链接时回调。
    var onLinkTapped: ((URL) -> Void)?

    /// textView 手势管理（图片点击 + 链接跳转）。
    private var gestureManager: TextViewGestureManager?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        streamingView.translatesAutoresizingMaskIntoConstraints = false
        streamingView.textView.isScrollEnabled = false   // 由 cell 承载高度
        streamingView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        streamingView.layer.cornerRadius = 10.0
        streamingView.layer.borderWidth = 1.0
        streamingView.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        streamingView.maxTextWidth = UIScreen.main.bounds.width - kCellHInset * 2.0
        contentView.addSubview(streamingView)

        // 用手势管理类统一处理图片点击 + 链接跳转（内部自行添加手势，不拦截 textView 原生交互）。
        gestureManager = TextViewGestureManager(textView: streamingView.textView)
        gestureManager?.onImageTapped = { [weak self] tapped, allImages in
            self?.onImageTapped?(tapped, allImages)
        }
        gestureManager?.onLinkTapped = { [weak self] url in
            self?.onLinkTapped?(url)
        }

        NSLayoutConstraint.activate([
            streamingView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: kCellVInset),
            streamingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -kCellVInset),
            streamingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: kCellHInset),
        ])

        streamingView.onContentSizeChange = { [weak self] size in
            // cell 高度 = 文字高度 + 上下内边距
            self?.onContentHeightChange?(ceil(size.height) + kCellVInset * 2.0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Controller

class TableStreamViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var items: [StreamItem] = []
    private var scriptedMessages: [NSAttributedString] = []
    private var nextScriptIndex = 0
    /// 是否自动跟随到底部（用户手动上滑离开底部后暂停跟随，回到底部附近后恢复）。
    private var autoScrollToBottom = true
    /// 外部可设置：富文本内有多张图片时，预览是否支持左右滑动浏览。
    var allowsImageSwipe = true

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TableView 流式"
        view.backgroundColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                           target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self, action: #selector(addItem))

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 60.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(StreamCell.self, forCellReuseIdentifier: "StreamCell")
        view.addSubview(tableView)

        // 逐条流式输出的“剧本”：一条打印完再追加下一条，内容足够长以便超出屏幕。
        scriptedMessages = buildScriptedMessages()
        nextScriptIndex = 0
        appendNextScriptedMessage()
    }

    @objc private func close() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Data

    private var contentWidth: CGFloat {
        var width = tableView.bounds.width
        if width <= 0 { width = UIScreen.main.bounds.width }
        return width - kCellHInset * 2.0
    }

    private func plainAttributed(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 17.0),
            .foregroundColor: UIColor.darkText])
    }

    private func sampleRichText() -> NSAttributedString {
        let rich = NSMutableAttributedString()
        rich.append(NSAttributedString(string: "富文本消息\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.systemBlue]))
        rich.append(NSAttributedString(string: "支持", attributes: [
            .font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.darkGray]))
        rich.append(NSAttributedString(string: "高亮", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.systemPink]))
        rich.append(NSAttributedString(string: "与下划线，逐帧打印同样保留样式。", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.darkGray,
            .underlineStyle: NSUnderlineStyle.single.rawValue]))
        return rich
    }
    /// 读取 bundle 里的 Markdown 资源。
    private func readmeMarkdown() -> String {
        if let path = Bundle.main.path(forResource: "Test", ofType: "md"),
           let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
            return content
        }
        return "# Test.md 未找到"
    }
    private func markDown() -> NSAttributedString {
        let markdown = readmeMarkdown()
        let maxImageWidth = min(UIScreen.main.bounds.width - 32.0, 300.0) - 24.0
        let options = MarkdownRenderOptions()
        options.fontSize = 16.0
        options.textColor = UIColor(white: 0.15, alpha: 1.0)
        options.maxImageWidth = maxImageWidth
        return DownBridge.attributedString(fromMarkdown: markdown, options: options)!

    }
    private func buildScriptedMessages() -> [NSAttributedString] {
        [
            plainAttributed("你好，我是流式助手 👋，下面用 tableView 逐条演示打字效果。"),
            sampleRichText(),
           
            plainAttributed("你可以在打印过程中手动向上滑动查看历史消息，此时会暂停自动跟随；"
                + "当你重新滑动回底部附近，自动跟随会恢复。"),
            markDown(),
            plainAttributed("再来一条更长的内容，确保总高度超过一屏：\n"
                + "1. 支持纯文本与富文本；\n2. 支持从指定偏移开始；\n3. 支持模拟网络分块追加；\n"
                + "4. 支持最大/最小宽高；\n5. 支持内容尺寸变化回调，从而驱动 cell 高度与列表滚动。\n"
                + "到这里演示基本结束啦，点击右上角“+”还能继续追加新的流式消息。✨"),
        ]
    }

    @objc private func addItem() {
        let text = "手动新增第 \(items.count + 1) 条：点击右上角“+”会追加一条新的流式消息，"
            + "每条都会边打字边把所在的 cell 撑高，并让列表跟随滚动到底部。✨"
        appendItem(StreamItem(attributedText: plainAttributed(text)))
    }

    /// 追加一条消息并插入到列表底部（自动开始流式在 cellForRow 中触发）。
    private func appendItem(_ item: StreamItem) {
        items.append(item)
        autoScrollToBottom = true
        let ip = IndexPath(row: items.count - 1, section: 0)
        tableView.insertRows(at: [ip], with: .fade)
        scrollToBottom(animated: true)
    }

    /// 逐条追加“剧本”消息：当前一条打印完成后再追加下一条。
    private func appendNextScriptedMessage() {
        guard nextScriptIndex < scriptedMessages.count else { return }
        let attr = scriptedMessages[nextScriptIndex]
        nextScriptIndex += 1
        appendItem(StreamItem(attributedText: attr))
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StreamCell", for: indexPath) as! StreamCell
        let item = items[indexPath.row]

        cell.streamingView.maxTextWidth = contentWidth

        cell.onContentHeightChange = { [weak self, weak item] height in
            guard let self = self, let item = item else { return }
            self.handleHeightChange(height, for: item)
        }
        cell.streamingView.onComplete = { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            self.handleFinish(for: item)
        }
        cell.onImageTapped = { [weak self] tapped, allImages in
            guard let self = self else { return }
            var images: [UIImage] = []
            var startIndex = 0
            for att in allImages {
                if let img = att.image {
                    if att === tapped { startIndex = images.count }
                    images.append(img)
                }
            }
            guard !images.isEmpty else { return }
            ImagePreviewer.shared.present(images,
                                          startIndex: startIndex,
                                          from: self.view,
                                          allowsSwipe: self.allowsImageSwipe)
        }
        cell.onLinkTapped = { url in
            UIApplication.shared.open(url)
        }

        // 仅首次开始流式，避免复用 / 行高刷新时重启动画。
        if !item.started {
            item.started = true
            cell.streamingView.charactersPerFrame = 1
            cell.streamingView.frameInterval = 2
            cell.streamingView.startStreamingAttributedText(item.attributedText)
        }else {
            // 复用时直接显示完整内容。
            cell.streamingView.reset()
            cell.streamingView.textView.attributedText = item.attributedText
        }
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = items[indexPath.row]
        return item.cachedHeight > 0 ? item.cachedHeight : UITableView.automaticDimension
    }

    // MARK: - Height driving

    /// 文字内容高度变化 -> 更新缓存并平滑刷新对应行高（不重建 cell，流式动画不中断）。
    private func handleHeightChange(_ height: CGFloat, for item: StreamItem) {
        if abs(item.cachedHeight - height) < 0.5 { return }
        item.cachedHeight = height

        // beginUpdates/endUpdates 只会重新询问行高，不会调用 cellForRow 重建 cell。
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        if autoScrollToBottom {
            scrollToBottom(animated: true)
        }
    }

    /// 某条消息打印完成 -> 追加下一条“剧本”消息。
    private func handleFinish(for item: StreamItem) {
        if item.finished { return }
        item.finished = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.appendNextScriptedMessage()
        }
    }

    // MARK: - Auto scroll

    private var effectiveContentInset: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return tableView.adjustedContentInset
        }
        return tableView.contentInset
    }

    private func scrollToBottom(animated: Bool) {
        tableView.layoutIfNeeded()
        let inset = effectiveContentInset
        let minOffset = -inset.top
        var bottomOffset = tableView.contentSize.height - tableView.bounds.size.height + inset.bottom
        bottomOffset = max(bottomOffset, minOffset)
        tableView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: animated)
    }

    private var isNearBottom: Bool {
        let distanceToBottom = tableView.contentSize.height
            - (tableView.contentOffset.y + tableView.bounds.size.height)
            + effectiveContentInset.bottom
        return distanceToBottom <= 44.0
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging || scrollView.isDecelerating {
            autoScrollToBottom = isNearBottom
        }
    }
}
