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

@objcMembers
public class DownBridge: NSObject {

    /// 供 Objective-C 读取图片 URL 的属性名。
    public static let imageURLAttributeName = "ZLImageURL"

    /// 创建一个使用 Down 的 `DownLayoutManager` 的 UITextView。
    /// Down 的代码块背景 / 引用竖线 / 分隔线等是自定义 block 属性，
    /// 只有 `DownLayoutManager` 才会绘制；普通 UITextView 的默认 layoutManager 不会画，
    /// 所以要展示代码块背景色必须用它来承载文本。
    public static func makeDownTextView() -> UITextView {
        let textStorage = NSTextStorage()
        let layoutManager = DownLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)

        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        return textView
    }

    /// Parse Markdown into an attributed string with a base font size and text color.
    public static func attributedString(fromMarkdown markdown: String,
                                        fontSize: CGFloat,
                                        textColor: UIColor) -> NSAttributedString? {
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

        let configuration = DownStylerConfiguration(fonts: fonts,
                                                    colors: colors,
                                                    paragraphStyles: paragraphStyles,
                                                    codeBlockOptions: codeBlockOptions)

        do {
            // 使用自定义 styler，让图片变成真正的 NSTextAttachment（并携带 URL）。
            return try Down(markdownString: markdown)
                .toAttributedString(.normalize, styler: ImageStyler(configuration: configuration))
        } catch {
            print("Error converting markdown: \(error)")
            return nil
        }
    }

    /// 处理富文本中的图片：把图片占位附件替换为会自下载的 `ImageTextAttachment`
    /// 并触发下载。每当有图片下载完成，会回调 `onImageLoaded(range)`，外部据此刷新
    /// 对应区域 / 高度。返回替换后的富文本（图片先显示占位，下载完成后自动更新）。
    /// - Parameters:
    ///   - attributedText: 待处理的富文本（通常来自 `attributedString(fromMarkdown:...)`）。
    ///   - maxImageWidth: 图片显示的最大宽度（按比例缩放）。
    ///   - onImageLoaded: 单张图片下载完成后的回调，参数为其在富文本中的 range。
    public static func processImages(in attributedText: NSAttributedString,
                                     maxImageWidth: CGFloat,
                                     onImageLoaded: ((NSRange) -> Void)?) -> NSAttributedString {
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
            attachment.onImageLoaded = { _ in
                onImageLoaded?(range)
            }
            rich.addAttribute(.attachment, value: attachment, range: range)
            attachment.loadImage()
        }

        return rich
    }

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
