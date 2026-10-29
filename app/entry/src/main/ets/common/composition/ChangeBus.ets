import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChangeListener, ChangeNotifier, Unsubscribe } from '../contracts/Common';

export class ChangeBus implements ChangeNotifier {
  private listeners: Set<ChangeListener> = new Set<ChangeListener>();

  subscribe(listener: ChangeListener): Unsubscribe {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  notifyDataChanged(): void {
    const current = Array.from(this.listeners);
    current.forEach((listener: ChangeListener) => {
      try {
        listener();
      } catch (error) {
        hilog.error(0x0000, 'AppChanges', 'Data-change listener failed: %{public}s', (error as Error).message);
      }
    });
  }
}
