//
//  ScrollView.swift
//  FlexKit
//
//  Created by admin on 2026/6/5.
//

import UIKit
@objc(ZLScrollView)
public class ScrollView: UIScrollView {

    public override func layoutSubviews() {

           super.layoutSubviews()

           let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft

           let transform = isRTL ? CGAffineTransform(scaleX: -1, y: 1) : .identity

           if self.transform != transform {

               self.transform = transform

           }

           subviews.forEach { view in

               let viewTransform = isRTL ? CGAffineTransform(scaleX: -1, y: 1) : .identity

               if view.transform != viewTransform {

                   view.transform = viewTransform

               }

           }

       }

}
