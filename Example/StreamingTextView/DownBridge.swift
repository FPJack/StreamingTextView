//
//  DownBridge.swift
//  ZLStreamingTextView_Example
//
//  Objective-C friendly bridge that uses the `Down` framework to render
//  CommonMark Markdown into an NSAttributedString.
//

import Foundation
import UIKit
import Down
import SDWebImage
import StreamingTextView

/// 自定义 NSTextAttachment：内部用 SDWebImage 下载网络图片，
/// 下载完成后自动更新自身 image / bounds，并回调通知外部刷新 UI。
@objcMembers
public class ImageTextAttachment: NSTextAttachment {

    /// 网络图片地址。
    public var imageURLString: String?

    /// 图片显示的最大宽度（按比例缩放）。<=0 表示不限制。
    public var maxImageWidth: CGFloat = 0

    /// 下载前占位高度（预留排版空间），默认 120。
    public var placeholderHeight: CGFloat = 120

    /// 图片下载完成（成功）后回调，外部据此刷新对应区域 / 高度。
    public var onImageLoaded: ((ImageTextAttachment) -> Void)?

    /// 图片被点击后回调，外部据此做预览 / 跳转等操作。
    public var onImageTapped: ((ImageTextAttachment) -> Void)?

    public var range: NSRange = NSRange(location: 0, length: 0)

    /// 开始异步下载图片（会先设置占位图，完成后替换并回调）。
    public func loadImage() {
        // 1) 先放一个占位图，保证排版预留空间。
        let placeholderWidth = maxImageWidth > 0 ? maxImageWidth : 200
        if image == nil {
            image = ImageTextAttachment.placeholderImage(of: CGSize(width: placeholderWidth, height: placeholderHeight))
            bounds = CGRect(x: 0, y: 0, width: placeholderWidth, height: placeholderHeight)
        }

        guard let urlString = imageURLString, !urlString.isEmpty,
              let url = URL(string: urlString) else { return }

        // 2) 内部用 SDWebImage 异步下载（带缓存），完成回调已在主线程。
        SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { [weak self] image, _, _, _, _, _ in
            guard let self = self, let image = image else { return }

            // 3) 更新自身 image / bounds（按最大宽度等比缩放）。
            self.image = image
            let w = self.maxImageWidth > 0 ? min(image.size.width, self.maxImageWidth) : image.size.width
            let h = image.size.width > 0 ? image.size.height * (w / image.size.width) : image.size.height
            self.bounds = CGRect(x: 0, y: 0, width: floor(w), height: floor(h))

            // 4) 通知外部刷新。
            self.onImageLoaded?(self)
        }
    }

