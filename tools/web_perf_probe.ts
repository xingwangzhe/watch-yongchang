import { writeFile } from "node:fs/promises";

const port = Number(process.env.CDP_PORT ?? "9333");
const pageMatch = process.env.WEB_PAGE_MATCH ?? "127.0.0.1:8788";
const tabs = await fetch(`http://127.0.0.1:${port}/json/list`).then((response) => response.json()) as Array<{
  id: string;
  title: string;
  type: string;
  url: string;
  webSocketDebuggerUrl: string;
}>;
const page = tabs.find((entry) => entry.type === "page" && entry.url.includes(pageMatch));
if (!page) throw new Error(`No page matching ${pageMatch}`);

const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise<void>((resolve, reject) => {
  socket.addEventListener("open", () => resolve(), { once: true });
  socket.addEventListener("error", () => reject(new Error("CDP socket failed")), { once: true });
});

let sequence = 0;
const pending = new Map<number, { resolve: (value: any) => void; reject: (error: Error) => void }>();
const consoleMessages: Array<{ type: string; text: string }> = [];
socket.addEventListener("message", (event) => {
  const message = JSON.parse(String(event.data));
  if (message.method === "Runtime.consoleAPICalled") {
    consoleMessages.push({
      type: message.params.type,
      text: (message.params.args ?? [])
        .map((arg: { value?: unknown; description?: string }) =>
          String(arg.value ?? arg.description ?? "")
        )
        .join(" "),
    });
  }
  const entry = pending.get(message.id);
  if (!entry) return;
  pending.delete(message.id);
  if (message.error) entry.reject(new Error(JSON.stringify(message.error)));
  else entry.resolve(message.result);
});

function command(method: string, params: Record<string, unknown> = {}, timeoutMs = 30000): Promise<any> {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`${method} timeout`));
    }, timeoutMs);
    pending.set(id, {
      resolve: (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      reject: (error) => {
        clearTimeout(timer);
        reject(error);
      },
    });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression: string, timeoutMs = 30000): Promise<any> {
  const result = await command("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
    userGesture: true,
  }, timeoutMs);
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text ?? "Evaluation failed");
  return result.result?.value ?? result;
}

async function screenshot(path: string): Promise<void> {
  const result = await command("Page.captureScreenshot", { format: "png" });
  await writeFile(path, Buffer.from(result.data, "base64"));
}

async function metricsSnapshot(): Promise<Record<string, number>> {
  const result = await command("Performance.getMetrics");
  return Object.fromEntries(result.metrics.map((entry: { name: string; value: number }) => [entry.name, entry.value]));
}

function sampleExpression(seconds: number): string {
  return `(async()=>{
    const intervals=[];
    let frames=0;
    const start=performance.now();
    let last=start;
    await new Promise(resolve=>{
      function tick(now){
        if(frames>0) intervals.push(now-last);
        last=now;
        frames++;
        if(now-start<${seconds * 1000}) requestAnimationFrame(tick);
        else resolve();
      }
      requestAnimationFrame(tick);
    });
    const duration=performance.now()-start;
    const sorted=[...intervals].sort((a,b)=>a-b);
    const quantile=p=>sorted.length?sorted[Math.min(sorted.length-1,Math.floor((sorted.length-1)*p))]:null;
    const canvas=document.querySelector('canvas');
    const gl=canvas?(canvas.getContext('webgl2')||canvas.getContext('webgl')):null;
    const debug=gl?gl.getExtension('WEBGL_debug_renderer_info'):null;
    return {
      frames,
      duration_ms:duration,
      fps:frames*1000/duration,
      p50_ms:quantile(.5),
      p90_ms:quantile(.9),
      p95_ms:quantile(.95),
      p99_ms:quantile(.99),
      max_ms:sorted.at(-1)??null,
      over25:sorted.filter(value=>value>25).length,
      over50:sorted.filter(value=>value>50).length,
      over100:sorted.filter(value=>value>100).length,
      canvas:canvas?[canvas.width,canvas.height]:null,
      css:canvas?[canvas.clientWidth,canvas.clientHeight]:null,
      dpr:devicePixelRatio,
      visibility:document.visibilityState,
      focused:document.hasFocus(),
      webgl2:!!(gl&&self.WebGL2RenderingContext&&gl instanceof WebGL2RenderingContext),
      renderer:gl&&debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):null
    };
  })()`;
}

await command("Page.bringToFront");
await command("Emulation.setFocusEmulationEnabled", { enabled: true });
await new Promise((resolve) => setTimeout(resolve, 300));
const [action, ...args] = process.argv.slice(2);

