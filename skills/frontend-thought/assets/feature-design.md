---
task_id: {feature-slug}
feature: {FeatureName}
status: pending
depends_on: []
description: "{一句话描述}"
---

# {FeatureName} Feature 设计

## 页面与路由

| 页面 | 路由 | 描述 |
|------|------|------|

## Feature Slices

<!-- 每个 Feature slice 的范围和用途 -->

## Entity Slices

<!-- 每个 Entity slice（本 Feature 依赖的业务实体） -->

## Shared 层需求

<!-- 需要新增的公共基础设施：API 客户端、公共组件、类型等 -->

## 组件设计

### {FeatureSlice}/ui/{ComponentName}

#### Props 接口

```typescript
interface {ComponentName}Props {
  // ...
}
```

#### 交互行为

<!-- 用户操作 → 状态变化 → 视觉反馈 -->

#### 数据来源

<!-- 哪个 hook 提供数据 -->

## 状态管理

### 服务端状态（React Query hooks）

| Hook | 位置 | queryKey | 说明 |
|------|------|----------|------|

### 客户端状态（如有）

<!-- zustand store 设计 -->

## API 设计

### API 函数签名表

| 函数名 | 位置 | 入参 | 返回类型 | 对应后端接口 |
|--------|------|------|----------|-------------|

## 文件清单

| # | FSD 层 | 文件路径 | 导出内容 | 依赖 |
|---|--------|----------|----------|------|
