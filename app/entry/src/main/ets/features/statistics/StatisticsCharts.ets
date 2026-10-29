import { StatisticsItem } from '../../common/contracts/Statistics';

const CHART_COLORS: string[] = ['#2E6A4F', '#D6A345', '#C47255', '#78958A'];

@Component
export struct TrendLineChart {
  @Prop @Watch('redraw') items: StatisticsItem[] = [];
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasWidth: number = 0;
  private ready: boolean = false;

  private redraw(): void {
    if (!this.ready || this.canvasWidth <= 0 || this.items.length === 0) { return; }
    const ctx = this.context;
    const height = 100;
    const baseline = 62;
    ctx.clearRect(0, 0, this.canvasWidth, height);
    let maximum = 0;
    this.items.forEach((item: StatisticsItem) => { maximum = Math.max(maximum, Math.abs(item.reductionGrams)); });
    const scale = maximum === 0 ? 1 : maximum;

    ctx.strokeStyle = '#DCE5D5';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(5, baseline); ctx.lineTo(this.canvasWidth - 5, baseline); ctx.stroke();

    const xAt = (index: number): number => {
      return this.items.length === 1 ? this.canvasWidth / 2 :
        5 + (this.canvasWidth - 10) * index / (this.items.length - 1);
    };
    const yAt = (index: number): number => {
      return baseline - 44 * this.items[index].reductionGrams / scale;
    };

    // Soft area under the line, so the trend reads as a shape rather than a wire.
    ctx.beginPath();
    ctx.moveTo(xAt(0), baseline);
    for (let i = 0; i < this.items.length; i++) {
      ctx.lineTo(xAt(i), yAt(i));
    }
    ctx.lineTo(xAt(this.items.length - 1), baseline);
    ctx.closePath();
    ctx.fillStyle = '#EEF3DC';
    ctx.fill();

    // Wide, pale under-stroke gives the line a subtle glow on hardware rendering.
    ctx.strokeStyle = '#D5E4C0';
    ctx.lineWidth = 5;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    for (let i = 0; i < this.items.length; i++) {
      if (i === 0) { ctx.moveTo(xAt(i), yAt(i)); } else { ctx.lineTo(xAt(i), yAt(i)); }
    }
    ctx.stroke();

    ctx.strokeStyle = '#2E6A4F';
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (let i = 0; i < this.items.length; i++) {
      if (i === 0) { ctx.moveTo(xAt(i), yAt(i)); } else { ctx.lineTo(xAt(i), yAt(i)); }
    }
    ctx.stroke();

    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].recordCount > 0) {
        const x = xAt(i);
        const y = yAt(i);
        ctx.fillStyle = '#D9F26E';
        ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = '#2E6A4F';
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2); ctx.stroke();
      }
    }
  }

  build() {
    Canvas(this.context).width('100%').height(100)
      .onReady(() => { this.ready = true; this.redraw(); })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.canvasWidth = Number(newArea.width);
        this.redraw();
      })
  }
}

@Component
export struct PositivePieChart {
  @Prop @Watch('redraw') items: StatisticsItem[] = [];
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;

  private redraw(): void {
    if (!this.ready) { return; }
    const ctx = this.context;
    ctx.clearRect(0, 0, 120, 120);
    let total = 0;
    this.items.forEach((item: StatisticsItem) => { total += item.positiveReductionGrams; });
    if (total <= 0) { return; }
    let angle = -Math.PI / 2;
    for (let i = 0; i < this.items.length; i++) {
      const value = this.items[i].positiveReductionGrams;
      if (value > 0) {
        const end = angle + Math.PI * 2 * value / total;
        ctx.fillStyle = CHART_COLORS[i % CHART_COLORS.length];
        ctx.beginPath(); ctx.moveTo(60, 60); ctx.arc(60, 60, 52, angle, end); ctx.closePath(); ctx.fill();
        angle = end;
      }
    }
    ctx.fillStyle = '#FDFBF2';
    ctx.beginPath(); ctx.arc(60, 60, 34, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#EEF2E2';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(60, 60, 52, 0, Math.PI * 2); ctx.stroke();
  }

  build() {
    Canvas(this.context).width(120).height(120).onReady(() => { this.ready = true; this.redraw(); })
  }
}
