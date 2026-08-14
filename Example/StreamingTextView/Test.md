
```swift
public struct MarkdownToHTML: DownHTMLRenderable {
  
    public var markdownString: String

}
```


# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题

---

## 文本样式
*斜体* 或 _斜体_  
**粗体** 或 __粗体__  
***粗斜体*** 或 ___粗斜体___  
~~删除线~~  
==高亮==（部分编辑器支持）  
行内代码：`printf(\"Hello, world!\");`

---

## 列表

### 无序列表
- 苹果
- 香蕉
  - 子项：帝王蕉
  - 子项：巴西蕉
- 橙子

### 有序列表
1. 第一步
2. 第二步
   1. 子步骤 2.1
   2. 子步骤 2.2
3. 第三步

### 任务列表（GitHub 风格）
- [x] 已完成任务
- [ ] 未完成任务
- [ ] 待办事项

---

## 链接与图片
[点击跳转到百度](https://www.baidu.com)  
[带标题的链接](https://example.com \"悬停提示\")  
自动链接：<https://www.example.com>

图片（![alt 文本](https://gips1.baidu.com/it/u=3874647369,3220417986&fm=3028&app=3028&f=JPEG&fmt=auto?w=720&h=1280)）：
![示例图片](https://via.placeholder.com/150 \"可选标题\")

---

## 引用
> 这是一级引用。
> > 这是嵌套引用。
> > > 可以多层嵌套。
> 
> 引用中可以包含其他元素，比如 **粗体** 或 `代码`。

---

## Drivers
Appium supports app automation across a variety of platforms, like iOS, Android, macOS, Windows,and more. Each platform is supported by one or more "drivers", which know how toautomate thatparticular platform. You can find a full list of officially-supported and third-party drivers in

# Markdown 图文混排示例

欢迎使用 Markdown 图文混排演示。

这是一段普通文本。

![山川风景](https://img2.baidu.com/it/u=2838910375,3102156952&fm=253&app=138&f=JPEG?w=800&h=1067)

图片展示了一幅美丽的自然风景。

## 产品介绍

下面展示一款产品：

![产品图片](https://gips1.baidu.com/it/u=1658389554,617110073&fm=3028&app=3028&f=JPEG&fmt=auto?w=1280&h=960)

- 高清显示
- 超长续航
- 轻薄设计



