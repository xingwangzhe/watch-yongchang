#!/usr/bin/env python3
"""通过 CDP 向 Godot Web Canvas 发送真实鼠标/键盘输入与截图。

用法：
  python3 tools/cdp_game_input.py click <design_x> <design_y> [--w 1280 --h 720]
  python3 tools/cdp_game_input.py key <key_name> [--code KEY_C]
  python3 tools/cdp_game_input.py shot <path.png>
  python3 tools/cdp_game_input.py eval "<js>"
  python3 tools/cdp_game_input.py setviewport <width> <height>

设计坐标默认按 1280x720 逻辑视口换算到当前 canvas 实际尺寸。
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

try:
    import websocket  # type: ignore
except ImportError:
    websocket = None

CDP_HTTP = "http://127.0.0.1:{port}"
DESIGN_W = 1280
DESIGN_H = 720


def cdp_json(port: int, path: str):
    with urllib.request.urlopen(CDP_HTTP.format(port=port) + path, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


class CDP:
    def __init__(self, port: int = 9333):
        if websocket is None:
            raise RuntimeError("需要 websocket-client：pip install websocket-client")
        self.port = port
        targets = cdp_json(port, "/json/list")
        page = next((t for t in targets if t.get("type") == "page"), None)
        if page is None:
            raise RuntimeError("没有可连接的页面目标")
        self.ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=30)
        self.msg_id = 0

    def send(self, method: str, params: dict | None = None):
        self.msg_id += 1
        current = self.msg_id
        self.ws.send(json.dumps({"id": current, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == current:
                if "error" in msg:
                    raise RuntimeError(str(msg["error"]))
                return msg.get("result", {})

    def eval(self, expression: str):
        result = self.send("Runtime.evaluate", {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True,
        })
        return result.get("result", {}).get("value")

    def canvas_rect(self):
        value = self.eval("JSON.stringify(document.querySelector('canvas').getBoundingClientRect().toJSON())")
        return json.loads(value)

    def to_client(self, dx: float, dy: float, design_w: int, design_h: int):
        rect = self.canvas_rect()
        return (
            rect["x"] + dx / design_w * rect["width"],
            rect["y"] + dy / design_h * rect["height"],
        )

    def click(self, dx: float, dy: float, design_w: int, design_h: int):
        x, y = self.to_client(dx, dy, design_w, design_h)
        self.send("Input.dispatchMouseEvent", {
            "type": "mouseMoved", "x": x, "y": y, "button": "none", "buttons": 0,
        })
        self.send("Input.dispatchMouseEvent", {
            "type": "mousePressed", "x": x, "y": y, "button": "left", "buttons": 1, "clickCount": 1,
        })
        time.sleep(0.05)
        self.send("Input.dispatchMouseEvent", {
            "type": "mouseReleased", "x": x, "y": y, "button": "left", "buttons": 0, "clickCount": 1,
        })
        return x, y

    def move(self, dx: float, dy: float, design_w: int, design_h: int):
        x, y = self.to_client(dx, dy, design_w, design_h)
        self.send("Input.dispatchMouseEvent", {
            "type": "mouseMoved", "x": x, "y": y, "button": "none", "buttons": 0,
        })
        return x, y

    def key(self, key: str, code: str | None, windows_vk: int | None = None):
        params = {"type": "keyDown", "key": key}
        if code:
            params["code"] = code
        if windows_vk is not None:
            params["windowsVirtualKeyCode"] = windows_vk
            params["nativeVirtualKeyCode"] = windows_vk
        self.send("Input.dispatchKeyEvent", params)
        time.sleep(0.05)
        params["type"] = "keyUp"
        self.send("Input.dispatchKeyEvent", params)

    def shot(self, path: str):
        result = self.send("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": False})
        output = Path(path)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(base64.b64decode(result["data"]))
        return str(output)

    def set_viewport(self, width: int, height: int, mobile: bool = False):
        self.send("Emulation.setDeviceMetricsOverride", {
            "width": width,
            "height": height,
            "deviceScaleFactor": 1,
            "mobile": mobile,
        })
        if mobile:
            self.send("Emulation.setTouchEmulationEnabled", {
                "enabled": True, "maxTouchPoints": 5,
            })

    def clear_viewport(self):
        self.send("Emulation.clearDeviceMetricsOverride")
        self.send("Emulation.setTouchEmulationEnabled", {"enabled": False})

    def close(self):
        self.ws.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=9333)
    parser.add_argument("--w", type=int, default=DESIGN_W, help="设计视口宽度")
    parser.add_argument("--h", type=int, default=DESIGN_H, help="设计视口高度")
    sub = parser.add_subparsers(dest="command", required=True)
    p_click = sub.add_parser("click")
    p_click.add_argument("x", type=float)
    p_click.add_argument("y", type=float)
    p_move = sub.add_parser("move")
    p_move.add_argument("x", type=float)
    p_move.add_argument("y", type=float)
    p_key = sub.add_parser("key")
    p_key.add_argument("name")
    p_key.add_argument("--code", default=None)
    p_key.add_argument("--vk", type=int, default=None)
    p_shot = sub.add_parser("shot")
    p_shot.add_argument("path")
    p_eval = sub.add_parser("eval")
    p_eval.add_argument("expression")
    p_view = sub.add_parser("setviewport")
    p_view.add_argument("width", type=int)
    p_view.add_argument("height", type=int)
    p_view.add_argument("--mobile", action="store_true")
    sub.add_parser("clearviewport")
    args = parser.parse_args()

    cdp = CDP(args.port)
    try:
        if args.command == "click":
            print(json.dumps({"client": cdp.click(args.x, args.y, args.w, args.h)}))
        elif args.command == "move":
            print(json.dumps({"client": cdp.move(args.x, args.y, args.w, args.h)}))
        elif args.command == "key":
            cdp.key(args.name, args.code, args.vk)
            print("ok")
        elif args.command == "shot":
            print(cdp.shot(args.path))
        elif args.command == "eval":
            print(cdp.eval(args.expression))
        elif args.command == "setviewport":
            cdp.set_viewport(args.width, args.height, args.mobile)
            print("ok")
        elif args.command == "clearviewport":
            cdp.clear_viewport()
            print("ok")
    finally:
        cdp.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        raise