    /// 生成一个纯色占位图，用于图片下载前预留空间。
    private static func placeholderImage(of size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor(white: 0.92, alpha: 1.0).setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

/// 自定义 Styler：Down 默认会把 Markdown 图片 `![alt](url)` 渲染成「alt 文本 + link 属性」，
/// 并不会生成 NSTextAttachment（alt 为空时甚至是空串）。这里改成插入一个占位的
/// NSTextAttachment，并把图片 URL 存到自定义属性上，方便 Objective-C 侧下载并回填图片。
public class ImageStyler: DownStyler {
    /// 存放图片 URL 的自定义属性 key（Objective-C 可用同名字符串读取）。
    public static let imageURLKey = NSAttributedString.Key("ZLImageURL")

    /// 行内代码 `like this` 的高亮背景色。
    public var inlineCodeBackground: UIColor = UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)

    /// 标记「行内代码」范围的自定义属性 key。
    /// 引用样式 `style(blockQuote:)` 会用 `colors.quote` 覆盖整段前景色，
    /// 从而抹掉行内代码的红色文字。用这个标记把行内代码的范围记下来，
    /// 便于在引用样式应用之后再把代码的前景 / 背景色还原回去。
    private static let inlineCodeMarkerKey = NSAttributedString.Key("ZLInlineCode")

    /// 重写行内代码样式：在父类（等宽字体 + 文字颜色）基础上，追加背景高亮色，
    /// 并打上标记，供引用场景还原样式。
    /// 注意 NSAttributedString 的 `.backgroundColor` 是矩形填充（无圆角），
    /// 但对行内代码的视觉区分已经足够。
    public override func style(code str: NSMutableAttributedString) {
        super.style(code: str)
        let range = NSRange(location: 0, length: str.length)
        str.addAttribute(.backgroundColor, value: inlineCodeBackground, range: range)
        str.addAttribute(ImageStyler.inlineCodeMarkerKey, value: true, range: range)
    }

    /// 重写引用样式：父类会用 `colors.quote` 覆盖整段前景色，抹掉引用内行内代码的红字。
    /// 这里在父类处理完之后，找出被标记为行内代码的范围，重新还原它的前景色和背景高亮，
    /// 保证「引用内的行内代码」和「普通行内代码」外观一致。
    public override func style(blockQuote str: NSMutableAttributedString, nestDepth: Int) {
        super.style(blockQuote: str, nestDepth: nestDepth)
        let fullRange = NSRange(location: 0, length: str.length)
        str.enumerateAttribute(ImageStyler.inlineCodeMarkerKey, in: fullRange, options: []) { value, range, _ in
            guard value != nil else { return }
            str.addAttribute(.foregroundColor, value: colors.code, range: range)
            str.addAttribute(.backgroundColor, value: inlineCodeBackground, range: range)
        }
    }

    public override func style(image str: NSMutableAttributedString, title: String?, url: String?) {
        let attachment = NSTextAttachment()          // 占位附件，图片稍后由 App 侧下载填入
        let placeholder = NSMutableAttributedString(attachment: attachment)
        if let url = url {
            let range = NSRange(location: 0, length: placeholder.length)
            placeholder.addAttribute(ImageStyler.imageURLKey, value: url, range: range)
        }
        // 用附件替换掉原本的 alt 文本内容。
        str.setAttributedString(placeholder)
    }
}

/// Markdown 渲染配置：除 markdown 字符串外的所有参数都收拢到这个对象里。
@objcMembers
public class MarkdownRenderOptions: NSObject {

    /// 正文基准字号。
    public var fontSize: CGFloat = 16.0

    /// 正文文字颜色。
    public var textColor: UIColor = UIColor(white: 0.15, alpha: 1.0)

    /// 图片显示的最大宽度（按比例缩放）。<=0 表示不限制。
    public var maxImageWidth: CGFloat = 0

    /// 单张图片下载完成后的回调，参数为其在富文本中的 range。
    public var onImageLoaded: ((ImageTextAttachment) -> Void)?

    /// 图片点击事件回调。
    /// - 参数 1：被点击的图片附件。
    /// - 参数 2：所在 textView 里按顺序排列的全部图片附件（用于多图左右滑动浏览）。
    public var onImageTapped: ((ImageTextAttachment, [ImageTextAttachment]) -> Void)?

    /// 链接点击事件回调（参数为链接 URL）。
    public var onLinkTapped: ((URL) -> Void)?

    /// 表格配置：外部可传入以自定义 Markdown 里表格（`GridTableView`）的样式与行为
    /// （列宽 / 分割线 / 边框 / 表头样式 / 滑动模式等）。为 nil 时使用内部默认配置。
    /// 注意：`GridTableView` 需要 iOS 13+，此配置在 iOS 13 以下不生效。
    @available(iOS 13.0, *)
    public var tableConfiguration: GridTableConfiguration? {
        get { _tableConfiguration as? GridTableConfiguration }
        set { _tableConfiguration = newValue }
    }
    /// 类型擦除存储（避免给存储属性直接标注 @available 带来的限制）。
    private var _tableConfiguration: Any?

    /// 承载富文本的 textView。设置后，`attributedString(fromMarkdown:options:)`
    /// 会自动为其绑定手势交互（图片点击 + 链接跳转），无需外部再手动调用 `bindGestures(to:)`。
    public weak var textView: UITextView?

    public override init() {
        super.init()
    }

