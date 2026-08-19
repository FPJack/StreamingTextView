//
//  MarkdownTableParser.swift
//  StreamingTextView_Example
//
//  Created by admin on 2026/8/19.
//  Copyright © 2026 CocoaPods. All rights reserved.
//

import Foundation

final class MarkdownTableParser {

    /// 将 Markdown 字符串按照表格块切割
    /// - Parameter markdown: 原始 Markdown
    /// - Returns: 普通文本和表格字符串交替数组
    static func splitMarkdownTables(_ markdown: String) -> [String] {

        // Markdown Table:
        // 第一行必须有 |
        // 第二行必须是 ---- 分割线
        // 后续任意 | 行
        let pattern = #"(?ms)(?:^[ \t]*\|.*\|[ \t]*\n)(?:^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(?:\|[ \t]*:?-{3,}:?[ \t]*)+\|?[ \t]*\n)(?:^[ \t]*\|.*\|[ \t]*(?:\n|$))*"#


        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.anchorsMatchLines]
        ) else {
            return [markdown]
        }


        let nsString = markdown as NSString

        let matches = regex.matches(
            in: markdown,
            range: NSRange(
                location: 0,
                length: nsString.length
            )
        )

        if matches.isEmpty {
            return [markdown]
        }


        var result: [String] = []

        var lastIndex = 0


        for match in matches {

            let range = match.range

            // 表格之前的普通文本
            if range.location > lastIndex {

                let textRange = NSRange(
                    location: lastIndex,
                    length: range.location - lastIndex
                )

                let text = nsString.substring(
                    with: textRange
                )

                if !text.isEmpty {
                    result.append(text)
                }
            }


            // 表格内容
            let table = nsString.substring(
                with: range
            )

            result.append(table)


            lastIndex = range.location + range.length
        }


        // 最后的普通文本
        if lastIndex < nsString.length {

            let range = NSRange(
                location: lastIndex,
                length: nsString.length - lastIndex
            )

            let tail = nsString.substring(
                with: range
            )

            if !tail.isEmpty {
                result.append(tail)
            }
        }


        return result
    }
}

func prientMarkdown() {
    if let path = Bundle.main.path(forResource: "Test", ofType: "md"),
       let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
       let arr = MarkdownTableParser.splitMarkdownTables(content)
        print("Markdown split into \(arr) parts:")
    }
    
}

