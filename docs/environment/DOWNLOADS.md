# M00 官方来源与完整性记录

实查日期：2026-10-27（Asia/Shanghai）。以下下载已完成并比对 SHA-256 后解压。安装包和临时解压目录在交付前清理，已安装 SDK/工具保留。

| 内容 | 官方来源 | SHA-256 |
| --- | --- | --- |
| OpenHarmony Public SDK 5.0.0.71，Mac ARM，API 12 | [SDK 包](https://repo.huaweicloud.com/openharmony/os/5.0.0-Release/L2-SDK-MAC-M1-PUBLIC.tar.gz)、[官方校验值](https://repo.huaweicloud.com/openharmony/os/5.0.0-Release/L2-SDK-MAC-M1-PUBLIC.tar.gz.sha256) | `55251a081bb4a18c42a7f6c482f34e8c38ce0a3b95cef9dd8548019c25e9dc87` |
| Node v18.20.8，darwin-arm64 | [包](https://nodejs.org/dist/v18.20.8/node-v18.20.8-darwin-arm64.tar.gz)、[校验表](https://nodejs.org/dist/v18.20.8/SHASUMS256.txt) | `bae4965d29d29bd32f96364eefbe3bca576a03e917ddbb70b9330d75f2cacd76` |
| Temurin JDK 17.0.21+9，mac aarch64 | [Adoptium 元数据](https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=aarch64&image_type=jdk&os=mac&vendor=eclipse)、[固定版本包](https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21_9.tar.gz) | `78b08c7f5a0598242d5719c022e19479cb4a3aa45c37c19726a757a469ed1c15` |
| OpenHarmony Command Line Tools mac 2.0.0.2（内含 ohpm 1.2.0） | [华为官方归档页](https://developer.huawei.com/consumer/cn/deveco-studio/archive/) 中同名包 | `213a35ec4df224bd95e203710b40f28109c9c42c6954d14071394b6653cc5682` |

曾下载 Node 20.20.2 并核对官方校验值 `466e05f3477c20dfb723054dfebffe55bc74660ee77f612166fca121dacb65b6`，但其与样例 wrapper 的 pnpm 7.30.0 出现 `ERR_INVALID_THIS`，未选为交付组合；已清理该次安装。Node 18 属于旧版工具链依赖，版本升级应由 M10 单独验证，不能直接替换。

## 工程依据

- [官方 OpenHarmony 5.0.0 发布说明](https://github.com/openharmony/docs/blob/master/en/release-notes/OpenHarmony-v5.0.0-release.md)：API 12、Public SDK 5.0.0.71、配套 DevEco Studio 5.0.0 Release，并列出 Mac M1 包。
- [官方 AppStartup 样例固定提交](https://github.com/openharmony/applications_app_samples/tree/f057ed7727368d98d2ea1dde21c33e0150b76c41/code/BasicFeature/Ability/AppStartup)，分支 `OpenHarmony-5.0.0-Release`。实际取得的 `build-profile.json5` 指定 API 12 / OpenHarmony，`hvigor/hvigor-config.json5` 指定 Hvigor 与 OHOS 插件 4.0.2。本项目保留该组合，删除样例的启动任务、数据库、ImageKnife 依赖与页面，改为 M00 验证页。
- `app/LICENSE` 保留官方样例 Apache-2.0 许可，原文件中的版权头保留。样例 PNG 图标作为最小工程素材保留，未引入外部商业素材。
- Hvigor / OHOS 插件从 `https://repo.harmonyos.com/npm/` 安装；pnpm 7.30.0 与通用 npm 依赖从 `https://registry.npmjs.org/` 安装；Hypium 1.0.15 从 `https://ohpm.openharmony.cn/ohpm/` 安装，完整性保存在 `app/oh-package-lock.json5`。
- DevEco 官方下载中心：[下载页](https://developer.huawei.com/consumer/cn/download/)。本次仅获取了公开页面；本机会话下后续接口 HTTP 404、直接首页请求曾 HTTP 403，浏览器工具两次超时。未取得目标版本 IDE 安装包，未安装旧版 3.1.1 冒充 API 12 环境。
- [OpenHarmony 官方签名工具说明](https://github.com/openharmony/developtools_hapsigner/blob/master/README_ZH.md)。本次还核对了本地 API 12 `hap-sign-tool.jar -h`，未生成个人签名材料。

## 下载和安装的实际方法

本机系统代理为 `127.0.0.1:7890`；命令行直连部分站点失败，下载时显式用 `curl --proxy http://127.0.0.1:7890 -L --fail ...`。代理没有写入应用或全局 shell 配置，其他电脑应按自身网络选择。

SDK 先解压外层 tar.gz，再把 `sdk/packages/ohos-sdk/darwin/*.zip` 全部用 `unzip` 解压到 `$HOME/Library/OpenHarmony/Sdk/12/`（保留可执行权限）。Node 与 JDK 的 tar.gz 解压到 `$HOME/Library/OpenHarmony/Tools/`。命令行工具解压同目录，使用其 `ohpm/bin/init` 安装运行依赖，传入 `REGISTRY=https://registry.npmjs.org/`。`app/.npmrc` 为 `@ohos` 单独指定官方 HarmonyOS 工具仓。

ohpm 旧工具的初始化 npm 输出报告 7 个依赖安全告警（1 low / 1 moderate / 4 high / 1 critical）；没有执行自动升级或 `audit fix --force`。这是开发机 CLI 的依赖告警，不是已确认的应用漏洞；正式应用未引入这些 npm 依赖。M10 应评估升级工具链并重跑构建。SDK 与工具的许可证保留在安装目录内。

## 用户下载 IDE 的追加实查

用户随后从官方站点下载 `devecostudio-mac-arm-26.0.0.851.zip`，下载来源元数据的域名为华为 CDN 与 developer.huawei.com。计算的 SHA-256 为 `86289edeb2e8e30eb1adf80cba0fc55f0e57cdd4f6dc4ec9c59985a0bc4b8524`，尚未独立取得官网发布校验值，不能称两者已比对。ZIP CRC 与内部 DMG 校验均成功；包内 DevEco Studio 26.0.0.851 / ARM64，Apple codesign 深度校验成功，签名者为 Huawei Device Co,. LTD (TZEA3TN37Q)。详见 logs/ide-package.txt。用户明确正在安装，待其完成通知后再核验安装副本和首次启动；本执行者未并发复制/覆盖安装目录。用户下载原件保留。

## 最终 IDE 与工具组合更正

用户已完成安装，M00在 `/Applications/DevEco-Studio.app` 再次执行codesign深度校验及spctl，均退出0；Apple结果为Notarized Developer ID，见logs/ide-validation.txt。后续UI控制恢复，已实际打开项目、处理迁移、同步并成功编译HAP。最终工具来自这个已核验IDE：Hvigor/OHOS插件6.26.8、ohpm26.0.0.630（以Node24.14.1运行）；SDK12编译Node为18.20.8，签名JDK17不变。前文4.0.2/1.2.0是初次构建阶段历史。官方迁移只改模型配置与wrapper/lock格式，未升级SDK；最终完整步骤见BUILD_AND_RUN.md。
