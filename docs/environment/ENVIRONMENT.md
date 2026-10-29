# M00 开发环境实查

记录日期：2026-10-27（Asia/Shanghai）。最新执行者：Claude Code 接班会话 `local_38943ac7-e6d2-4e0f-a64d-cd9502a6b0a1`；用户明确确认原 M00 停止并由本对话接手。

## 当前结论与边界

- **已实现**：沿用并核验已有最小 ArkTS/ArkUI Stage 工程、环境页、按钮、测试入口和工具链；源码清单43项匹配，未重新初始化，未开发 M01+。
- **构建验证**：本轮重新执行 OpenHarmony API12 主HAP、测试HAP构建及本地Hypium，全部退出0；本地仅1项框架smoke通过。
- **安装启动**：用户另行授权的独立 HarmonyOS7 模拟器上，本轮主/测试unsigned HAP默认安装成功，EntryAbility启动、原生按钮测试及实际0→1→2/进程重启归零均成功。未修改签名检查或系统安全开关。
- **未验证**：赛事对该商业模拟器镜像的认可、OpenHarmony API12参考设备与物理真机、真机/发布签名、M01+业务、RDB、性能。不宣布G0总验收通过。

原执行阶段的安装与迁移历史见 `docs/ai-dev/reports/M00.md` 第2—12节；本次新证据见第13节与 `logs/handoff-*`，不把旧HAP校验值当当前产物。

## 实查固定组合

| 项目 | 实际值 / 路径 | 验证范围 |
| --- | --- | --- |
| 系统 | macOS15.8，Build24H23，arm64 | 本轮 `sw_vers` / `uname -m` |
| 硬件 | MacBook Pro / Apple M2 Pro / 16GB；本轮可用磁盘约275GiB | 实查，不保存序列号 |
| DevEco Studio | 26.0.0.851，`/Applications/DevEco-Studio.app`；build `DS-261.23567.138.36.2600851` | 本轮安装副本版本实查；原执行者codesign/公证、UI迁移同步与IDE构建记录保留 |
| 构建SDK | OpenHarmony Public SDK5.0.0.71/API12 | 五组件已安装；本轮CompileArkTS及实际HAP元信息核验 |
| SDK根目录 | `/Users/ZZB/Library/OpenHarmony/Sdk`；版本目录 `12/` | ets/js/native/previewer/toolchains；`sdk-components.json` |
| 编译Node/npm | Node18.20.8 / npm10.8.2 | `~/Library/OpenHarmony/Tools/node-v18.20.8-darwin-arm64`；不改全局PATH |
| JDK | Eclipse Temurin17.0.21+9，aarch64 | `~/Library/OpenHarmony/Tools/jdk-17.0.21+9/Contents/Home`；本轮版本核验 |
| Hvigor/OHOS插件 | 6.26.8 / 6.26.8，IDE内置；modelVersion5.0.0 | 本轮CLI主/测试HAP均成功；`app/hvigorw`为本机薄封装 |
| ohpm | 26.0.0.630，IDE内置 | `app/scripts/ohpm`单独使用IDE自带Node24.14.1；编译仍为Node18；本轮未重装依赖 |
| Hypium | 1.0.15，开发依赖，锁文件v3 | 本地框架smoke1项与真实模拟器设备按钮用例1项分别通过 |
| hdc | API12 SDK的 `toolchains/hdc`，3.1.0b | 本轮已连接、安装、启动、执行设备用例，无需更换版本 |
| SDK Previewer | 5.0.0.71 | 本地测试使用；不能等同系统模拟器 |
| 系统模拟器 | HarmonyOS Emulator26.0.0.402，IDE内置 | 本轮CLI创建/启动独立 `M00Compatibility` 实例成功 |
| 系统镜像 | HarmonyOS7.0.0.107，`HarmonyOS 7.0.0(26.0.0)`，arm64 | 接手时已下载；未重新下载、未代用户接受许可 |
| 镜像目录 | `~/Library/Huawei/Sdk/system-image/HarmonyOS-7.0.0/phone_all_arm/` | 与构建SDK目录分离；未把编译目标改为HarmonyOS |
| 实例目录 | `~/.Huawei/Emulator/deployed/M00Compatibility` | 4CPU / 4096MB / 6GB数据盘；保留为后续开发运行目标 |
| 运行时参数 | `const.ohos.apiversion=26`；`const.ohos.fullname=OpenHarmony-7.0.0.105`；软件 `emulator 7.0.0.107(SP8DEVC00E999R4P11)` | 来自已启动系统，见 `logs/handoff-emulator-system.txt`；内部fullname不改变镜像商业发行标识 |
| 调试目标 | 验证期间 `127.0.0.1:5555` | 本次唯一hdc目标；重启后应重新查询，不能假定端口固定 |

