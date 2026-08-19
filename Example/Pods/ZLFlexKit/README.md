# ZLFlexKit

`ZLFlexKit` 是一个基于 Auto Layout 的弹性布局库，核心能力是：
- 用 `StackView` + `FlexItem` 提供类似 Flexbox 的布局体验
- 同时支持 Swift 链式、Result Builder DSL、Objective-C 链式 block API
- 支持主轴分布、交叉轴对齐、单项 flex 权重、最小/最大间距、弹性空白
- 内置 `LayoutBox`（`view.box`）快速约束 DSL

> 本 README 内容基于当前仓库 `ZLFlexKit/Classes` 源码整理。

---

## 目录

- [能力概览](#能力概览)
- [安装](#安装)
- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [Swift 详细用法](#swift-详细用法)
- [Objective-C 详细用法](#objective-c-详细用法)
- [LayoutBox 用法（`view.box`）](#layoutbox-用法-viewbox)
- [API 速查](#api-速查)
- [注意事项（逐条）](#注意事项逐条)
- [常见问题](#常见问题)

---

## 能力概览

### 1) 主轴分布（`Justify`）

支持：
- `.fill`
- `.fillEqually`
- `.start`
- `.center`
- `.end`
- `.spaceBetween`
- `.spaceAround`
- `.spaceEvenly`

### 2) 交叉轴对齐（`FlexItemCrossAlign`）

支持：
- `.start`
- `.center`
- `.end`
- `.fill`

并且支持 item 级别 `alignSelf` 覆盖容器对齐策略。

### 3) item 弹性能力（`view.flex`）

支持：
- `flex(Int)` 权重分配剩余空间
- `isFlexibleSpace(true)` 插入弹性空白
- `spacing/minSpacing/maxSpacing` 三种间距控制
- `margin` 外边距
- `width/height/min/max/size/square` 尺寸约束

### 4) 构建方式

- Swift 链式 API
- Result Builder DSL（`StackView { ... }`）
- Objective-C 链式 block API

### 5) 补充能力

- `EdgeInsets` 轻量结构体
- `wrapScrollView()` 一键包裹滚动容器
- `LayoutBox` 约束 DSL（`view.box`）

---

## 安装

### CocoaPods

```ruby
pod 'ZLFlexKit'
```

### Swift Package Manager

在 SPM 中添加仓库后，引入 `ZLFlexKit` 产品。

> 说明：Podspec 与 SPM 的最低系统版本配置可能存在差异，最终以你工程实际集成为准。

---

## 快速开始

```swift
import UIKit
import ZLFlexKit

final class DemoVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let a = UILabel(); a.text = "A"; a.backgroundColor = .systemRed
        let b = UILabel(); b.text = "B"; b.backgroundColor = .systemBlue
        let c = UILabel(); c.text = "C"; c.backgroundColor = .systemGreen

        let stack = HStackView {
            a
            12
            b
            Spacer()
            c
        }
        .justify(.fill)
        .align(.center)
        .insets(.all(16))

        view.addSubview(stack)
        stack.box
            .top(120)
            .leading(16)
            .trailing(-16)
            .height(56)

        a.flex.flex(1)
        c.flex.flex(1)
    }
}
```

---

## 核心概念

### `StackView`

容器对象，负责统一布局策略：
- `axis`: 主轴方向（水平/垂直）
- `justifyContent`: 主轴分布
- `alignment`: 交叉轴对齐
- `insets`: 容器内边距
- `spacing`: 全局间距

### `FlexItem`（`view.flex`）

子视图对应的布局配置对象，负责单项策略：
- 间距：`spacing/minSpacing/maxSpacing`
- 弹性：`flex/isFlexibleSpace`
- 对齐：`alignSelf`
- 外边距：`margin`
- 尺寸：`width/height/min/max/size`

### `FlexManager`

内部约束生成器，根据容器与 item 状态生成并激活约束。

### `LayoutBox`（`view.box`）

通用约束 DSL，用于非 StackView 场景或辅助布局。

---

## Swift 详细用法

### 1. 创建容器

```swift
let s1 = StackView {}
let s2 = StackView.horizontal()
let s3 = StackView.vertical()
let s4 = HStackView {}
let s5 = VStackView {}
```

### 2. 容器链式配置

```swift
stack
    .axis(.horizontal)
    .justify(.spaceBetween)
    .align(.center)
    .spacing(10)
    .insets(.init(t: 8, s: 12, b: 8, e: 12))
```

### 3. 添加子视图

#### 3.1 普通添加

```swift
stack.addArrangedSubview(label)
stack.insertArrangedSubview(button, at: 0)
stack.removeArrangedSubview(label)
```

#### 3.2 链式添加

```swift
stack
    .addView(label)
    .addView(if: isVIP, badge)
    .addView(make: { (_: StackView) in UIImageView() })
```

#### 3.3 DSL 添加（推荐）

```swift
let stack = StackView {
    UILabel()
    8
    UIButton(type: .system)
    Spacer(min: 6)
    UIView()
}
```

### 4. 主轴分布（justify）

```swift
stack.justify(.fill)
stack.justify(.fillEqually)
stack.justify(.start)
stack.justify(.center)
stack.justify(.end)
stack.justify(.spaceBetween)
stack.justify(.spaceAround)
stack.justify(.spaceEvenly)
```

### 5. 交叉轴对齐（align）

```swift
stack.align(.start)
stack.align(.center)
stack.align(.end)
stack.align(.fill)
```

item 覆盖容器：

```swift
avatar.flex.align(.start)
```

### 6. 间距体系

#### 6.1 全局间距

```swift
stack.spacing(12)
```

#### 6.2 指定某个 view 后面的间距

```swift
stack.setCustomSpacing(20, after: viewA)
stack.setCustomMinSpacing(8, after: viewA)
stack.setCustomMaxSpacing(36, after: viewA)
```

#### 6.3 插入间距（链式）

```swift
stack
    .addView(viewA)
    .insertSpacing(10)
    .addView(viewB)
    .insertSpacing(min: 6)
    .addView(viewC)
    .insertSpacing(max: 30)
```

### 7. flex 与弹性空白

```swift
left.flex.flex(1)
center.flex.flex(2)
right.flex.flex(1)
```

弹性空白：

```swift
spacerHolder.flex.isFlexibleSpace(true)
```

### 8. margin 与 insets

```swift
stack.insets(.all(12))

nameLabel.flex.margin(.init(t: 4, s: 8, b: 4, e: 8))
```

### 9. item 尺寸

```swift
avatar.flex.size(w: 40, h: 40)
titleLabel.flex.minWidth(80)
tagLabel.flex.maxWidth(140)
```

### 10. 动态更新

```swift
itemView.isHidden.toggle()    // 自动触发布局刷新
stack.setFlex(3, for: itemView)
stack.setAlignment(.end, for: itemView)
stack.setMargin(.init(top: 0, leading: 12, bottom: 0, trailing: 0), for: itemView)
```

### 11. 包裹滚动容器

```swift
let scroll = stack.wrapScrollView()
view.addSubview(scroll)
scroll.box.edgesZero()
```

---

## Objective-C 详细用法

`StackView` 暴露了 ObjC 链式 block 属性，示例：

```objc
ZLStackView *stack = [ZLStackView new];
stack
.setAxis(ZLStackViewAxisHorizontal)
.setJustify(ZLJustifyFill)
.setAlign(ZLFlexItemCrossAlignCenter)
.setInsets(8, 12, 8, 12)
.setSpacing(10)
.addView(label)
.insertFlexibleSpacing(YES)
.addView(button);

label.zl_flex
.flex(1)
.minSpacing(8)
.maxSpacing(20)
.height(36);
```

也支持一些便捷属性（如 `justifyFill` / `alignCenter` 等）。

---

## LayoutBox 用法（`view.box`）

`LayoutBox` 是 ZLFlexKit 内置的通用约束 DSL，用于 **非 StackView 场景** 或作为 StackView 布局的辅助工具。它是对 `NSLayoutAnchor` 的轻量封装，具备以下核心特性：

- **链式调用**：每个方法都返回 `Self`，可无限串联
- **懒激活**：约束不会立即 active，会在下一次 `updateConstraints` 阶段统一激活（内部通过 swizzle 实现）
- **自动 TAMR**：调用任何布局方法后自动把 `translatesAutoresizingMaskIntoConstraints = false`
- **NumberConvertible**：所有数值参数支持 `Int / Int8~64 / UInt / Float / Double / CGFloat`，无需手动转换
- **约束模式切换**：支持 `add / update / remake / remove / clear` 五种约束操作模式
- **Swift 与 ObjC 双端**：Swift 用 `view.box`，ObjC 用 `view.zl_layout`

### 1. 入口

| 语言 | 属性名 | 类型 |
|------|--------|------|
| Swift | `view.box` | `LayoutBox` |
| Objective-C | `view.zl_layout` | `ZLLayout *`（类名保留 ObjC 别名） |

```swift
// Swift
let box = someView.box
```

```objc
// Objective-C
ZLLayout *box = someView.zl_layout;
```

### 2. 位置约束（父视图相对）

不带 `To` 后缀的方法，默认相对 `superview` 对应锚点。

```swift
view.box
    .top(20)            // 距父视图顶部 20
    .leading(16)        // 距父视图左边 16
    .trailing(-16)      // ⚠️ 相对父视图 trailing，常用负值内缩
    .bottom(-20)        // ⚠️ 相对父视图 bottom，常用负值内缩
```

> **重要**：`bottom` / `trailing` 使用 `constant` 原始语义，正值向外扩、负值向内缩，与 SnapKit 的自动取反不同，请注意符号约定。

### 3. 相对任意 anchor 约束（`xxxTo`）

```swift
labelA.box.leadingTo(labelB.trailingAnchor, offset: 8)
labelA.box.topTo(view.safeAreaLayoutGuide.topAnchor, offset: 12)
labelA.box.bottomTo(labelB.topAnchor, offset: -8)
```

### 4. 大小关系（`>= / <=`）

每个位置方法都有三个变体：

| 方法 | 关系 | 说明 |
|------|------|------|
| `topTo(anchor, offset:)` | `==` | 严格等于 |
| `topGreaterThanOrTo(anchor, offset:)` | `>=` | 至少 |
| `topLessThanOrTo(anchor, offset:)` | `<=` | 至多 |

`leading / trailing / top / bottom / centerX / centerY` 全部有 3 个变体。

```swift
// 保证 label 距父视图顶部至少 20
label.box.topGreaterThanOrTo(view.topAnchor, offset: 20)
// 限制 label 距底部最多 100
label.box.bottomLessThanOrTo(view.bottomAnchor, offset: -100)
```

### 5. 居中

```swift
view.box.center()                        // 相对父视图水平+垂直居中
view.box.centerX()                       // 相对父视图水平居中
view.box.centerY(10)                     // 垂直居中，向下偏移 10
view.box.centerOffset(x: 0, y: -20)      // 双向居中并偏移
view.box.centerXTo(header.centerXAnchor) // 相对任意 anchor 居中
```

### 6. 尺寸

```swift
view.box.width(100)          // 固定宽
view.box.height(44)          // 固定高
view.box.size(w: 100, h: 44) // 同时设宽高
view.box.square(48)          // 正方形

view.box.minWidth(80)        // 最小宽
view.box.maxWidth(200)       // 最大宽
view.box.minHeight(40)
view.box.maxHeight(120)

// 与其他 dimension 相等
labelA.box.widthTo(labelB.widthAnchor)
labelA.box.heightTo(view.heightAnchor)
```

### 7. 贴边（Edges）

```swift
view.box.edgesZero()                                   // 四边全 0，贴紧父视图
view.box.allEdges(16)                                  // 四边同值内缩 16
view.box.edges(top: 8, leading: 16, bottom: 8, trailing: 16)
// 注意：edges 内部自动为 bottom/trailing 取反，直接传正数即可
```

> **注意 edges 的语义特殊**：`edges(...)` 内部会对 bottom/trailing 自动取负，因此传入正数就是内缩值；而单独使用 `.bottom(_:)` / `.trailing(_:)` 时不会取反，需要自行传负值。

### 8. 视图层级

```swift
// 添加到父视图
child.box.addTo(parent)

// 添加到父视图并贴四边
child.box.addToFull(parent)

// 添加子视图
parent.box.addSubview(child)

// 添加子视图并立即布局
parent.box.addSubviewLayout(child) { box in
    box.leading(12).centerY().size(w: 24, h: 24)
}
```

`addSubviewLayout` 闭包中的 `box` 是 **子视图自己的** `LayoutBox`，可以直接链式布局。

### 9. 综合示例

```swift
let card = UIView()
let icon = UIImageView()
let title = UILabel()
let subtitle = UILabel()

card.box
    .addTo(view)
    .top(100).leading(16).trailing(-16)
    .height(80)

icon.box
    .addTo(card)
    .leading(12).centerY()
    .square(48)

title.box
    .addTo(card)
    .leadingTo(icon.trailingAnchor, offset: 12)
    .top(12).trailing(-12)

subtitle.box
    .addTo(card)
    .leadingTo(icon.trailingAnchor, offset: 12)
    .topTo(title.bottomAnchor, offset: 4)
    .trailing(-12).bottom(-12)
```

### 10. 约束管理：update / remake / remove / clear

`LayoutBox` 内部维护了每个 view 的约束存储，支持四种操作模式：

| 方法 | 说明 | 适用场景 |
|------|------|----------|
| 默认（无操作） | 新增并激活约束 | 首次布局 |
| `.update()` | 相同约束更新 constant / priority，新约束追加 | 修改已有约束数值 |
| `.remake()` | 先删除所有历史约束，再重新添加 | 大幅重构布局 |
| `.remove()` | 删除本次调用中传入的约束（按 firstItem/secondItem/attribute/relation 匹配） | 精细删除某组约束 |
| `.clear()` | 清空所有历史约束（同步生效，不需要 flush） | 完全重置 |

#### 10.1 update：修改现有约束数值

```swift
// 首次布局
view.box.top(20).leading(16).width(100).height(44)

// 一段时间后，把 top 从 20 改成 60、宽度从 100 改成 200
view.box
    .top(60)
    .width(200)
    .update()   // 匹配到相同 attribute 的约束，更新其 constant
```

#### 10.2 remake：整体重建

```swift
view.box
    .allEdges(20)   // 新的约束
    .remake()       // 先清空历史约束再激活这批
```

#### 10.3 remove：删除指定约束

```swift
view.box
    .top(20)        // 传入要匹配删除的约束特征
    .leading(16)
    .remove()
```

> `remove` 根据 `firstItem / secondItem / firstAttribute / secondAttribute / relation` 精确匹配，不依赖 constant。

#### 10.4 clear：全清

```swift
view.box.clear()    // 立即释放当前 view 上所有 LayoutBox 管理的约束
```

### 11. 立即生效（flush）

由于约束是 **懒激活** 的，某些场景（如 UITableViewCell 自适应高度计算）需要立即生效：

```swift
view.box.top(10).leading(16).width(100).height(44)
view.box.flush()   // 强制走一次 updateConstraintsIfNeeded()
```

`update() / remake() / remove()` 内部会自动调用 `flush()`，无需手动调用。

### 12. 支持任意数值类型（NumberConvertible）

```swift
view.box.top(10)          // Int
view.box.top(10.5)        // Double
view.box.top(Float(8))    // Float
view.box.top(CGFloat(12)) // CGFloat
view.box.top(UInt(4))     // UInt
```

### 13. ObjC 链式用法

所有 Swift 链式方法都通过 `@objc(...)` 计算属性暴露给 ObjC：

```objc
UIView *card = [UIView new];
card.zl_layout
    .addTo(self.view)
    .top(100)
    .leading(16)
    .trailing(-16)
    .height(120);

UIImageView *icon = [UIImageView new];
card.zl_layout.addSubviewLayout(icon, ^(ZLLayout *box) {
    box.leading(12).centerY(0).square(24);
});
```

⚠️ ObjC 侧数值参数是 `CGFloat`，需要 `centerY(0)` 显式传 0，不能省略。

### 14. LayoutBox 常见坑

1. **`bottom` / `trailing` 直接使用时不自动取反**，请传负值内缩。仅 `edges(top:leading:bottom:trailing:)` 会自动取反。
2. **`update()` 只更新 constant/priority**：如果第二次调用的约束参与的 anchor 不同（firstItem 或 attribute 不同），会作为新约束追加，不会覆盖原来的。
3. **`clear()` 会同步清除，不需要 flush**；其余模式（update/remake/remove）内部已经自动 flush。
4. **在 `viewDidLoad` 里链式布局是安全的**，约束会在 runloop 下一个 update pass 激活；如果需要立即读取 frame，请调用 `flush()` 后再 `layoutIfNeeded()`。
5. **不要与 `translatesAutoresizingMaskIntoConstraints = true` 混用**：LayoutBox 一旦被调用会强制关闭该属性。
6. **一个 view 只会有一份 LayoutBox**（通过 associated object 缓存），多次访问 `view.box` 返回同一实例，因此内部约束记录是累积的。
7. **`view.box.view` 弱引用**：`LayoutBox` 持有 view 是 `weak`，无循环引用风险；但也意味着 view 销毁后 `box` 不再可用。

---

## API 速查

### `StackView`

- 容器属性：`axis` `justifyContent` `alignment` `insets` `spacing`
- Swift 链式：`axis(_:)` `justify(_:)` `align(_:)` `insets(_:)` `spacing(_:)`
- 视图增删：`addArrangedSubview` `insertArrangedSubview` `removeArrangedSubview`
- DSL 相关：`addViews {}` `addView(if:)` `addView(make:)`
- 间距控制：`insertSpacing(_:)` `insertSpacing(min:)` `insertSpacing(max:)` `insertSpacing(flexible:)`
- item 定向设置：`setCustomSpacing` `setCustomMinSpacing` `setCustomMaxSpacing` `setFlex` `setAlignment` `setMargin`
- 滚动容器：`wrapScrollView()`

### `FlexItem`（`view.flex`）

- 间距：`spacing` `minSpacing` `maxSpacing`
- 弹性：`flex` `isFlexibleSpace`
- 对齐：`alignSelf` / `align(_:)`
- 外边距：`margin(_:)`
- 尺寸：`width/height/minWidth/maxWidth/minHeight/maxHeight/size/square`

### DSL

`StackView {}` 内可直接写：
- `UIView`
- `FlexItem`
- `Int/Float/Double`（表示间距）
- `Spacer()` / `Spacer(min:)` / `Spacer(max:)` / `Spacer(value)`
- `Optional<FlexType>`

### `LayoutBox`（`view.box` / ObjC: `view.zl_layout`）

- **位置（3 变体：`==` / `>=` / `<=`）**：
  - `top / topTo / topGreaterThanOrTo / topLessThanOrTo`
  - `leading / leadingTo / leadingGreaterThanOrTo / leadingLessThanOrTo`
  - `bottom / bottomTo / bottomGreaterThanOrTo / bottomLessThanOrTo`
  - `trailing / trailingTo / trailingGreaterThanOrTo / trailingLessThanOrTo`
  - `centerX / centerXTo / centerXGreaterThanOrTo / centerXLessThanOrTo`
  - `centerY / centerYTo / centerYGreaterThanOrTo / centerYLessThanOrTo`
- **居中辅助**：`center()` `centerOffset(x:y:)`
- **尺寸**：`width / height / minWidth / maxWidth / minHeight / maxHeight / size(w:h:) / square / widthTo / heightTo`
- **贴边**：`edges(top:leading:bottom:trailing:)` `allEdges(_:)` `edgesZero()`（bottom/trailing 自动取反）
- **层级**：`addTo(_:)` `addToFull(_:)` `addSubview(_:)` `addSubviewLayout(_:layout:)`
- **约束管理**：`update()` `remake()` `remove()` `clear()` `flush()`
- **数值类型**：任意 `NumberConvertible`（`Int/Int8~64/UInt/Float/Double/CGFloat`）

---

## 注意事项（逐条）

1. **`fill` 与 `fillEqually` 语义完全不同**
   - `fill` 更适合配合 `flex`。
   - `fillEqually` 会强制主轴等分。

2. **`spacing = -1` 在源码里有“回退到 stack.spacing”的语义**
   - item 未显式设置 spacing 时，会使用容器 spacing。

3. **`minSpacing/maxSpacing/spacing` 可能叠加影响**
   - 当三者同时设置时，最终效果受约束关系影响。

4. **`isFlexibleSpace` 不是“任意模式都明显”**
   - 常见有效场景是 `fill/fillEqually`。

5. **调用 `setCustomSpacing(_:after:)` 前，view 必须已经在当前 stack 中**
   - 否则不会生效。

6. **隐藏视图不会出现在 `arrangedViews`**
   - `arrangedViews` 返回的是非隐藏项。

7. **`LayoutBox` 的 `trailing/bottom` 建议按你的团队约定统一正负写法**
   - 常见写法是 `trailing(-16)`、`bottom(-12)`。

8. **`LayoutBox` 使用了 `updateConstraints` swizzle 来激活 pending 约束**
   - 若业务层有类似 swizzle，需评估相互影响。

9. **嵌套 `StackView/UIStackView` 时，内部会处理 `translatesAutoresizingMaskIntoConstraints`**
   - 这是为了降低冲突风险。

10. **`wrapScrollView()` 返回新对象**
    - 你需要把返回的 `ScrollView` 加入父视图。

11. **RTL 下 `ScrollView` 会对自身和 subviews 做 transform 调整**
    - 如果你项目也在做 transform，需要注意叠加效果。

12. **性能建议：批量改动集中触发一次布局**
    - 避免高频小改动反复重建约束。

---

## 常见问题

### Q1：设置了 `flex` 但看起来没按比例分配？

优先检查：
- `justify` 是否为 `.fill`
- item 是否隐藏
- 是否又加了固定宽/高把弹性空间锁死

### Q2：DSL 里为什么数字可以直接写？

因为 `Int/Float/Double` 已实现 `StackViewDSL`，数字被解释为 spacing。

### Q3：怎么把尾部元素顶到最右/最下？

在中间插入 `Spacer()`，或给中间 view 设置 `isFlexibleSpace(true)`。

### Q4：为什么改了 `margin/insets` 没有立刻可见？

通常是布局时机问题，确认 view 已在层级中，必要时调用 `layoutIfNeeded()`。

---

## License

MIT
