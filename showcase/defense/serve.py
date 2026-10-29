#!/usr/bin/env python3
"""
碳小步 · 答辩演示桥

作用：把 HarmonyOS 模拟器的实时画面嵌进 HTML 演示稿，并把网页上的点击/滑动
     转发回模拟器。这样演示稿全屏也不会挡住模拟器，因为模拟器就在网页里。

用法：
    python3 serve.py              # 启动并自动打开浏览器
    PORT=8777 python3 serve.py    # 指定端口

依赖：Python 3.8+（macOS 自带）、DevEco 的 hdc、已启动的模拟器。
只用标准库，不需要 pip 安装任何东西。
"""

import json
import os
import shutil
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("PORT", "8777"))

# 模拟器逻辑分辨率（截图原始尺寸），用于把网页坐标换算成设备坐标
DEV_W = int(os.environ.get("DEV_W", "1320"))
DEV_H = int(os.environ.get("DEV_H", "2232"))

# 抓帧分辨率
CAP_W = int(os.environ.get("CAP_W", "660"))
CAP_H = int(round(CAP_W * DEV_H / DEV_W))

# 并发抓帧路数。单路约 9fps，模拟器端可并行：
# 1→9  2→16  4→27  6→34  8→36 fps。
# 实测 3 路与 5 路下操作注入耗时几乎相同（0.46s vs 0.47s），
# 说明瓶颈在注入本身而非 CPU 争抢，因此取 6 路换更高帧率。
WORKERS = int(os.environ.get("WORKERS", "6"))

TARGET = os.environ.get("HDC_TARGET", "127.0.0.1:5555")
BUNDLE = os.environ.get("BUNDLE", "com.carbonfootprint.app")
ABILITY = os.environ.get("ABILITY", "EntryAbility")


