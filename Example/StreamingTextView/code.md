
```swift
public struct MarkdownToHTML: DownHTMLRenderable {
  
    public var markdownString: String

}
    /// 极简「语法着色」：关键字蓝、注释绿、字符串橙。
    private static func colorize(_ attr: NSMutableAttributedString) {
        let text = attr.string
        let ns = text as NSString

        // 注释：以 // 开头到行尾。
        if let r = text.range(of: "//.*", options: .regularExpression) {
            attr.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: NSRange(r, in: text))
            return
        }
        let keywords = ["import", "struct", "public", "var", "let", "func", "return"]
        for kw in keywords {
            var searchRange = NSRange(location: 0, length: ns.length)
            while true {
                let found = ns.range(of: kw, options: [], range: searchRange)
                if found.location == NSNotFound { break }
                // 词边界校验（前后都不是字母）。
                let beforeIsLetter: Bool = {
                    guard found.location > 0 else { return false }
                    let c = ns.substring(with: NSRange(location: found.location - 1, length: 1))
                    return c.rangeOfCharacter(from: .letters) != nil
                }()
                let afterLoc = found.location + found.length
                let afterIsLetter: Bool = {
                    guard afterLoc < ns.length else { return false }
                    let c = ns.substring(with: NSRange(location: afterLoc, length: 1))
                    return c.rangeOfCharacter(from: .letters) != nil
                }()
                if !beforeIsLetter && !afterIsLetter {
                    attr.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: found)
                }
                searchRange = NSRange(location: afterLoc, length: ns.length - afterLoc)
            }
        }
        // 字符串字面量。
        if let r = text.range(of: "\"[^\"]*\"", options: .regularExpression) {
            attr.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: NSRange(r, in: text))
        }
    }
}

```
