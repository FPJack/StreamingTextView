//
//  ChunkViewController.swift
//  StreamingTextView_Example
//
//  Created by admin on 2026/8/19.
//  Copyright © 2026 CocoaPods. All rights reserved.
//

import UIKit
import ZLFlexKit
import StreamingTextView
class ChunkViewController: UIViewController {
    private func readmeMarkdown() -> String {
        if let path = Bundle.main.path(forResource: "Test", ofType: "md"),
           let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
            return content
        }
        
        return "# Test.md 未找到"
    }
    var textView: StreamingTextView = {
        let v = StreamingTextView()
        
        return v
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(textView)
        textView.maxTextWidth = view.bounds.width - 20
        textView.box.leading(10).top(10)
        textView.charactersPerFrame = 5
        let attr = DownBridge.attributedString(fromMarkdown: readmeMarkdown(), options: MarkdownRenderOptions())
        textView.startStreamingAttributedText(attr!)
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