def find_hdc():
    candidates = [
        os.environ.get("HDC"),
        "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc",
        os.path.expanduser("~/Library/OpenHarmony/Sdk/12/toolchains/hdc"),
        shutil.which("hdc"),
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return "hdc"


HDC = find_hdc()


class Capture:
    """多路并发抓帧：每路独立抓取，按采集时间戳去重，只保留最新一帧。"""

    def __init__(self):
        self.cv = threading.Condition()
        self.frame = None
        self.seq = 0
        self.ts = 0.0
        self.fps = 0.0
        self.ok = False
        self.error = ""
        self.running = True
        self.paused = False
        self.accepted = 0

    def hdc(self, args, timeout=15):
        return subprocess.run(
            [HDC, "-t", TARGET] + args,
            capture_output=True, timeout=timeout
        )

    def worker(self, idx):
        tmp = f"/data/local/tmp/_deck_{idx}.jpeg"
        cmd = (f"snapshot_display -w {CAP_W} -h {CAP_H} -f {tmp} "
               f">/dev/null 2>&1; cat {tmp}")
        while self.running:
            if self.paused:
                time.sleep(0.05)
                continue
            started = time.time()
            try:
                p = self.hdc(["shell", cmd])
                data = p.stdout
                if data[:2] == b"\xff\xd8" and len(data) > 2000:
                    with self.cv:
                        # 只接受比当前帧更新的采集结果，避免画面倒退
                        if started > self.ts:
                            self.ts = started
                            self.frame = data
                            self.seq += 1
                            self.ok = True
                            self.error = ""
                            self.accepted += 1
                            self.cv.notify_all()
                else:
                    with self.cv:
                        self.ok = False
                        self.error = "抓帧失败"
                    time.sleep(0.3)
            except subprocess.TimeoutExpired:
                with self.cv:
                    self.ok = False
                    self.error = "hdc 超时"
                time.sleep(0.4)
            except Exception as e:  # noqa: BLE001
                with self.cv:
                    self.ok = False
                    self.error = str(e)[:80]
                time.sleep(0.4)

    def fps_loop(self):
        last = 0
        while self.running:
            time.sleep(1.0)
            with self.cv:
                n = self.accepted
            self.fps = float(n - last)
            last = n

    def keep_awake(self):
        """长时间不操作时避免模拟器息屏，导致投屏变黑。"""
        while self.running:
            time.sleep(45)
            try:
                self.hdc(["shell", "power-shell wakeup"], timeout=8)
            except Exception:  # noqa: BLE001
                pass

    def start(self):
        for i in range(WORKERS):
            threading.Thread(target=self.worker, args=(i,), daemon=True).start()
        threading.Thread(target=self.fps_loop, daemon=True).start()
        threading.Thread(target=self.keep_awake, daemon=True).start()

    def wait_frame(self, last, timeout=5.0):
        with self.cv:
            self.cv.wait_for(lambda: self.seq != last, timeout=timeout)
            return self.seq, self.frame


CAP = Capture()


def tap(x, y):
    return CAP.hdc(["shell", f"uitest uiInput click {int(x)} {int(y)}"])


# 一次滚动手势最多走多远（设备像素），约等于一屏
SCROLL_STEP = 760


def scroll_by(dy):
    """按位移量做一次竖直拖拽。dy>0 表示内容上移（手指上滑）。

    用 uinput 分三步模拟「按下-移动-抬起」，而不是 uitest drag：
    uitest 每次要约 2 秒（它在等界面稳定），uinput 只要约 0.6 秒，
    而且分步移动会被 ArkUI 正确识别成滚动手势，不会误判成点击。
    """
    mag = int(min(abs(dy), SCROLL_STEP))
    if mag < 30:
        return
    half = mag // 2
    cx = DEV_W // 2
    cy = DEV_H // 2
    y1, y2 = (cy + half, cy - half) if dy > 0 else (cy - half, cy + half)
    # 移动时长决定"抬手速度"：太快会被判成轻扫并带出惯性甩动。
    # 实测 450px/s 约 1.1 倍、1000px/s 约 1.6~2 倍、1800px/s 约 4.4 倍。
    # 这里固定约 650px/s：甩动倍率稳定在 1.2 上下，位移基本可控，
    # 又不像 550px/s 那样慢到 1 秒一次。
    dur = int(max(150, min(600, mag / 0.65)))
    cmd = (f"uinput -S -d {cx} {y1}; "
           f"uinput -S -m {cx} {y1} {cx} {y2} {dur}; "
           f"uinput -S -u {cx} {y2}")
    CAP.hdc(["shell", cmd], timeout=8)


class ScrollQueue:
    """同一时刻只跑一个滚动手势，期间收到的滚动合并成下一次。

    这是流畅度的关键：uitest 每注入一次手势要约 2 秒才返回（它在等界面稳定），
    如果每条滚动都排队，用户停手后画面还会继续补滚十几秒。
    """

    def __init__(self):
        self.cv = threading.Condition()
        self.pending = 0
        self.busy = False
        threading.Thread(target=self.loop, daemon=True).start()

    def add(self, dy):
        with self.cv:
            # 上限压到一屏：避免连续输入被累加成"一次翻好几页"
            self.pending = max(-SCROLL_STEP, min(SCROLL_STEP,
                                                 self.pending + int(dy)))
            self.cv.notify()

    def loop(self):
        while True:
            with self.cv:
                while self.pending == 0:
                    self.cv.wait()
                dy = self.pending
                self.pending = 0
            self.busy = True
            try:
                scroll_by(dy)
            except Exception:  # noqa: BLE001
                pass
            finally:
                self.busy = False


SCROLL = ScrollQueue()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    disable_nagle_algorithm = True

    def log_message(self, fmt, *args):  # 安静一点
        if os.environ.get("VERBOSE"):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # ---------- 工具 ----------
    def _send(self, code, body=b"", ctype="text/plain; charset=utf-8"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj).encode(), "application/json")

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n).decode() or "{}")
        except Exception:  # noqa: BLE001
            return {}

    # ---------- 路由 ----------
    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            fp = os.path.join(HERE, "index.html")
            with open(fp, "rb") as f:
                self._send(200, f.read(), "text/html; charset=utf-8")
            return
        if path == "/stream":
            self.stream()
            return
        if path == "/state":
            self._json({
                "ok": CAP.ok, "fps": round(CAP.fps, 1),
                "w": DEV_W, "h": DEV_H, "cap": [CAP_W, CAP_H], "workers": WORKERS,
                "error": CAP.error,
            })
            return
        self._send(404, b"not found")

    def do_POST(self):
        path = self.path.split("?")[0]
        d = self._body()
        try:
            if path == "/tap":
                tap(d.get("x", 0), d.get("y", 0))
                self._json({"ok": True})
                return
            if path == "/scroll":
                SCROLL.add(d.get("dy", 0))
                self._json({"ok": True})
                return
            if path == "/swipe":
                SCROLL.add(d.get("y2", 0) - d.get("y1", 0))
                self._json({"ok": True})
                return
            if path == "/restart":
                CAP.paused = True
                CAP.hdc(["shell", f"aa force-stop {BUNDLE}"])
                time.sleep(0.3)
                CAP.hdc(["shell", f"aa start -a {ABILITY} -b {BUNDLE}"])
                CAP.paused = False
                self._json({"ok": True})
                return
        except Exception as e:  # noqa: BLE001
            self._json({"ok": False, "error": str(e)[:120]}, 500)
            return
        self._send(404, b"not found")

    def stream(self):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
        self.send_header("Cache-Control", "no-store, no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        last = 0
        try:
            while True:
                seq, data = CAP.wait_frame(last, timeout=5.0)
                if data is None or seq == last:
                    continue
                last = seq
                self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\n")
                self.wfile.write(b"Content-Length: " + str(len(data)).encode() + b"\r\n\r\n")
                self.wfile.write(data)
                self.wfile.write(b"\r\n")
        except (BrokenPipeError, ConnectionResetError):
            return


def main():
    if not os.path.exists(os.path.join(HERE, "index.html")):
        sys.exit("找不到 index.html，请把 serve.py 和 index.html 放在同一目录")

    print(f"hdc       : {HDC}")
    print(f"target    : {TARGET}")
    print(f"capture   : {CAP_W}×{CAP_H}  (device {DEV_W}×{DEV_H})  ×{WORKERS} 路并发")

    try:
        out = subprocess.run([HDC, "list", "targets"], capture_output=True, timeout=8)
        targets = out.stdout.decode(errors="ignore").strip()
        print(f"targets   : {targets or '(空)'}")
        if TARGET not in targets:
            print("⚠️  没有看到目标设备。请先启动模拟器，再重新运行本脚本。")
    except Exception as e:  # noqa: BLE001
        print(f"⚠️  hdc 检查失败：{e}")

    CAP.start()

    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    srv.daemon_threads = True
    url = f"http://127.0.0.1:{PORT}/"
    print(f"\n演示地址   : {url}")
    print("Ctrl+C 结束\n")
    try:
        webbrowser.open(url)
    except Exception:  # noqa: BLE001
        pass
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")
        CAP.running = False
        srv.shutdown()


if __name__ == "__main__":
    main()
