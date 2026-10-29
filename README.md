# 碳小步

> 记录每一小步，汇成绿色改变。

基于 **OpenHarmony** 的个人低碳生活记录与成长应用（ArkTS + ArkUI，Stage 模型）。
面向学生与个人用户，把宿舍节电、按需取餐、旧物再利用这类零散的绿色行动，变成有记录、有依据、有反馈的日常习惯。

本仓库包含原生应用源码、核算规则、构建说明、排放因子调研资料与演示材料。

---

## 它解决什么问题

| 用户的真实问题 | 碳小步的回应 |
| --- | --- |
| 做了绿色行动，但没留下记录 | 按具体行为录入日期、数量与说明，几秒完成一次记录 |
| 看见减排数字，却不知道从何而来 | 每条记录都能查看公式、因子来源、假设与估算说明 |
| 只记录一次，很难坚持 | 每日任务、积分流水、续火花与虚拟奖励 |
| 记录越来越多，看不出变化 | 时间趋势、分类统计与历史查询 |
| 网络不稳定，担心数据不可用 | 本地规则、本地账本、离线科普，核心体验不依赖联网 |

## 六项核心功能

1. **低碳行为记录与核算** — 覆盖出行、节水节电、旧物循环、光盘行动四类生活主题，选择规则后填写数量即可得到参考估算，并查看计算依据。
2. **历史记录与趋势回顾** — 记录列表、按分类与时间维度统计，支持更正与撤销。
3. **每日任务、积分与虚拟奖励** — 任务进度驱动积分流水，积分可兑换虚拟成就，所有奖励均为应用内虚拟属性。
4. **双碳科普** — 内置离线文章与本地插画，不联网也能阅读。
5. **低碳建议** — 依据用户近七天的真实记录生成可执行建议。
6. **本地数据管理** — JSON 备份导出与校验恢复、CSV 报表导出，全部在设备本地完成。

## 技术栈

- **平台**：OpenHarmony Public SDK 5.0.0.71 / API 12，Stage 模型
- **语言与框架**：ArkTS + ArkUI（声明式 UI）
- **存储**：关系型数据库（RDB），跨记录 / 任务 / 积分 / 兑换的写入走统一事务
- **构建**：DevEco Studio 26.0.0.851 + Hvigor 6.26.8
- **测试**：Hypium（`@ohos/hypium` 1.0.15），含本地单元测试与设备侧隔离测试

## 目录结构

```
.
├── app/                        原生应用工程（DevEco 可直接打开）
│   ├── entry/src/main/ets/     ArkTS 源码
│   │   ├── common/             公共契约、设计系统、路由
│   │   ├── features/           业务特性：records / statistics / engagement /
│   │   │                       knowledge / advice / family / dataTransfer / ai …
│   │   └── entryability/       应用入口
│   ├── entry/src/test/         本地单元测试
│   ├── entry/src/ohosTest/     设备侧隔离测试
│   └── scripts/                env.sh / ohpm / hdc 等本机工具封装
├── docs/
│   ├── environment/            环境搭建与构建运行说明、构建日志
│   └── research/               排放因子与 UI 调研资料
├── showcase/                   离线演示网页与五分钟演讲稿
└── 项目需求分析与功能说明书.md
```

## 构建与运行

前置：已安装 DevEco Studio 与 OpenHarmony SDK（API 12）。首次构建前在 `app/local.properties` 写入本机 SDK 路径：

```properties
sdk.dir=/path/to/OpenHarmony/Sdk
```

```bash
cd app
source scripts/env.sh
ohpm install
./hvigorw --mode module -p product=default -p module=entry@default \
  -p buildMode=debug assembleHap --no-daemon
```

产物位于 `app/entry/build/default/outputs/default/entry-default-unsigned.hap`。该 HAP 未签名，可在模拟器上直接安装；真机需先配置签名后再安装：

```bash
hdc install -r entry-default-unsigned.hap
```

详细的 SDK 版本、环境变量、模拟器配置与验证边界见 [`docs/environment/BUILD_AND_RUN.md`](docs/environment/BUILD_AND_RUN.md)。

## 文档

| 想了解 | 看这里 |
| --- | --- |
| 产品定位与完整功能说明 | [`项目需求分析与功能说明书.md`](项目需求分析与功能说明书.md) |
| 构建、签名与设备验证 | [`docs/environment/BUILD_AND_RUN.md`](docs/environment/BUILD_AND_RUN.md) |
| 环境与依赖来源 | [`docs/environment/ENVIRONMENT.md`](docs/environment/ENVIRONMENT.md) |
| 排放因子调研资料 | [`docs/research/factors/`](docs/research/factors/) |
| 五分钟作品演示 | [`showcase/carbon-footprint/`](showcase/carbon-footprint/) |

## 关于结果的诚实说明

- 应用给出的是**参考估算**，基于公开排放因子与明示假设，**不是实测值，也不是经核证减排量**。
- 积分与奖励均为应用内**虚拟属性**，不具备任何货币价值或兑换承诺。
- 核心记录与科普功能可完全离线使用；联网能力仅用于可选增强，不影响主流程。
- 家庭账本的成员筛选与任务接力目前为示例数据，多设备同步尚未实现。

## 许可

`app/` 下部分工程骨架与图标源自 OpenHarmony 官方样例，遵循 Apache License 2.0，原始版权头保留于对应文件，许可证全文见 [`app/LICENSE`](app/LICENSE)。
