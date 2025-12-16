# PR: 支持从配置文件读取多个订阅源并分别展示订阅信息

## 功能说明

### 核心功能
**支持从配置文件读取多个订阅源并分别展示订阅信息**

### 主要改进

#### 1. 订阅源读取优先级
- 优先级1: UI手动设置的订阅URL
- 优先级2: 配置订阅设置
- 优先级3: **配置文件中的proxy-providers**（新增）

#### 2. 多订阅源展示
- **1个订阅源**：单行显示，占满宽度
- **2个订阅源**：并排显示，各占50%
- **3个订阅源**：并排显示，各占33%
- **4个及以上**：横向滚动展示，每个最小33%宽度，**支持鼠标拖拽滚动**

#### 3. 交互优化
- 鼠标拖拽横向滚动（4个及以上订阅源时）
- 鼠标滚轮横向滚动
- 切换配置/刷新时显示加载状态
- 隐藏滚动条，界面更简洁

### 技术更新要点

#### 后端API改进
- **统一返回格式**：`sub_info_get` API统一返回 `providers` 数组
- **支持多组订阅信息**：单个订阅源也包装为数组返回，消除格式不一致
- **支持proxy-providers**：从配置文件YAML中读取所有带订阅信息的provider

#### 前端实现
- **响应式布局**：Flex布局替代Grid，支持动态宽度和滚动
- **拖拽滚动**：纯JavaScript实现，无需外部依赖
- **状态管理**：统一处理数组格式数据，简化逻辑

### 使用场景示例

**配置文件示例**
```yaml
proxy-providers:
  Sub-01:
    url: "https://example.com/subscription1"
    subscription-userinfo: true

  Sub-02:
    url: "https://example.com/subscription2"
    subscription-userinfo: true

  Sub-03:
    url: "https://example.com/subscription3"
    subscription-userinfo: true
```

**展示效果**
- 自动读取所有订���源信息
- 分别显示各订阅源的流量和到期时间
- 超过3个时可拖拽查看

### 兼容性
- ✅ 向后兼容单个订阅源
- ✅ 无外部依赖
- ✅ 无新增翻译文案
- ✅ 不影响现有功能

---

## ��� Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