if (action === "click") {
  const x = Number(args[0]);
  const y = Number(args[1]);
  const output = args[2] ?? "";
  await command("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await command("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
  await command("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, 800));
  if (output) await screenshot(output);
  console.log(JSON.stringify({ action, x, y, output: output || null }));
} else if (action === "click-metrics") {
  const x = Number(args[0]);
  const y = Number(args[1]);
  const seconds = Number(args[2] ?? "6");
  const output = args[3] ?? "";
  await command("Performance.enable");
  await command("Runtime.enable");
  await evaluate(`(() => {
    const probe = { start: performance.now(), frames: [], done: false };
    window.__clickProbe = probe;
    function frame(now) {
      probe.frames.push(now - probe.start);
      if (now - probe.start < ${seconds * 1000}) requestAnimationFrame(frame);
      else probe.done = true;
    }
    requestAnimationFrame(frame);
    return true;
  })()`);
  const before = await metricsSnapshot();
  await command("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  await command("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
  await command("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  const after = await metricsSnapshot();
  const probe = await evaluate("window.__clickProbe");
  const frames: number[] = probe?.frames ?? [];
  const intervals = frames.slice(1).map((frame, index) => frame - frames[index]);
  const sorted = [...intervals].sort((left, right) => left - right);
  const spikes = intervals
    .map((duration, index) => ({ at_ms: frames[index + 1], duration_ms: duration }))
    .filter((entry) => entry.duration_ms > 40)
    .sort((left, right) => right.duration_ms - left.duration_ms)
    .slice(0, 12);
  const quantile = (ratio: number) =>
    sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor((sorted.length - 1) * ratio))] : null;
  const delta = Object.fromEntries(
    Object.keys(after)
      .filter((name) => name in before)
      .map((name) => [name, after[name] - before[name]]),
  );
  if (output) await screenshot(output);
  console.log(JSON.stringify({
    action,
    x,
    y,
    seconds,
    frames: frames.length,
    first_frame_ms: frames[0] ?? null,
    p50_ms: quantile(0.5),
    p95_ms: quantile(0.95),
    p99_ms: quantile(0.99),
    max_ms: sorted.at(-1) ?? null,
    over50: sorted.filter((value) => value > 50).length,
    over100: sorted.filter((value) => value > 100).length,
    spikes,
    script_ms: (delta.ScriptDuration ?? 0) * 1000,
    task_ms: (delta.TaskDuration ?? 0) * 1000,
    console: consoleMessages.slice(-40),
    output: output || null,
  }, null, 2));
} else if (action === "sample") {
  const seconds = Number(args[0] ?? "5");
  const output = args[1] ?? "";
  console.log(JSON.stringify(await evaluate(sampleExpression(seconds), seconds * 1000 + 15000), null, 2));
  if (output) await screenshot(output);
} else if (action === "hold") {
  const key = args[0] ?? "d";
  const code = args[1] ?? "KeyD";
  const virtualKey = Number(args[2] ?? "68");
  const seconds = Number(args[3] ?? "5");
  const output = args[4] ?? "";
  await command("Input.dispatchKeyEvent", {
    type: "keyDown",
    key,
    code,
    windowsVirtualKeyCode: virtualKey,
    nativeVirtualKeyCode: virtualKey,
  });
  console.log(JSON.stringify(await evaluate(sampleExpression(seconds), seconds * 1000 + 15000), null, 2));
  await command("Input.dispatchKeyEvent", {
    type: "keyUp",
    key,
    code,
    windowsVirtualKeyCode: virtualKey,
    nativeVirtualKeyCode: virtualKey,
  });
  if (output) await screenshot(output);
} else if (action === "metrics") {
  const seconds = Number(args[0] ?? "5");
  const key = args[1] ?? "";
  const code = args[2] ?? "";
  const virtualKey = Number(args[3] ?? "0");
  await command("Performance.enable");
  const before = await metricsSnapshot();
  if (key) {
    await command("Input.dispatchKeyEvent", {
      type: "keyDown",
      key,
      code,
      windowsVirtualKeyCode: virtualKey,
      nativeVirtualKeyCode: virtualKey,
    });
  }
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  if (key) {
    await command("Input.dispatchKeyEvent", {
      type: "keyUp",
      key,
      code,
      windowsVirtualKeyCode: virtualKey,
      nativeVirtualKeyCode: virtualKey,
    });
  }
  const after = await metricsSnapshot();
  const delta = Object.fromEntries(
    Object.keys(after)
      .filter((name) => name in before)
      .map((name) => [name, after[name] - before[name]]),
  );
  console.log(JSON.stringify({ seconds, key: key || null, delta }, null, 2));
} else if (action === "profile") {
  const seconds = Number(args[0] ?? "5");
  await command("Profiler.enable");
  await command("Profiler.setSamplingInterval", { interval: 200 });
  await command("Profiler.start");
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  const profile = await command("Profiler.stop");
  const nodes = new Map<number, { name: string; url: string; line: number; parent: number }>();
  for (const node of profile.profile.nodes) {
    nodes.set(node.id, {
      name: node.callFrame.functionName || "(anonymous)",
      url: node.callFrame.url || "",
      line: node.callFrame.lineNumber ?? -1,
      parent: node.parent ?? 0,
    });
  }
  const totals = new Map<number, number>();
  for (let index = 0; index < profile.profile.samples.length; index++) {
    const id = profile.profile.samples[index];
    totals.set(id, (totals.get(id) ?? 0) + Math.max(0, profile.profile.timeDeltas[index] ?? 0));
  }
  const top = [...totals.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, 40)
    .map(([id, microseconds]) => {
      const stack = [];
      let current = id;
      for (let depth = 0; current && depth < 8; depth++) {
        const node = nodes.get(current);
        if (!node) break;
        stack.push(`${node.name}@${node.url}:${node.line}`);
        current = node.parent;
      }
      const node = nodes.get(id);
      return { microseconds, name: node?.name, url: node?.url, line: node?.line, stack };
    });
  console.log(JSON.stringify({ seconds, top }, null, 2));
} else if (action === "viewport") {
  const width = Number(args[0]);
  const height = Number(args[1]);
  const scale = Number(args[2] ?? "1");
  await command("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: scale,
    mobile: false,
  });
  await new Promise((resolve) => setTimeout(resolve, 800));
  console.log(JSON.stringify({ width, height, scale }));
} else if (action === "clear-viewport") {
  await command("Emulation.clearDeviceMetricsOverride");
  await new Promise((resolve) => setTimeout(resolve, 800));
  console.log(JSON.stringify({ action }));
} else if (action === "eval") {
  console.log(JSON.stringify(await evaluate(args.join(" ")), null, 2));
} else {
  throw new Error("Usage: web_perf_probe.ts <click|sample|hold|eval> ...");
}

socket.close();
