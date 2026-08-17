//
//  TextViewGestureManager.swift
//  StreamingTextView_Example
//
//  统一管理 UITextView 的手势交互：图片点击 + 链接点击。
//  内部负责添加手势、判断命中类型，并通过 block 把事件回调给外部；
//  只有点到「图片」或「链接」时才接收触摸，否则放行给 UITextView 处理
//  自身的文本选择等手势，不会拦截原生交互。
//

import UIKit

@MainActor
public class TextViewGestureManager: NSObject, UIGestureRecognizerDelegate {

    /// 点击到图片附件时回调。
    /// - 参数 1：被点击的图片附件。
    /// - 参数 2：当前 textView 里按顺序排列的全部图片附件（用于多图左右滑动浏览）。
    public var onImageTapped: ((ImageTextAttachment, [ImageTextAttachment]) -> Void)?

    /// 点击到链接时回调（参数为链接 URL）。
    public var onLinkTapped: ((URL) -> Void)?

    /// 被管理的 textView（弱引用，避免循环持有）。
    private weak var textView: UITextView?

    /// 绑定到指定 textView，并自动添加点击手势。
    /// - Parameter textView: 承载富文本（图片附件 / 链接）的 UITextView。
    public init(textView: UITextView) {
        self.textView = textView
        super.init()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        textView.addGestureRecognizer(tap)
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = textView else { return }
        let point = gesture.location(in: textView)

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
        guard let textView = textView else { return false }
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