    /// 便捷初始化。
    public convenience init(fontSize: CGFloat,
                            textColor: UIColor,
                            maxImageWidth: CGFloat,
                            onImageLoaded: ((ImageTextAttachment) -> Void)? = nil) {
        self.init()
        self.fontSize = fontSize
        self.textColor = textColor
        self.maxImageWidth = maxImageWidth
        self.onImageLoaded = onImageLoaded
    }

    /// 给指定 textView 绑定手势交互（图片点击 + 链接跳转）：
    /// 内部会**自动判断是否需要绑定**——只有设置了 `onImageTapped` 或 `onLinkTapped`
    /// 才创建 `TextTapGesture` 并赋值回调；两者都为空则不绑定，返回 nil。
    ///
    /// 绑定前会先移除 textView 上由本类添加过的旧手势，避免重复叠加；
    /// 新建的 manager 由「textView → 手势 → manager」这条引用链天然持有，
    /// 外部无需额外保存（无需关联对象）。
    /// - Parameter textView: 承载富文本（图片附件 / 链接）的 UITextView。
    /// - Returns: 绑定好的手势管理器；无需绑定时返回 nil。
    @MainActor
    @discardableResult
    public func bindGestures(to textView: UITextView) -> TextTapGesture? {
        // 先移除旧的同名手势（连带释放其持有的旧 manager），避免重复绑定。
        textView.gestureRecognizers?
            .filter { $0.name == TextTapGesture.gestureName }
            .forEach { textView.removeGestureRecognizer($0) }

        // 自动判断：没有任何点击回调时无需绑定。
        guard onImageTapped != nil || onLinkTapped != nil else { return nil }

        let manager = TextTapGesture(textView: textView)
        manager.onImageTapped = onImageTapped
        manager.onLinkTapped = onLinkTapped
        return manager
    }
}

@objcMembers
public class DownBridge: NSObject {

    /// 供 Objective-C 读取图片 URL 的属性名。
    public static let imageURLAttributeName = "ZLImageURL"

    // MARK: - 流式增量解析（实例）

    /// 承载渲染结果的流式视图（弱引用，避免循环引用）。
    public weak var streamingView: StreamingTextView?
    /// 渲染配置（字号 / 颜色 / 图片宽度 / 表格配置等）。
    public var renderOptions: MarkdownRenderOptions

    /// 已累积、需保留用于「整体重新解析」的完整 markdown 原文。
    private let accumulatedMarkdown = NSMutableString()
    /// 当前已在 textView 上显示（揭示）的富文本字符数。
    /// 由 streamingView 的进度回调维护，作为下次重新赋值时的「续播起点」。
    private var displayedLength = 0
    /// 上一次已解析渲染到的原文长度（去重，避免无变化时重复解析）。
    private var parsedSourceLength = 0
    /// 是否正处于一次逐字揭示中（true 时不重新解析，避免打断进行中的动画）。
    private var isRevealing = false
    /// 数据流是否已结束（结束后允许解析最后不足一行的尾巴）。
    private var streamFinished = false

    /// 流式揭示进度回调（已显示字符数，缓冲总字符数），供外部更新 UI / 跟随滚动。
    public var onStreamProgress: ((_ displayed: Int, _ total: Int) -> Void)?

    /// 实例化初始化：用于「分块到达的 markdown 增量流式解析」。
    /// - Parameters:
    ///   - streamingView: 承载渲染结果的流式视图。
    ///   - options: 渲染配置。
    @MainActor
    public init(streamingView: StreamingTextView, options: MarkdownRenderOptions) {
        self.streamingView = streamingView
        self.renderOptions = options
        super.init()
        bindStreamingCallbacks()
    }

    /// 绑定 streamingView 的进度 / 完成回调：记录「已显示位置」，并在揭示完成后继续解析。
    @MainActor
    private func bindStreamingCallbacks() {
        streamingView?.onProgress = { [weak self] visible, total in
            guard let self = self else { return }
            // textView 记录已经显示的位置。
            self.displayedLength = visible
            self.onStreamProgress?(visible, total)
        }
        streamingView?.onComplete = { [weak self] in
            guard let self = self, let view = self.streamingView else { return }
            self.isRevealing = false
            self.displayedLength = view.totalLength
            // 本轮揭示完成后，若期间累积了新内容，继续解析下一段。
            self.renderIfIdle()
        }
    }

