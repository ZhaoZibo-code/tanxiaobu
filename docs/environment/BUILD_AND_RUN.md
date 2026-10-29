# M00 构建、测试与运行

日期：2026-10-27（Asia/Shanghai）。工程 `/Users/ZZB/Desktop/game/app`，包 `com.carbonfootprint.app`，产品 `default`，模块 `entry`，Stage / ArkTS / ArkUI，debug。构建SDK为OpenHarmony Public SDK5.0.0.71/API12。

**当前结果**：主/测试HAP构建、本地框架smoke均通过；用户授权的独立HarmonyOS7模拟器上安装启动、真实按钮设备用例与0→1→2/进程重启归零均通过。赛事是否接受该镜像、真机和发布签名仍未验证，不宣布G0总验收。第9节为本轮运行证据和复现入口。

## 1. 本机环境与依赖

新Bash/Zsh先进入app；`env.sh`依赖当前目录，只影响当前shell：

```bash
cd /Users/ZZB/Desktop/game/app
```

```bash
source scripts/env.sh
```

固定组合：编译Node18.20.8、JDK17.0.21+9、DevEco26.0.0.851内置Hvigor/插件6.26.8、modelVersion5.0.0。ohpm26.0.0.630由 `scripts/ohpm` 单独切到IDE内置Node24.14.1运行，不改变编译Node。完整路径和版本证据见ENVIRONMENT.md及 `logs/handoff-toolchain.txt`。

首次安装或锁文件变化后执行：

```bash
ohpm install
```

原执行者已成功安装，本次接班未重新安装。固定开发依赖Hypium1.0.15，保留锁文件v3。普通npm依赖用npmjs，`@ohos` scope用官方工具仓；未向应用写入代理或运行时联网依赖。不同工作副本应调整本机忽略的 `local.properties` SDK路径，不提交签名和账号材料。

## 2. 主HAP原生构建（L2）

```bash
./hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
```

本次接班实际执行以上构建，退出0，CompileArkTS/PackageHap成功；不是本轮clean构建。需要完整重建时在assembleHap前加clean，不能与其他会话并发写同一build目录。原执行者的clean构建与IDE构建证据见 `logs/final-native-build.log`、`logs/ide-ui-build.txt`；新证据为 `logs/handoff-native-build.log`。

当前主产物：`/Users/ZZB/Desktop/game/app/entry/build/default/outputs/default/entry-default-unsigned.hap`。

- 本轮CLI构建并安装测试的版本：82,559字节，ABC10,688字节；SHA-256：`78cd6bc4ceeeb03cccab095e28bf3347c5ffdc1eda4c0c709ceec9bae503c899`。
- 收尾23:10同一路径被另一次打包替换，当前SHA为 `a421dd6284a231640df7b8898595b2b953d3b3a66e332df536d66b46d5ec83d8`，大小、SDK/API与ABC大小检查仍符合，但本对话未对该新字节版本重做安装运行；不得将前述测试结果直接绑定新SHA。见报告第13.7节与 `logs/handoff-final-artifacts.txt`。
- 内部SDK类型OpenHarmony、版本5.0.0.71、min/target API12；正式HAP不含测试模块。
- 保留 `No signingConfig found for product default` 和SDK12打包器 `--pkg-sdk-info-path is invalid!` 警告；本次镜像安装运行成功不证明所有目标兼容。

## 3. 本地测试入口（L1，仅框架smoke）

```bash
./hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug test --no-daemon
```

本次退出0，实际结果 `Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0`。源目录 `entry/src/test/`，注册文件 `List.test.ets` 仅注册 `LocalUnit.test.ets` 的 `localUnitTest/assertContain`。这只是官方字符串断言，不是业务规则覆盖。

SDK Previewer会mock部分原生能力，本地结果不能证明RDB、设备UI或完整业务。证据 `logs/handoff-local-test.log`、`logs/handoff-local-test-result.txt`；再生目录 `entry/.test/` 可在保存必要文本结果后清理。尚无核实的单用例CLI筛选参数，不猜测使用。后续公共注册由M01/M10按归属接续。

