//
//  ImagePreviewer.swift
//  StreamingTextView_Example
//
//  独立的图片预览工具类：全屏遮罩展示大图，支持多图左右滑动浏览、
//  捏合缩放、双击放大、点击任意处关闭。通过单例即可在任意页面调用。
//

import UIKit

@MainActor
public class ImagePreviewer: NSObject, UIScrollViewDelegate {

    /// 共享单例。
    public static let shared = ImagePreviewer()

    private var overlay: UIView?
    /// 横向分页容器：每一页承载一张可缩放的图片。
    private var pagingScroll: UIScrollView?
    /// 每一页的缩放容器（与图片一一对应）。
    private var zoomScrolls: [UIScrollView] = []

    /// 预览单张图片（便捷方法）。
    public func present(_ image: UIImage, from sourceView: UIView) {
        present([image], startIndex: 0, from: sourceView, allowsSwipe: false)
    }

    /// 全屏预览一组图片，支持左右滑动浏览。
    /// - Parameters:
    ///   - images: 要预览的图片数组。
    ///   - startIndex: 初始展示的图片下标。
    ///   - sourceView: 用于定位所在 window 的视图（一般传当前控制器的 `view`）。
    ///   - allowsSwipe: 是否允许左右滑动切换图片。为 false 时只展示 `startIndex` 那一张。
    public func present(_ images: [UIImage],
                        startIndex: Int = 0,
                        from sourceView: UIView,
                        allowsSwipe: Bool = true) {
        guard overlay == nil, !images.isEmpty else { return }   // 已有预览 / 无图则忽略

        // 不允许滑动时，只保留起始那一张。
        let clampedStart = min(max(startIndex, 0), images.count - 1)
        let displayImages = allowsSwipe ? images : [images[clampedStart]]
        let startPage = allowsSwipe ? clampedStart : 0

        let host: UIView = sourceView.window ?? sourceView
        let bounds = host.bounds

        let overlay = UIView(frame: bounds)
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.9)
        overlay.alpha = 0
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 横向分页容器。
        let paging = UIScrollView(frame: bounds)
        paging.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        paging.isPagingEnabled = displayImages.count > 1
        paging.isScrollEnabled = displayImages.count > 1
        paging.showsHorizontalScrollIndicator = false
        paging.showsVerticalScrollIndicator = false
        paging.contentSize = CGSize(width: bounds.width * CGFloat(displayImages.count), height: bounds.height)
        overlay.addSubview(paging)

        // 单击关闭。
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        overlay.addGestureRecognizer(singleTap)

        zoomScrolls.removeAll()
        for (i, image) in displayImages.enumerated() {
            let pageFrame = CGRect(x: bounds.width * CGFloat(i), y: 0, width: bounds.width, height: bounds.height)

            // 每页一个可缩放容器。
            let zoom = UIScrollView(frame: pageFrame)
            zoom.delegate = self
            zoom.minimumZoomScale = 1.0
            zoom.maximumZoomScale = 3.0
            zoom.showsHorizontalScrollIndicator = false
            zoom.showsVerticalScrollIndicator = false

            let iv = UIImageView(image: image)
            iv.contentMode = .scaleAspectFit
            iv.frame = zoom.bounds
            iv.isUserInteractionEnabled = true
            zoom.addSubview(iv)

            // 双击缩放。
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            iv.addGestureRecognizer(doubleTap)
            singleTap.require(toFail: doubleTap)

            paging.addSubview(zoom)
            zoomScrolls.append(zoom)
        }

        host.addSubview(overlay)
        self.overlay = overlay
        self.pagingScroll = paging

        // 定位到起始页。
        paging.setContentOffset(CGPoint(x: bounds.width * CGFloat(startPage), y: 0), animated: false)

        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
    }

    @objc private func dismiss() {
        guard let overlay = overlay else { return }
        UIView.animate(withDuration: 0.25, animations: {
            overlay.alpha = 0
        }, completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.overlay = nil
            self?.pagingScroll = nil
            self?.zoomScrolls.removeAll()
        })
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // 找到当前页对应的缩放容器（gesture 所在 imageView 的父视图）。
        guard let zoom = gesture.view?.superview as? UIScrollView else { return }
        if zoom.zoomScale > zoom.minimumZoomScale {
            zoom.setZoomScale(zoom.minimumZoomScale, animated: true)
        } else {
            zoom.setZoomScale(zoom.maximumZoomScale, animated: true)
        }
    }

    // MARK: - UIScrollViewDelegate

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // 只有「缩放容器」参与缩放，返回它内部的 imageView。
        return scrollView.subviews.first { $0 is UIImageView }
    }
}