    /// 追加一段 markdown 原文并触发增量流式渲染。
    /// 内部会「拼接保留原文 → 整体重新解析 → 赋值给 textView → 从上次显示处续播」。
    @MainActor
    public func appendMarkdown(_ markdownChunk: String) {
        guard !markdownChunk.isEmpty else { return }
        accumulatedMarkdown.append(markdownChunk)
        if markdownChunk.contains("\n| --- |") {
            NSLog("Appended markdown chunk: \\n| --- |\\n");
        }
        NSLog("Appended markdown chunk: start %@", markdownChunk);

        renderIfIdle()
      
        NSLog("Appended markdown chunk: end%@", markdownChunk);
        
    }

    /// 通知数据流结束：把最后不足一行的尾巴也解析显示出来。
    @MainActor
    public func finishStreaming() {
        streamFinished = true
        renderIfIdle()
    }

    /// 重置流式状态（清空累积原文与显示）。
    @MainActor
    public func resetStreaming() {
        accumulatedMarkdown.setString("")
        displayedLength = 0
        parsedSourceLength = 0
        isRevealing = false
        streamFinished = false
        streamingView?.reset()
    }

    /// 计算可安全解析的「已提交前缀」长度：
    /// - 未结束时，取到最后一个换行（含）为止的完整行，避免把半行 markdown 解析成破碎文本；
    /// - 已结束时，取全部（尾巴也解析）。
    private func committedSourceLength() -> Int {
        if streamFinished { return accumulatedMarkdown.length }
        let newline = accumulatedMarkdown.range(of: "\n", options: .backwards)
        return newline.location == NSNotFound ? 0 : newline.location + newline.length
    }

    /// 在流式空闲时：把保留的原文（已提交前缀）整体重新解析，赋值给 textView，
    /// 并谨慎地从「上次已显示位置」继续流式打印（严格夹取下标，避免越界）。
    @MainActor
    private func renderIfIdle() {
        guard !isRevealing else {
            print("DownBridge: renderIfIdle() skipped because isRevealing == true")
            return
        }              // 不打断进行中的揭示 / 表格动画
        guard let view = streamingView else { return }

        let committed = committedSourceLength()
        guard committed > parsedSourceLength else { return }   // 没有新的完整内容
        parsedSourceLength = committed

        // 1) 整体重新解析保留的原文前缀，生成全新的富文本。
        let markdown = accumulatedMarkdown.substring(to: committed)
        let full = DownBridge.attributedString(fromMarkdown: markdown, options: renderOptions)
            ?? NSAttributedString(string: markdown,
                                  attributes: [.font: UIFont.systemFont(ofSize: renderOptions.fontSize)])

        // 2) 谨慎处理「上一次已显示位置」：严格夹取到 [0, full.length]，避免下标越界。
        //    （即使新一次解析后整体变短，也不会越界。）
        let startLength = max(0, min(displayedLength, full.length))

        // 3) 重新赋值富文本，并从上次已显示处继续流式打印。
        isRevealing = true
        view.startStreamingAttributedText(full, fromLength: startLength)

        // 4) 若本次没有需要逐字揭示的新内容（startLength 已到末尾，不会触发 onComplete），
        //    立即恢复空闲，以便后续再解析。
        if startLength >= full.length {
            isRevealing = false
            displayedLength = full.length
            onStreamProgress?(full.length, full.length)
        }
    }

    // MARK: - 静态工具

    /// 创建一个使用 Down 的 `DownLayoutManager` 的 UITextView。
    /// Down 的代码块背景 / 引用竖线 / 分隔线等是自定义 block 属性，
    /// 只有 `DownLayoutManager` 才会绘制；普通 UITextView 的默认 layoutManager 不会画，
    /// 所以要展示代码块背景色必须用它来承载文本。
   @MainActor public static func makeDownTextView() -> UITextView {
        let textStorage = NSTextStorage()
        let layoutManager = DownLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        return textView
    }

