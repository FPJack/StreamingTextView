//
//  MarkdownTableParser.swift
//  StreamingTextView_Example
//
//  Created by admin on 2026/8/19.
//  Copyright © 2026 CocoaPods. All rights reserved.
//

import Foundation
import StreamingTextView

/// 一段 Markdown 的解析结果：要么是普通文本，要么是可直接喂给 `GridTableView` 的表格数据。
/// - `text`：非表格内容，原样返回。
/// - `table`：表格内容，已转成 `GridTableView` 需要的 `[[GridCellModel]]`
///   （第 0 行为表头，其余为数据行；分隔行 `| --- |` 已被跳过）。
@available(iOS 13.0, *)
enum MarkdownSegment {
    case text(String)
    case table([[GridCellModel]])
}

enum MarkdownTableParser {

    /// 匹配 GFM 竖线表格的正则。
    ///
    /// 结构（三部分，逐行匹配，`.anchorsMatchLines` 让 `^` 贴住每一行行首）：
    ///   1) 表头行：`^[ \t]*\|.*\|[ \t]*\r?\n`
    ///      —— 以可选空白 + `|` 开头、含 `|` 结尾的一整行。
    ///   2) 分隔行：`^[ \t]*\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*\r?\n`
    ///      —— 每个单元格形如 `:?-+:?`（`-+` 允许 1 个及以上短横，比 `-{3,}` 更宽松），
    ///         首尾 `|` 均可选，`(?:...)*` 允许 1 列或多列。
    ///   3) 数据行：`(?:^[ \t]*\|.*\|[ \t]*\r?\n?)*`
    ///      —— 0 行或多行「含 `|` 的行」。遇到空行（无 `|`）自动结束，
    ///         因此两张以空行分隔的表格会被分别匹配成两段。
    ///
    /// 注意：横向空白只用 `[ \t]`（不用 `\s`），避免 `\s` 把换行也吃掉、
    /// 导致贪婪 `.*` 跨行错配。
    private static let tablePattern = #"(?:^[ \t]*\|.*\|[ \t]*\r?\n)(?:^[ \t]*\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*\r?\n)(?:^[ \t]*\|.*\|[ \t]*\r?\n?)*"#

    /// 把 markdown 拆分为「普通文本段」与「表格段」交替的数组，保持原始顺序。
    /// - Returns: 段落数组；每个表格段是完整的表格文本，其余为普通文本。
    static func splitMarkdownTables(_ markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: tablePattern,
            options: [.anchorsMatchLines]
        ) else {
            return [markdown]
        }

        let nsString = markdown as NSString
        let matches = regex.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsString.length)
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
                let text = nsString.substring(with: textRange)
                if !text.isEmpty {
                    result.append(text)
                }
            }

            // 表格内容
            let table = nsString.substring(with: range)
            result.append(table)

            lastIndex = range.location + range.length
        }

        // 最后的普通文本
        if lastIndex < nsString.length {
            let range = NSRange(
                location: lastIndex,
                length: nsString.length - lastIndex
            )
            let tail = nsString.substring(with: range)
            if !tail.isEmpty {
                result.append(tail)
            }
        }

        return result
    }

    // MARK: - 段落转换（文本 / 表格）

    /// 传入 `splitMarkdownTables(_:)` 拆分出的字符串数组，逐段判断：
    /// - 不是表格：原样以 `.text` 返回；
    /// - 是表格：解析成 `GridTableView` 需要的 `[[GridCellModel]]`，以 `.table` 返回。
    /// - Parameter segments: 已拆分的 Markdown 段落数组。
    /// - Returns: 与输入顺序一致的 `MarkdownSegment` 数组。
    @available(iOS 13.0, *)
    static func convertSegments(_ segments: [String]) -> [MarkdownSegment] {
        segments.map { segment in
            if isTable(segment) {
                return .table(gridRows(from: segment))
            } else {
                return .text(segment)
            }
        }
    }

    /// 便捷入口：直接把整篇 Markdown 拆分并转换为 `MarkdownSegment` 数组。
    @available(iOS 13.0, *)
    static func parseSegments(_ markdown: String) -> [MarkdownSegment] {
        convertSegments(splitMarkdownTables(markdown))
    }

    // MARK: - 表格识别 / 解析

    /// 判断一段文本是否为表格：首个非空行含 `|`，且第二个非空行是分隔行（`| --- |`）。
    static func isTable(_ segment: String) -> Bool {
        let lines = segment
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return false }
        return lines[0].contains("|") && isSeparatorLine(lines[1])
    }

    /// 把表格文本解析成 `GridTableView` 需要的单元格模型二维数组。
    @available(iOS 13.0, *)
    static func gridRows(from tableString: String) -> [[GridCellModel]] {
        tableRows(from: tableString).map { row in
            row.map { GridCellModel(text: $0) }
        }
    }

    /// 把表格文本解析成二维字符串（第 0 行表头，其余为数据行，列数对齐到表头，跳过分隔行）。
    static func tableRows(from tableString: String) -> [[String]] {
        let lines = tableString
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0.contains("|") }
        guard lines.count >= 2 else { return [] }

        let header = splitCells(lines[0])
        var rows: [[String]] = [header]
        let colCount = header.count
        // lines[1] 是分隔行，跳过；从 lines[2] 起是数据行。
        for k in 2..<lines.count {
            var cells = splitCells(lines[k])
            if cells.count < colCount {
                cells += Array(repeating: "", count: colCount - cells.count)
            } else if cells.count > colCount {
                cells = Array(cells.prefix(colCount))
            }
            rows.append(cells)
        }
        return rows
    }

    /// 是否为分隔行：去首尾 `|` 后每个单元格都形如 `:?-+:?`。
    static func isSeparatorLine(_ line: String) -> Bool {
        let cells = splitCells(line)
        guard !cells.isEmpty else { return false }
        for c in cells {
            let t = c.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return false }
            if t.range(of: "^:?-+:?$", options: .regularExpression) == nil { return false }
        }
        return true
    }

    /// 把一行拆成单元格：去掉首尾 `|` 后按 `|` 分割并 trim。
    static func splitCells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

