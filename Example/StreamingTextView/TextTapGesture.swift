//
//  TextTapGesture.swift
//  StreamingTextView_Example
//
//  统一管理 UITextView 的手势交互：图片点击 + 链接点击。
//  本类直接继承 UITapGestureRecognizer——textView 会强引用自己的手势，
//  因此 manager 的生命周期天然随手势挂在 textView 上，无需关联对象或外部属性持有。
//  只有点到「图片」或「链接」时才接收触摸，否则放行给 UITextView 处理
//  自身的文本选择等手势，不会拦截原生交互。
//

import UIKit

@MainActor
public class TextTapGesture: UITapGestureRecognizer, UIGestureRecognizerDelegate {

    /// 手势名字标记：用于在 textView 上识别 / 移除本类添加的手势，避免重复叠加。
    public static let gestureName = "com.streamingtextview.TextTapGesture"

    /// 点击到图片附件时回调。
    /// - 参数 1：被点击的图片附件。
    /// - 参数 2：当前 textView 里按顺序排列的全部图片附件（用于多图左右滑动浏览）。
    public var onImageTapped: ((ImageTextAttachment, [ImageTextAttachment]) -> Void)?

    /// 点击到链接时回调（参数为链接 URL）。
    public var onLinkTapped: ((URL) -> Void)?

    /// 被管理的 textView（弱引用，避免循环持有）。
    private weak var boundTextView: UITextView?

    /// 绑定到指定 textView，并自动把自己作为点击手势添加上去。
    /// - Parameter textView: 承载富文本（图片附件 / 链接）的 UITextView。
    public init(textView: UITextView) {
        super.init(target: nil, action: nil)
        self.boundTextView = textView
        self.addTarget(self, action: #selector(handleTap))
        self.delegate = self
        self.name = TextTapGesture.gestureName
        textView.addGestureRecognizer(self)
    }

    // MARK: - Tap handling

    @objc private func handleTap() {
        guard let textView = boundTextView else { return }
        let point = location(in: textView)

        // 优先命中图片附件。
        if let attachment = DownBridge.imageAttachment(at: point, in: textView) {
            let allImages = DownBridge.imageAttachments(in: textView)
            onImageTapped?(attachment, allImages)
            return
        }
        // 其次命中链接。
        if let url = link(at: point, in: textView) {
            onLinkTapped?(url)
        }
    }

    // MARK: - Hit test

    /// 命中链接：返回点击处的 `.link` 属性对应的 URL。
    private func link(at point: CGPoint, in textView: UITextView) -> URL? {
        guard let charIndex = characterIndex(at: point, in: textView),
              charIndex < textView.textStorage.length else { return nil }
        let value = textView.textStorage.attribute(.link, at: charIndex, effectiveRange: nil)
        if let url = value as? URL { return url }
        if let str = value as? String { return URL(string: str) }
        return nil
    }

    /// 把点击坐标换算为字符索引（要求点击确实落在某个 glyph 的绘制矩形内）。
    private func characterIndex(at point: CGPoint, in textView: UITextView) -> Int? {
        let layoutManager = textView.layoutManager
        let container = textView.textContainer

        var location = point
        location.x -= textView.textContainerInset.left
        location.y -= textView.textContainerInset.top

        let glyphIndex = layoutManager.glyphIndex(for: location, in: container)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: container)
        guard glyphRect.contains(location) else { return nil }
        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }

    // MARK: - UIGestureRecognizerDelegate

    /// 只有触点落在图片或链接上时才接收触摸，否则放行给 textView 自身手势。
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let textView = boundTextView else { return false }
        let point = touch.location(in: textView)
        if DownBridge.imageAttachment(at: point, in: textView) != nil { return true }
        return link(at: point, in: textView) != nil
    }

    /// 与 textView 内置手势并存，避免互相取消。
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

