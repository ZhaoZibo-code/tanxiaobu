# 碳足迹：M00 最小原生工程

OpenHarmony Public SDK 5.0.0.71 / API 12，ArkTS + ArkUI，Stage。基于官方 API 12 AppStartup 样例裁剪，只有环境验证页、按钮和可见计数；尚无业务模块。

从本目录执行：

```bash
source scripts/env.sh
ohpm install
./hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

DevEco Studio 26.0.0.851 已安装，工程已同步，IDE 与命令行原生构建成功。本轮 CLI 构建的 unsigned 主/测试 HAP 已在独立 HarmonyOS7.0.0.107/API26 模拟器默认配置下安装、启动并通过真实按钮测试；构建目标仍是 OpenHarmony/API12。收尾主包被再次打包，新 SHA 版本尚未由本对话重新安装运行，详见 M00 报告第13.7节。赛事镜像认可、真机与发布签名仍未验证，不宣布 G0 总验收通过。完整命令、测试目录、产物校验值、签名边界及保留实例启动步骤在 `../docs/environment/BUILD_AND_RUN.md`；环境与来源在同目录 `ENVIRONMENT.md`、`DOWNLOADS.md`。

源码、配置、测试与图标的上游来源及裁剪说明见 DOWNLOADS.md。保留 `LICENSE`（Apache-2.0）及上游版权头。`local.properties` 为本机 SDK 路径，不应共享提交；签名材料不要写入公共配置。M01 从当前页面和真实 SDK 开始，M10 后续维护共享构建与入口。

已通过 IDE 官方迁移助手将 modelVersion 更新为 5.0.0；使用 IDE 内置 Hvigor 6.26.8。`hvigorw` 是本项目的薄封装，调用已安装 IDE 工具；编译使用 Node 18，`scripts/ohpm` 使用 IDE 内置 Node 24 运行新版 ohpm。完整依据与验证边界见环境文档。
