import common from '@ohos.app.ability.common';
import { V } from '../ui/VisualKit';
import { Account, clearAccount, createAccount, loadAccount, loadSavedPassword, saveSavedPassword,
  verifyPassword } from './AccountStore';

/**
 * First screen: creates or unlocks the local account. There is no server here —
 * the password only gates access to data that already lives on this device.
 */
@Component
export struct LoginGate {
  onSuccess: (nickname: string) => void = () => {};
  @State private nickname: string = '';
  @State private password: string = '';
  @State private hasAccount: boolean = false;
  @State private savedPassword: string = '';
  @State private usePassword: boolean = true;
  @State private remember: boolean = true;
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private loading: boolean = true;
  private account: Account | null = null;
  private active: boolean = true;

  aboutToAppear(): void {
    this.active = true;
    this.prepare();
  }

  aboutToDisappear(): void {
    this.active = false;
  }

  private async prepare(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const account = await loadAccount(context);
      const saved = await loadSavedPassword(context);
      if (!this.active) {
        return;
      }
      this.account = account;
      this.hasAccount = account !== null;
      this.nickname = account === null ? '' : (account as Account).nickname;
      this.savedPassword = saved;
      this.usePassword = saved.length === 0;
    } catch (error) {
      this.error = '读取本机账号失败。';
    }
    this.loading = false;
  }

  private async submitWithSaved(): Promise<void> {
    if (this.busy || this.account === null || this.savedPassword.length === 0) {
      return;
    }
    this.busy = true;
    this.error = '';
    try {
      const ok = await verifyPassword(this.account as Account, this.savedPassword);
      if (!this.active) {
        return;
      }
      if (ok) {
        this.onSuccess((this.account as Account).nickname);
      } else {
        this.savedPassword = '';
        this.usePassword = true;
        this.error = '保存的登录信息已失效，请输入密码。';
      }
    } catch (error) {
      this.error = '登录失败，请重试。';
    }
    this.busy = false;
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    const nickname = this.nickname.trim();
    const password = this.password;
    if (!this.hasAccount && (nickname.length < 2 || nickname.length > 12)) {
      this.error = '昵称请填 2 到 12 个字。';
      return;
    }
    if (password.length < 4) {
      this.error = '密码至少 4 位。';
      return;
    }
    this.busy = true;
    this.error = '';
    try {
      const context = getContext(this) as common.UIAbilityContext;
      if (this.hasAccount && this.account !== null) {
        const ok = await verifyPassword(this.account as Account, password);
        if (!this.active) {
          return;
        }
        if (!ok) {
          this.error = '密码不对，再试一次。';
          this.busy = false;
          return;
        }
        if (this.remember) {
          await saveSavedPassword(context, password);
        }
        this.onSuccess((this.account as Account).nickname);
      } else {
        const created = await createAccount(context, nickname, password);
        if (this.remember) {
          await saveSavedPassword(context, password);
        }
        if (!this.active) {
          return;
        }
        this.onSuccess(created.nickname);
      }
    } catch (error) {
      this.error = '操作失败，请重试。';
    }
    this.busy = false;
  }

  @Builder
  private rememberRow() {
    Row({ space: 7 }) {
      Stack() {
        if (this.remember) {
          Text('✓')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
        }
      }
      .width(18)
      .height(18)
      .borderRadius(6)
      .backgroundColor(this.remember ? V.lime : '#00000000')
      .border({ width: this.remember ? 0 : 1, color: V.line })

      Text('记住登录信息')
        .fontSize(11)
        .fontColor(V.text)
      Blank()
    }
    .width('100%')
    .onClick(() => { this.remember = !this.remember; })
  }

  build() {
    Column({ space: 0 }) {
      Blank()

      Column({ space: 22 }) {
        Column({ space: 10 }) {
          Stack() {
            Text('碳')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.lime)
          }
          .width(64)
          .height(64)
          .backgroundColor(V.forest)
          .borderRadius(22)
          .shadow({ radius: 18, color: '#33123524', offsetX: 0, offsetY: 8 })

          Text(this.hasAccount ? '欢迎回来' : '给自己起个名字')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
            .margin({ top: 6 })
          Text(this.hasAccount ? '输入密码继续你的账本' : '账号只保存在这台设备上')
            .fontSize(11)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')

        Column({ space: 10 }) {
          if (this.hasAccount) {
            Row() {
              Text(this.nickname)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(V.ink)
              Blank()
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#F7F5EA')
            .border({ width: 1, color: V.line })
            .borderRadius(14)
          } else {
            TextInput({ text: this.nickname, placeholder: '昵称' })
              .id('login-nickname')
              .height(50)
              .fontSize(14)
              .fontColor(V.ink)
              .backgroundColor('#FCFAF0')
              .border({ width: 1, color: V.line })
              .borderRadius(14)
              .enabled(!this.busy)
              .onChange((value: string) => {
                this.nickname = value;
                this.error = '';
              })
          }

          if (this.hasAccount && this.savedPassword.length > 0 && !this.usePassword) {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                if (this.busy) {
                  LoadingProgress().width(16).height(16).color(V.lime)
                }
                Text(this.busy ? '正在进入…' : '一键登录')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.busy ? '#B9CFBB' : V.lime)
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
            .id('login-one-tap')
            .width('100%')
            .height(50)
            .backgroundColor(V.forest)
            .borderRadius(25)
            .enabled(!this.busy)
            .onClick(() => { this.submitWithSaved(); })

            Text('改用密码')
              .fontSize(11)
              .fontColor(V.moss)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 2 })
              .onClick(() => { this.usePassword = true; })
          } else {
            TextInput({ text: this.password, placeholder: '密码（至少 4 位）' })
              .id('login-password')
              .type(InputType.Password)
              .height(50)
              .fontSize(14)
              .fontColor(V.ink)
              .backgroundColor('#FCFAF0')
              .border({ width: 1, color: V.line })
              .borderRadius(14)
              .onChange((value: string) => {
                this.password = value;
                this.error = '';
              })
              .onSubmit(() => { this.submit(); })

            this.rememberRow()

            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                if (this.busy) {
                  LoadingProgress().width(16).height(16).color(V.lime)
                }
                Text(this.busy ? '正在处理…' : (this.hasAccount ? '进入账本' : '创建并进入'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.busy ? '#B9CFBB' : V.lime)
              }
              .width('100%')
              .height(50)
              .justifyContent(FlexAlign.Center)
            }
            .id('login-submit')
            .width('100%')
            .height(50)
            .backgroundColor(V.forest)
            .borderRadius(25)
            .enabled(!this.busy)
            .onClick(() => { this.submit(); })
          }

          if (this.error.length > 0) {
            Text(this.error)
              .fontSize(10)
              .fontColor(V.error)
              .width('100%')
          }

          if (this.hasAccount) {
            Text('换个账号')
              .fontSize(10)
              .fontColor(V.sage)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 4 })
              .onClick(() => { this.switchAccount(); })
          }
        }
        .width('100%')

        Text('碳小步 · 记录保存在本机')
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')
      .padding({ left: 26, right: 26 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  private async switchAccount(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await clearAccount(context);
      if (!this.active) {
        return;
      }
      this.account = null;
      this.hasAccount = false;
      this.nickname = '';
      this.password = '';
      this.savedPassword = '';
      this.usePassword = true;
      this.error = '';
    } catch (error) {
      this.error = '重置失败，请重试。';
    }
  }
}
