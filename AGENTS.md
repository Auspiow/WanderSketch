# HarmonyOS Project Rules

- 使用 ArkTS
- 使用 ArkUI 声明式 UI
- 使用 Stage Model 和 UIAbility
- 页面放在 `entry/src/main/ets/pages`
- 组件放在 `entry/src/main/ets/components`
- 数据类型放在 `entry/src/main/ets/model`
- 网络、存储、业务逻辑放在 `entry/src/main/ets/services`
- 优先使用 `@State`、`@Prop`、`@Link`、`@Observed`
- 不生成 Android、React Native、Flutter 代码
- UI 风格简洁，适合移动端