    /// 解析 Markdown 为富文本，并在方法内部直接完成图片下载（占位 → 异步下载 → 回填）。
    /// 返回的富文本中，图片先显示占位，下载完成后自动更新，并通过 `options.onImageLoaded(range)` 回调刷新对应区域。
    ///
    /// 同时会检测 Markdown 里的**表格**（GFM 竖线表格）：
    /// 命中后把该表格解析成数据，用 `GridTableAttachment` 作为「块级流式附件」插入富文本，
    /// 在文本里预留出表格的完整尺寸（占位空白）。真正的 `GridTableView` 会由
    /// `StreamingTextView` 叠加到占位区域上方，并在文字流式打印到此处时**先逐行打印表格**，
    /// 表格打印完再继续打印后面的文字。
    /// - Parameters:
    ///   - markdown: Markdown 源码。
    ///   - options: 渲染配置（字号、颜色、图片最大宽度、图片下载回调等）。
    @MainActor
    public static func attributedString(fromMarkdown markdown: String,
                                        options: MarkdownRenderOptions) -> NSAttributedString? {
        let configuration = makeConfiguration(fontSize: options.fontSize, textColor: options.textColor)
        let segments = MarkdownTableParser.parseSegments(markdown)
        // 2) 逐段渲染并拼接。
        let result = NSMutableAttributedString()
        let newlineAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: options.fontSize)]
        for segment in segments {
            switch segment {
            case .text(let text):
                // 文本段：交给 Down 渲染。
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                if let parsed = try? Down(markdownString: text)
                    .toAttributedString(.normalize, styler: ImageStyler(configuration: configuration)) {
                    result.append(parsed)
                }
            case .table(let table):
                // 优先使用外部传入的表格配置；未提供则用内部默认配置。
                let tableConfig = options.tableConfiguration
                ?? makeTableConfiguration(maxWidth: options.maxImageWidth,
                                          fontSize: options.fontSize,
                                          textColor: options.textColor)
                let attachment = GridTableAttachment(rows: table, configuration: tableConfig)
                // 表格自成一块，前后补换行，保证独占段落。
                if result.length > 0 { result.append(NSAttributedString(string: "\n", attributes: newlineAttrs)) }
                result.append(NSAttributedString(attachment: attachment))
                result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
            }
        }

        guard result.length > 0 else { return nil }

