import curves from '@ohos.curves';
import { formatReduction } from '../../common/utils/Display';

/**
 * Shared visual language for the refreshed interface.
 * Deep forest + cream paper + lime accent, with an aurora backdrop.
 */
export class V {
  static readonly ink: string = '#12291F';
  static readonly forest: string = '#0F3B2C';
  static readonly pine: string = '#1D5A45';
  static readonly moss: string = '#4F7A5F';
  static readonly sage: string = '#8FA893';
  static readonly mint: string = '#DCEBDD';
  static readonly lime: string = '#D9F26E';
  static readonly limeSoft: string = '#EEF7C6';
  static readonly cream: string = '#F7F4E7';
  static readonly paper: string = '#FFFDF4';
  static readonly text: string = '#4E6457';
  static readonly muted: string = '#7C8C80';
  static readonly line: string = '#DEE7D9';
  static readonly amber: string = '#C68A3E';
  static readonly coral: string = '#C47255';
  static readonly error: string = '#A23A32';
  static readonly white: string = '#FFFFFF';
}

/** Soft aurora field used behind the whole app shell. Static gradients only:
 *  no full-screen blur or infinite animation, so scrolling stays smooth. */
@Component
export struct AuroraBackdrop {
  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 155,
          colors: [['#F8F5E9', 0.0], ['#EDF4E1', 0.45], ['#F7F3E6', 1.0]]
        })
      Column()
        .width(460)
        .height(460)
        .borderRadius(230)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#78CFE6A8', 0.0], ['#00CFE6A8', 1.0]]
        })
        .position({ x: -150, y: -120 })
      Column()
        .width(420)
        .height(420)
        .borderRadius(210)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#66F1D9A4', 0.0], ['#00F1D9A4', 1.0]]
        })
        .position({ x: 200, y: 140 })
      Column()
        .width(380)
        .height(380)
        .borderRadius(190)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#55B9D8C2', 0.0], ['#00B9D8C2', 1.0]]
        })
        .position({ x: -100, y: 540 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}

/** Big animated reduction value, split into number + unit for editorial hierarchy. */
@Component
export struct AnimatedReduction {
  @Prop @Watch('restart') grams: number = 0;
  @Prop valueSize: number = 46;
  @Prop unitSize: number = 14;
  @Prop color: string = V.cream;
  @Prop accent: string = '#CBE3B4';
  @Prop idValue: string = '';
  @State private shown: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.restart();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private restart(): void {
    this.stop();
    const target = this.grams;
    const duration = 760;
    const started = Date.now();
    this.timer = setInterval(() => {
      const progress = Math.min(1, (Date.now() - started) / duration);
      const eased = 1 - Math.pow(1 - progress, 3);
      this.shown = target * eased;
      if (progress >= 1) {
        this.shown = target;
        this.stop();
      }
    }, 16);
  }

  private isKilogram(): boolean {
    return Math.abs(Math.round(this.grams)) >= 1000;
  }

  private numberText(): string {
    if (this.isKilogram()) {
      return (this.shown / 1000).toFixed(2);
    }
    return `${Math.round(this.shown)}`;
  }

  private unitText(): string {
    return this.isKilogram() ? 'kg CO₂e' : 'g CO₂e';
  }

  build() {
    Row({ space: 7 }) {
      Text(this.numberText())
        .id(this.idValue)
        .fontSize(this.valueSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color)
        .letterSpacing(-1)
        .textShadow({ radius: 18, color: '#AA0A2419', offsetX: 0, offsetY: 6 })
        .accessibilityText(formatReduction(Math.round(this.grams)))
      Text(this.unitText())
        .fontSize(this.unitSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.accent)
        .margin({ top: 12 })
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }
}

/** Animated integer for points and counters. */
@Component
export struct AnimatedInt {
  @Prop @Watch('restart') value: number = 0;
  @Prop valueSize: number = 32;
  @Prop color: string = V.cream;
  @Prop idValue: string = '';
  @State private shown: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.restart();
  }

  aboutToDisappear(): void {
    this.stop();
  }

  private stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private restart(): void {
    this.stop();
    const target = this.value;
    const duration = 620;
    const started = Date.now();
    this.timer = setInterval(() => {
      const progress = Math.min(1, (Date.now() - started) / duration);
      const eased = 1 - Math.pow(1 - progress, 3);
      this.shown = target * eased;
      if (progress >= 1) {
        this.shown = target;
        this.stop();
      }
    }, 16);
  }

  build() {
    Text(`${Math.round(this.shown)}`)
      .id(this.idValue)
      .fontSize(this.valueSize)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.color)
      .letterSpacing(-1)
  }
}

/** Small uppercase eyebrow + title, used to open page sections. */
@Component
export struct SectionHeading {
  @Prop eyebrow: string = '';
  @Prop title: string = '';
  @Prop trailing: string = '';
  @Prop dark: boolean = false;

  build() {
    Row() {
      Column({ space: 5 }) {
        if (this.eyebrow.length > 0) {
          Text(this.eyebrow)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(this.dark ? '#A9C3AC' : V.moss)
            .width('100%')
        }
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.dark ? V.cream : V.ink)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.trailing.length > 0) {
        Text(this.trailing)
          .fontSize(12)
          .fontColor(this.dark ? '#B7CDBA' : V.muted)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }
}

/** Shared spring curve so every surface settles with the same personality. */
export function softSpring(): curves.ICurve {
  return curves.springMotion(0.52, 0.76);
}

export function snappySpring(): curves.ICurve {
  return curves.springMotion(0.36, 0.72);
}