版本查询证据：`logs/handoff-toolchain.txt`。源码、主包/测试包标识：`SOURCE_SHA256SUMS.txt`、`logs/handoff-artifacts.txt`。此前 `final-*` 日志仍作为迁移后首次构建历史保留。

## SDK与API依据

比赛资料记载统一DevEco、OpenHarmony、API12及以上，纯北向应用可用手机/平板/模拟器；**是否认可本次商业HarmonyOS镜像仍需总工按赛事口径核定**。镜像系统参数出现OpenHarmony名称不等于已验证比赛参考设备。

工程始终使用OpenHarmony5.0.0 Public SDK/API12。新HAP内部 `compileSdkType=OpenHarmony`、`compileSdkVersion=5.0.0.71`、min/target API均12，含真实 `ets/modules.abc`。无商业专有Kit或Web替代实现。

已有实现的本地声明依据：

- `12/ets/kits/@kit.AbilityKit.d.ts`、`12/ets/api/@ohos.app.ability.UIAbility.d.ts`：Stage UIAbility。
- `12/ets/kits/@kit.ArkUI.d.ts`、`12/ets/api/@ohos.window.d.ts`：WindowStage/loadContent。
- `12/ets/kits/@kit.PerformanceAnalysisKit.d.ts`：hilog。
- `12/ets/kits/@kit.TestKit.d.ts`、`12/ets/api/@ohos.UiTest.d.ts`：TestRunner、abilityDelegatorRegistry、Driver、ON.id、waitForComponent、click、getText。

本次另用运行系统实际 `uitest` 帮助核对dumpLayout、uiInput、screenCap；点击位置从真实布局中的 `m00-increment` bounds计算，未凭截图猜测。设备Hypium用例直接启动真实EntryAbility并查询/点击组件。

## 签名与后续最小动作

本次两份unsigned HAP在**该模拟器默认配置**下可安装，无需用户登录或签名材料，未关闭签名验证。这不证明任意真机可安装unsigned包，也不证明具有有效发布签名。物理目标仍需信任链认可的有效签名、匹配包名/有效期/UDID和用户调试授权；不使用SDK示例私钥充当个人正式身份。

后续使用保留实例的精确启动、查询、安装和测试命令见 `BUILD_AND_RUN.md` 第9节。本轮官方stop成功并关闭专用终端后，收尾观察到DevEco Studio重新启动同一实例（父进程为IDE），当前又连接127.0.0.1:5555；未再次停止可能正由用户操作的目标。23:10磁盘主HAP也被重新打包为SHA `a421dd6284a231640df7b8898595b2b953d3b3a66e332df536d66b46d5ec83d8`，与本轮已安装测试的78cd6bc4…不同；该新字节版本未由本对话重新安装运行，详见报告第13.7节与 `logs/handoff-final-artifacts.txt`。

总工最小待核定事项：审阅本次L2与限定镜像的L3/按钮证据，确认赛事是否接受此运行目标，决定G0与M01授权；执行者不修改公共PROJECT_MEMORY、TASK_BOARD或契约。

## 保留的警告与历史

- 新Hvigor调用SDK12打包器仍有 `--pkg-sdk-info-path is invalid!`；HAP元信息、ABC及本次镜像安装运行已实查，不能外推所有目标兼容性。
- `No signingConfig` 对应真实unsigned产物，不再错误解释为该模拟器必然不能安装。
- 原Node20/pnpm兼容失败、旧CLI依赖告警、IDE初次同步失败及官方迁移过程在报告和DOWNLOADS保留；不做破坏性依赖升级或自动audit修复。
- 当前目录及上级非Git，未初始化仓库、切分支、提交或覆盖其他执行者成果；忽略本机 `local.properties`、`.idea` 和签名配置的共享边界不变。
