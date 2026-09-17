#!/usr/bin/env node
'use strict';

/**
 * dev-env-bootstrap 主入口
 *
 * 自动识别操作系统并调用对应的平台初始化脚本：
 *   macOS   -> scripts/setup-macos.sh     （Homebrew + rustup + npm）
 *   Windows -> scripts/setup-windows.ps1  （本地安装包 / winget + npm）
 */
const { spawn } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

/** 运行子进程，透传输出，返回退出码 */
function run(command, args) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: 'inherit' });
    child.on('error', (err) => {
      console.error(`[dev-env-bootstrap] 无法启动脚本: ${err.message}`);
      resolve(1);
    });
    child.on('exit', (code) => resolve(code ?? 1));
  });
}

async function main() {
  const scriptsDir = path.join(__dirname, 'scripts');
  const platform = process.platform;

  if (platform === 'darwin') {
    const script = path.join(scriptsDir, 'setup-macos.sh');
    if (!fs.existsSync(script)) {
      console.error(`[dev-env-bootstrap] 未找到脚本: ${script}`);
      process.exitCode = 1;
      return;
    }
    process.exitCode = await run('/bin/bash', [script]);
  } else if (platform === 'win32') {
    const script = path.join(scriptsDir, 'setup-windows.ps1');
    if (!fs.existsSync(script)) {
      console.error(`[dev-env-bootstrap] 未找到脚本: ${script}`);
      process.exitCode = 1;
      return;
    }
    process.exitCode = await run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script,
    ]);
  } else {
    console.error(`[dev-env-bootstrap] 不支持的操作系统: ${platform}`);
    console.error('dev-env-bootstrap 仅支持 macOS 与 Windows。');
    process.exitCode = 1;
  }
}

main();