        // 3) 处理图片（表格附件没有 URL，会被自动跳过）。
        let final = processImages(in: result,
                                  maxImageWidth: options.maxImageWidth,
                                  onImageLoaded: options.onImageLoaded)
        // 4) 若设置了 textView，则自动绑定手势（内部会按需判断是否真的需要绑定）。
        if let textView = options.textView {
            options.bindGestures(to: textView)
        }
        return final
    }

    /// 构建 Down 的样式配置（字体 / 颜色 / 段落样式 / 代码块选项）。
    private static func makeConfiguration(fontSize: CGFloat, textColor: UIColor) -> DownStylerConfiguration {
        var fonts = StaticFontCollection()
        fonts.body = UIFont.systemFont(ofSize: fontSize)
        fonts.heading1 = UIFont.boldSystemFont(ofSize: fontSize + 9)
        fonts.heading2 = UIFont.boldSystemFont(ofSize: fontSize + 6)
        fonts.heading3 = UIFont.boldSystemFont(ofSize: fontSize + 3)
        // 行内代码 + 代码块的字体（等宽字体）。
        fonts.code = UIFont(name: "Menlo", size: fontSize - 1) ?? UIFont.systemFont(ofSize: fontSize - 1)

        var colors = StaticColorCollection()
        colors.body = textColor
        colors.heading1 = textColor
        colors.heading2 = textColor
        colors.heading3 = textColor
        // 代码文字颜色 + 代码块背景色（背景色由 codeBlockBackground 控制）。
        colors.code = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0) // 深红色
        colors.codeBlockBackground = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1) // 浅灰蓝色

        // 代码块段落样式：行距、首行/整体缩进。
        var paragraphStyles = StaticParagraphStyleCollection()
        let codeParagraph = NSMutableParagraphStyle()
        codeParagraph.lineSpacing = 10
        codeParagraph.paragraphSpacingBefore = 6
        codeParagraph.paragraphSpacing = 6
        codeParagraph.firstLineHeadIndent = 8
        codeParagraph.headIndent = 8
        codeParagraph.tailIndent = -8
        paragraphStyles.code = codeParagraph

        // 标题段落样式：加大标题上下间距。
        let makeHeadingStyle: (CGFloat, CGFloat) -> NSParagraphStyle = { before, after in
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = before   // 标题前留白
            style.paragraphSpacing = after          // 标题后留白
            return style
        }
        paragraphStyles.heading1 = makeHeadingStyle(24, 12)
        paragraphStyles.heading2 = makeHeadingStyle(20, 10)
        paragraphStyles.heading3 = makeHeadingStyle(16, 8)
        paragraphStyles.heading4 = makeHeadingStyle(14, 8)
        paragraphStyles.heading5 = makeHeadingStyle(12, 6)
        paragraphStyles.heading6 = makeHeadingStyle(12, 6)

        // 代码块背景容器的内边距。
        let codeBlockOptions = CodeBlockOptions(containerInset: 8)

        return DownStylerConfiguration(fonts: fonts,
                                       colors: colors,
                                       paragraphStyles: paragraphStyles,
                                       codeBlockOptions: codeBlockOptions)
    }

    // MARK: - 表格配置

    /// 表格配置（用于聊天气泡内展示：限制最大宽度、可横向滑动、蓝底表头）。
    @available(iOS 13.0, *)
    private static func makeTableConfiguration(maxWidth: CGFloat,
                                               fontSize: CGFloat,
                                               textColor: UIColor) -> GridTableConfiguration {
        var config = GridTableConfiguration()
        config.scrollMode = .horizontal      // 列多时可横向滑动
        config.hasHeaderRow = true
        config.stickyHeader = false
        if maxWidth > 0 { config.maxTableWidth = maxWidth }
        config.maxColumnWidth = maxWidth > 0 ? maxWidth : 200
        config.minColumnWidth = 44
        config.separator = GridSeparatorStyle(width: 1, color: UIColor(white: 0.85, alpha: 1))
        config.border = GridBorderStyle(width: 1, color: UIColor(white: 0.8, alpha: 1), cornerRadius: 8)

        var header = GridCellStyle()
        header.font = .boldSystemFont(ofSize: fontSize - 1)
        header.textColor = .white
        header.backgroundColor = .red
        header.textAlignment = .center
        config.headerStyle = header

        var cell = GridCellStyle()
        cell.font = .systemFont(ofSize: fontSize - 1)
        cell.textColor = textColor
        cell.backgroundColor = .white
        config.cellStyle = cell
        return config
    }

    // MARK: - 图片处理

    /// 处理富文本中的图片：把图片占位附件替换为会自下载的 `ImageTextAttachment`
    /// 并触发下载。每当有图片下载完成，会回调 `onImageLoaded(range)`，外部据此刷新
    /// 对应区域 / 高度。返回替换后的富文本（图片先显示占位，下载完成后自动更新）。
    /// - Parameters:
    ///   - attributedText: 待处理的富文本（通常来自 `attributedString(fromMarkdown:...)`）。
    ///   - maxImageWidth: 图片显示的最大宽度（按比例缩放）。
    ///   - onImageLoaded: 单张图片下载完成后的回调，参数为其在富文本中的 range。
    ///   - onImageTapped: 图片点击事件回调，参数为被点击的图片附件。
    public static func processImages(in attributedText: NSAttributedString,
                                     maxImageWidth: CGFloat,
                                     onImageLoaded: ((ImageTextAttachment) -> Void)?,
                                     onImageTapped: ((ImageTextAttachment) -> Void)? = nil) -> NSAttributedString {
        let rich = NSMutableAttributedString(attributedString: attributedText)
        let urlKey = NSAttributedString.Key(imageURLAttributeName)
        let fullRange = NSRange(location: 0, length: rich.length)

        // 在不可变快照上遍历，块内可安全地修改 rich（range 长度不变）。
        (rich.copy() as! NSAttributedString).enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            guard value is NSTextAttachment else { return }
            guard let urlStr = rich.attribute(urlKey, at: range.location, effectiveRange: nil) as? String,
                  !urlStr.isEmpty else { return }

            let attachment = ImageTextAttachment()
            attachment.imageURLString = urlStr
            attachment.maxImageWidth = maxImageWidth
            attachment.range = range
            attachment.onImageLoaded = { attach in
                onImageLoaded?(attach)
            }
            attachment.onImageTapped = onImageTapped
            rich.addAttribute(.attachment, value: attachment, range: range)
            attachment.loadImage()
        }

        return rich
    }

    /// 根据点击坐标，在 UITextView 中命中图片附件（`ImageTextAttachment`）。
    /// 用于给承载 Markdown 富文本的 textView 加点击手势后定位被点的图片。
    /// - Parameters:
    ///   - point: 相对于 textView 的点击坐标（如 `gesture.location(in: textView)`）。
    ///   - textView: 承载富文本的 UITextView。
    /// - Returns: 命中的图片附件，未命中返回 nil。
   @MainActor public static func imageAttachment(at point: CGPoint, in textView: UITextView) -> ImageTextAttachment? {
        let layoutManager = textView.layoutManager
        let container = textView.textContainer

        // 换算到 textContainer 坐标系（扣除内边距）。
        var location = point
        location.x -= textView.textContainerInset.left
        location.y -= textView.textContainerInset.top

        let glyphIndex = layoutManager.glyphIndex(for: location, in: container)
        // 确认点击确实落在该 glyph 的绘制矩形内，避免点空白也命中最近的图片。
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: container)
        guard glyphRect.contains(location) else { return nil }

        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < textView.textStorage.length else { return nil }
        return textView.textStorage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? ImageTextAttachment
    }

    /// 按出现顺序收集富文本里的全部图片附件（`ImageTextAttachment`）。
    /// 用于多图预览时左右滑动浏览。
    /// - Parameter textView: 承载富文本的 UITextView。
    /// - Returns: 顺序排列的图片附件数组。
    @MainActor public static func imageAttachments(in textView: UITextView) -> [ImageTextAttachment] {
        var result: [ImageTextAttachment] = []
        let storage = textView.textStorage
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
            if let attachment = value as? ImageTextAttachment {
                result.append(attachment)
            }
        }
        return result
    }

    // MARK: - AST 调试

    /// 递归遍历并打印 AST。
    /// - Parameters:
    ///   - node: 当前节点（Down 的 `Node` 包装类型，其 `children` 已经是子节点数组）
    ///   - indent: 当前缩进，用于体现层级
    static func printAST(_ node: Node, indent: String = "") {
        let cmarkNode = node.cmarkNode

        // 打印当前节点类型（中文）
        print("\(indent)\(chineseTypeName(for: node))")

        // 如果有文字内容，打印出来
        if let literal = cmarkNode.literal {
            print("\(indent)  literal: \(literal)")
        }

        // 递归遍历所有子节点，缩进加深一层
        for child in node.children {
            printAST(child, indent: indent + "  ")
        }
    }

    /// 将 Down 的 AST 节点映射为中文类型名称。
    static func chineseTypeName(for node: Node) -> String {
        switch node {
        case is Document:      return "文档"
        case let heading as Heading:
                               return "标题(H\(heading.headingLevel))"
        case is Paragraph:     return "段落"
        case is Text:          return "文本"
        case is Strong:        return "加粗"
        case is Emphasis:      return "斜体"
        case is Code:          return "行内代码"
        case is CodeBlock:     return "代码块"
        case is BlockQuote:    return "引用"
        case is List:          return "列表"
        case is Item:          return "列表项"
        case is Link:          return "链接"
        case is Image:         return "图片"
        case is ThematicBreak: return "分隔线"
        case is SoftBreak:     return "软换行"
        case is LineBreak:     return "硬换行"
        case is HtmlBlock:     return "HTML 块"
        case is HtmlInline:    return "行内 HTML"
        case is CustomBlock:   return "自定义块"
        case is CustomInline:  return "自定义行内"
        default:               return "未知(\(node.cmarkNode.type))"
        }
    }
}
