import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { createDeflateZip, validateOfflineSource, type PackageFile } from "./package_lib.ts";

const ROOT = resolve(import.meta.dir, "..");
const SOURCE_DIR = import.meta.dir;
const OUTPUT_DIR = resolve(Bun.env.BAIDU_OUT_DIR ?? `${ROOT}/game/build/baidu-h5`);
const ZIP_PATH = `${OUTPUT_DIR}/yongchang-baidu-h5.zip`;
const SOURCE_FILES = ["index.html", "game.js"];

await mkdir(OUTPUT_DIR, { recursive: true });
const files: PackageFile[] = [];
for (const name of SOURCE_FILES) {
	const source = Bun.file(`${SOURCE_DIR}/${name}`);
	if (!(await source.exists())) throw new Error(`Missing H5 source file: ${name}`);
	files.push({ name, bytes: new Uint8Array(await source.arrayBuffer()) });
}
files.sort((a, b) => a.name.localeCompare(b.name));
const sourceIssues = validateOfflineSource(files);
if (sourceIssues.length) throw new Error(sourceIssues.join("\n"));
const totalBytes = files.reduce((sum, file) => sum + file.bytes.length, 0);
const zip = createDeflateZip(files);
await Bun.write(ZIP_PATH, zip);

const audit = [
	"baidu_h5_package=pass",
	"entry=index.html",
	"orientation=responsive_portrait_preferred_no_rotation_lock",
	"offline=all_required_resources_local",
	"pwa=false",
	"workers=false",
	"host_bridge=false",
	"network_apis=false",
	"custom_text_inputs=false",
	"zip_method=deflate",
	`source_entries=${files.length}`,
	`source_unpacked_bytes=${totalBytes}`,
	...files.map((file) => `${file.name}_bytes=${file.bytes.length}`),
	`source_zip_bytes=${zip.byteLength}`,
	`source_zip_path=${ZIP_PATH}`,
	"runtime_measurement=browser_test_pending",
	"ios_android_webview=not_tested",
].join("\n");
await Bun.write(`${OUTPUT_DIR}/audit.txt`, `${audit}\n`);

const submission = `# 《永昌守灯》百度赛道提交文案\n\n## 作品名\n永昌守灯\n\n## 简介（15字以内）\n移动巡夜，击退来敌，守灯到天明。\n\n## 玩法\n左侧摇杆移动，右侧攻击和冲刺；也可切换自动攻击。守住 60 秒即胜，灯火耗尽则败。支持键盘 WASD / 方向键、J 攻击、Space 冲刺、K 自动攻击。\n\n## 作品形式\n离线自包含 H5，ZIP 根目录为 index.html。所有画面由包内 Canvas 绘制；不请求网络、不使用平台 API、登录、广告或外部资源。\n\n## 体验路径\n开始守夜 → 移动与攻击 → 60 秒胜利或灯火耗尽 → 再守一夜。\n`;
await Bun.write(`${OUTPUT_DIR}/submission-copy.md`, submission);
await Bun.write(`${OUTPUT_DIR}/CREDITS.txt`, `永昌守灯（百度赛道轻量 H5）\n作者：xingwangzhe\n代码：AGPL-3.0-or-later；本仓库根目录 LICENSE 为准。\n画面：代码绘制的原创 Canvas 几何像素风，无外部图片、字体、音频、代码或网络资源。\n生成式 AI：本 H5 版本未使用图像生成模型。\n`);
console.log(audit);
