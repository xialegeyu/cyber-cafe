# Virtual Cafe MVP

这是一个静态 Web MVP，用来验证一件事：

> 能否让一个默认人物真正坐进咖啡馆场景，而不是贴在背景图上。

当前版本加入了第二个座位选项：同一个咖啡馆背景里的左后侧靠窗桌位。

## 当前实现

- 页面：`index.html`
- 样式：`styles.css`
- 交互：`script.js`
- 分层资产目录：`assets/cafe/`

## 分层结构

页面使用明确的 2.5D 层级：

```html
<div class="cafe-scene">
  <img class="layer room-bg" />
  <img class="layer seat-a-layer chair-layer" />
  <img class="layer seat-b-layer chair-layer" />
  <img class="layer seat-b-layer desk-layer" />
  <img class="layer seat-a-layer avatar-layer" />
  <img class="layer seat-b-layer avatar-layer" />
  <img class="layer seat-a-layer table-front-layer" />
  <div class="layer light-overlay"></div>
</div>
```

对应深度关系：

```css
.room-bg { z-index: 1; }
.chair-layer { z-index: 2; }
.desk-layer { z-index: 2; }
.avatar-layer { z-index: 3; }
.table-front-layer { z-index: 4; }
.light-overlay { z-index: 5; }
```

Seat B 是左后侧视角，层级和 Seat A 不同：

```css
.seat-b-layer.chair-layer { z-index: 2; }
.seat-b-layer.desk-layer { z-index: 2; }
.seat-b-layer.avatar-layer { z-index: 4; }
```

也就是说 Seat B 的人物层在桌子和椅子上方，方便桌子和椅子被人物自然遮挡。

Seat B 的职责拆分：

- `seat-b-avatar-seated.png`：人物 + 电脑，不包含椅子、桌子
- `seat-b-chair-layer.png`：只包含椅子/凳子
- `seat-b-desk-layer.png`：只包含连续木桌和少量桌面小物，不包含电脑，也不包含大块白色纸面

关键遮挡关系是：

```text
chair / back furniture
-> seated avatar
-> table front occlusion layer
```

`table-front-layer.png` 会覆盖人物的腰部、腿部和部分电脑下缘，因此人物看起来是在桌子后面坐下。

Seat B 使用同一个 `room-bg.png`，不再使用独立房间背景。对应新增资产：

- `seat-b-chair-layer.png`
- `seat-b-desk-layer.png`
- `seat-b-avatar-seated.png`

## MVP 范围

已实现：

- 一个 HTML 页面
- 一个共享咖啡馆背景
- Seat A：原来的正面圆桌
- Seat B：左后侧靠窗桌位
- 两套椅子/凳子/桌子层
- 两张桌子
- 一个默认坐姿人物
- `Seat A` 按钮：人物坐到正面圆桌
- `Seat B` 按钮：人物坐到左后侧靠窗桌位
- `Stand up` 按钮：隐藏人物

未实现：

- 多人
- 登录
- 聊天
- 声音
- 换装
- 多座位
- 数据库
- 部署
- 大地图
- 复杂游戏引擎逻辑

## 验收重点

- 椅子层在人物后面
- 人物层独立，不合并进背景
- 桌子前景层独立，不合并进背景
- 桌子前景层遮住人物的一部分
- Seat B 是同一个咖啡馆背景里的左后侧座位，不是第二张独立房间图
- Seat B 的人物资产包含电脑，但不包含椅子
- Seat B 使用独立椅子资产，便于后续替换椅子样式
- Seat B 使用独立桌子资产，桌面应是一张连续木桌，不应像两张桌子叠放
- Seat B 的人物层在桌子和椅子之上，桌子/椅子会被人物遮挡
- 点击 `Sit down` 后人物出现
- 点击 `Stand up` 后人物消失
- HTML/CSS 能清楚看到层结构和 z-index 顺序
