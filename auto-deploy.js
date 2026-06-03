#!/usr/bin/env node
import { watch } from 'node:fs';
import { basename, extname, resolve } from 'node:path';
import { spawn } from 'node:child_process';

const ROOT = process.cwd();
const WATCH_EXTS = new Set([
  '.html',
  '.css',
  '.js',
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
  '.svg',
  '.mp3',
  '.wav',
  '.txt',
  '.json',
  '.css',
]);

function isIgnored(filePath) {
  if (!filePath) return true;
  if (filePath.startsWith('.git')) return true;
  if (filePath.startsWith('node_modules')) return true;
  if (filePath.startsWith('.DS_Store')) return true;
  if (filePath.startsWith('deploy.sh')) return true;
  if (filePath.startsWith('.netlify')) return true;
  if (filePath.startsWith('.tmp')) return true;

  const ext = extname(filePath).toLowerCase();
  return WATCH_EXTS.size > 0 ? !WATCH_EXTS.has(ext) : false;
}

let deployTimer = null;
let deploying = false;
let pending = false;

function runDeploy() {
  if (deploying) {
    pending = true;
    return;
  }

  deploying = true;
  console.log(`[auto-deploy] 开始部署 @ ${new Date().toLocaleTimeString()}`);

  const child = spawn('sh', ['deploy.sh'], {
    stdio: 'inherit',
    cwd: ROOT,
    shell: false,
  });

  child.on('close', (code) => {
    if (code === 0) {
      console.log('[auto-deploy] 本次部署完成');
    } else {
      console.warn(`[auto-deploy] 本次部署失败，退出码 ${code}`);
    }
    deploying = false;
    if (pending) {
      pending = false;
      runDeploy();
    }
  });
}

function scheduleDeploy(filePath) {
  if (isIgnored(filePath)) return;

  const name = basename(filePath || '');
  console.log(`[auto-deploy] 检测到变更: ${name}`);

  if (deployTimer) clearTimeout(deployTimer);
  deployTimer = setTimeout(() => {
    runDeploy();
  }, 1000);
}

try {
  const watcher = watch(
    ROOT,
    { recursive: true },
    (eventType, filePath) => {
      if (filePath && filePath.startsWith('.')) {
        const normalized = filePath.replace(/^\.\//, '');
        scheduleDeploy(normalized);
        return;
      }
      if (!filePath) return;
      scheduleDeploy(filePath);
    },
  );

  watcher.on('error', (error) => {
    console.error('[auto-deploy] 监听失败，请手动运行 sh deploy.sh', error.message);
    process.exit(1);
  });

  console.log('[auto-deploy] 已启动：监听文件变更并自动部署到 Netlify');
  console.log('[auto-deploy] 你可以正常编辑项目，保存后自动触发部署');
} catch (error) {
  console.error('[auto-deploy] 监听器初始化失败：', error.message);
  process.exit(1);
}