## 4. 设备测试HAP（编译与本次镜像执行均通过）

```bash
./hvigorw --mode module -p product=default -p module=entry@ohosTest -p buildMode=debug assembleHap --no-daemon
```

本次退出0，OhosTestCompileArkTS/打包成功，见 `logs/handoff-test-hap-build.log`。产物 `/Users/ZZB/Desktop/game/app/entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap`，1,031,530字节，ABC220,712字节；SHA-256：`c32cf7a6f373be01b1ec0a2bb977341fd729c3e2286ea2ffaeb0a62ea3cbfc3d`。

- 测试源/注册：`entry/src/ohosTest/ets/test/Ability.test.ets`、`List.test.ets`。
- runner：`entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets`；测试Ability为 `ets/testability/TestAbility.ets`，合并模块名 `entry_test`。
- 用例 `M00NativeEnvironment/buttonUpdatesVisibleState` 启动真实EntryAbility，断言 `m00-status` 初始0，点击 `m00-increment` 后断言1；无业务fixture或固定成功服务。
- 本次实际设备执行1 pass/0 failure/0 error，TestFinished-ResultCode0；精确命令见第9节。不是用本地Previewer替代设备测试。

## 5. 签名边界与真机准备

两份当前HAP均unsigned，**本次M00Compatibility模拟器默认配置实际允许安装**，未修改系统签名/安全检查、未修改SDK、未使用示例私钥。这不代表真机或发布包可安装，以下仅为尚未执行的真机准备：

1. 连接赛事认可的API12+目标，开启开发者/调试模式并由用户授权电脑；记录实际系统、API和目标ID。普通Android手机不刷机。
2. 在IDE使用目标信任链认可、包名为 `com.carbonfootprint.app`、有效期与UDID匹配的debug签名材料，由用户本机填写口令。SDK模板和公开示例私钥不是用户正式发布身份，不原样套用过期profile。
3. 若使用SDK的hap-sign-tool，先查看其实际帮助并按对应版本官方签名指导完成sign-profile、sign-app和verify-app；本次未执行私人签名，不虚构可用证书。
4. 已签名HAP需重新记录SHA，不能沿用上述unsigned标识；后续共享签名/构建配置交M10维护。

## 6. 连接真实目标后的通用恢复步骤

本节是尚未执行的物理目标流程，不是第9节模拟器的前置要求。完成目标调试授权及所需签名后，使用 `hdc list targets` 返回的实际ID，查询系统/API，安装与该目标签名匹配的主包，再启动EntryAbility；安装测试包后先force-stop，再执行同一aa test命令。失败时保留安装/aa输出与限定应用的hilog，不通过关闭安全校验绕过。

aa/ArkXtest形式按API12说明、安装的SDK TestKit声明和本次设备实际执行核对。测试前必须冷启动应用，手动点过计数后不要直接运行要求初始0的用例。

## 7. 验证结果与产物核对

```bash
python3 scripts/inspect-artifacts.py
```

该脚本只检查真实HAP内部SDK、模块、非空ABC及SHA，不是ArkTS测试，也不推断安装历史。日志 `logs/handoff-artifacts.txt`。

从项目根核对源码清单：

```bash
shasum -a 256 -c docs/environment/SOURCE_SHA256SUMS.txt
```

43项包含源码、资源、配置、脚本和锁文件。接班沿用ArkTS源码与构建配置；收尾仅修正检查脚本不应声称“未安装”的输出、README当前状态并同步对应校验值，不改变HAP。重复打包HAP的SHA可能变化，旧 `artifacts.txt` 与 `final-*` 属历史，不能替代本次标识。

## 8. IDE迁移与历史

原执行者在IDE打开app后，通过官方“工具 > 迁移助手 > 5.0.0”迁移，SDK保持12，项目结构选择Node18，随后同步与编译HAP成功。modelVersion、锁文件和wrapper格式发生迁移；M00保留调用IDE工具的 `app/hvigorw` 薄封装。见报告第11—12节、`logs/ide-ui-build.txt`。

