#!/usr/bin/env npx tsx
/**
 * 단일 이미지 생성 래퍼.
 * Usage: npx tsx generate.ts "이미지 설명" [--resolution 1K|4K] [--output-dir ./path]
 */
import { generateImage } from '/Users/glen/Desktop/work/glen-contents-creator/src/core/image-gen.ts';

const args = process.argv.slice(2);
if (args.length === 0 || args[0] === '--help') {
  console.log('Usage: npx tsx generate.ts "설명" [--resolution 1K|4K] [--output-dir ./path]');
  process.exit(0);
}

// 첫 번째 non-flag 인자 = description
let description = '';
let resolution: '1K' | '4K' = '1K';
let outputDir = process.cwd();

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--resolution' && args[i + 1]) {
    resolution = args[++i] as '1K' | '4K';
  } else if (args[i] === '--output-dir' && args[i + 1]) {
    outputDir = args[++i];
  } else if (!args[i].startsWith('--')) {
    description = args[i];
  }
}

if (!description) {
  console.error('Error: 이미지 설명이 필요합니다.');
  process.exit(1);
}

const filePath = await generateImage(description, outputDir, resolution);
console.log(JSON.stringify({ filePath, description, resolution }));