旧Node20/pnpm的ERR_INVALID_THIS、新ohpm在Node18的ERR_REQUIRE_ESM与旧工具依赖告警保留为历史。当前用已验证的分离Node环境，不破坏性自动升级依赖。本次接班重跑的是CLI构建，没有把旧IDE UI操作写成本次重新执行。

## 9. 接班模拟器安装、启动与真实交互（已执行）

用户确认原M00停止并授权“先做兼容性验证”。镜像为此前已下载的 **HarmonyOS7.0.0.107/API26**，Emulator26.0.0.402，独立实例 `M00Compatibility`（4CPU/4GiB/6GiB），不是OpenHarmony API12参考镜像。内部参数fullname为 `OpenHarmony-7.0.0.105`，软件版本为 `emulator 7.0.0.107(SP8DEVC00E999R4P11)`，不据此改写镜像发行身份。构建目标仍为OpenHarmony/API12。

已执行的一次性创建命令；实例已保留，后续**不要重复创建**：

```bash
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -create M00Compatibility -deviceType Phone -osVersion "HarmonyOS 7.0.0(26.0.0)" -memory 4 -storage 6 -hotBoot false
```

后续直接启动保留实例：

```bash
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -start M00Compatibility
```

本次启动工具提示snapshot不适用hotBoot=false并自动冷启动成功；首次冷启动约48秒。运行时查询：

```bash
hdc list targets
```

本次实际目标 `127.0.0.1:5555`，后续重新查询并按实际值替换以下ID。已在app目录加载第1节环境后，执行过：

```bash
hdc -t 127.0.0.1:5555 install -r /Users/ZZB/Desktop/game/app/entry/build/default/outputs/default/entry-default-unsigned.hap
```

```bash
hdc -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.carbonfootprint.app
```

```bash
hdc -t 127.0.0.1:5555 install -r /Users/ZZB/Desktop/game/app/entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
```

```bash
hdc -t 127.0.0.1:5555 shell aa force-stop com.carbonfootprint.app
```

```bash
hdc -t 127.0.0.1:5555 shell aa test -b com.carbonfootprint.app -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 15000
```

两次安装均返回 `install bundle successfully.`，启动返回 `start ability successfully.`，设备用例结果1 pass/0 failure/0 error、ResultCode0，见 `logs/handoff-emulator-{install,start,test-install,uitest}.log`。

另单独force-stop/start建立初始0，读取真实 `uitest dumpLayout` 的 `m00-increment` bounds计算按钮中心，在该实例用uiInput实际点击两次，每次重新读取 `m00-status`，得到0→1→2；截图已实际查看，页面非空、计数2。再次force-stop/start后真实布局为0。保留 `logs/handoff-emulator-interaction.log` 与 `handoff-ui-{zero,1,2,restart}.json`；临时截图阅后清理。计数是内存UI状态，不声称业务持久化。

验证结束使用官方停止命令释放本轮模拟器资源，保留实例和已安装应用，关闭本轮专用终端；不停止用户其他目标：

```bash
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -stop M00Compatibility
```

收尾变化：上述stop成功、专用终端关闭后，DevEco Studio又启动同一实例；该新进程保留，不再替用户停止。主HAP也在23:10重新打包，当前a421dd62…与本轮已安装测试的78cd6bc4…不同，重生缓存同样保留。详见报告第13.7节；运行步骤可用于后续复验，但不是声称新包已运行。

**验收边界**：本次有真实限定镜像的安装启动与交互证据，绑定本轮78cd6bc4…主包；当前a421dd62…新字节版本尚未重做安装运行。仍无物理真机、有效发布签名、OpenHarmony API12参考镜像、M01+业务/RDB/离线业务/性能证据。商业镜像的赛事认可与G0最终结论由总工程师审阅，不自动通过。
