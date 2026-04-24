#!/usr/bin/env npx tsx
/**
 * 단일 이미지 생성 — self-contained (외부 lib 의존 없음).
 * Providers: gemini (default), openai
 *
 * Usage:
 *   npx tsx generate.ts "설명" [--provider gemini|openai]
 *                              [--quality standard|high]
 *                              [--aspect square|portrait|landscape]
 *                              [--resolution 1K|4K]          (legacy alias for --quality, gemini only)
 *                              [--transparent]               (openai only)
 *                              [--reference <path>]          (image edit mode)
 *                              [--output-dir ./path]
 */
import 'dotenv/config';
import { GoogleGenAI } from '@google/genai';
import OpenAI, { toFile } from 'openai';
import fs from 'node:fs/promises';
import path from 'node:path';

type Provider = 'gemini' | 'openai';
type Quality = 'standard' | 'high';
type Aspect = 'square' | 'portrait' | 'landscape';

interface GenerateOptions {
  description: string;
  provider: Provider;
  quality: Quality;
  aspect: Aspect;
  transparent: boolean;
  reference?: string;
  outputDir: string;
}

interface GenerateResult {
  filePath: string;
  description: string;
  provider: Provider;
  model: string;
  quality: Quality;
  aspect: Aspect;
  edited: boolean;
}

const BASE_PROMPT = [
  '한국어로 작성된 설명을 바탕으로, 교육용 문서에 넣을 수 있는 깔끔한 인포그래픽/다이어그램 스타일 이미지를 생성한다.',
  '이미지 안의 텍스트는 "기본 한글 + 일부 영어(키워드/라벨)"로 구성한다.',
  '- 한글 70~90%, 영어 10~30% (예: BM25, AST, MCP, locate/expand, tokens-to-complete 등은 영어 유지)',
  '- 문장형 설명 금지: 라벨/짧은 구문만',
  '- 로고/워터마크 금지, 과도한 텍스트 금지, 산세리프 폰트 느낌',
].join('\n');

function nowStamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}-${pad(d.getHours())}-${pad(d.getMinutes())}-${pad(d.getSeconds())}`;
}

function safeSlug(s: string): string {
  return (s || 'image')
    .replace(/[^a-zA-Z0-9가-힣]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 60) || 'image';
}

function buildOutputPath(description: string, outputDir: string, ext = '.png'): string {
  const slug = safeSlug(description);
  const filename = `${nowStamp()}-${slug}${ext}`;
  return path.join(outputDir, filename);
}

function detectMimeType(refPath: string): string {
  const ext = path.extname(refPath).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.webp') return 'image/webp';
  if (ext === '.gif') return 'image/gif';
  return 'image/png';
}

function extFromMimeType(mimeType?: string): string {
  if (!mimeType) return '.png';
  const mt = mimeType.toLowerCase();
  if (mt.includes('jpeg') || mt.includes('jpg')) return '.jpg';
  if (mt.includes('webp')) return '.webp';
  if (mt.includes('gif')) return '.gif';
  return '.png';
}

// ─────────────────────────────────────────────────────────────
// Gemini
// ─────────────────────────────────────────────────────────────

function geminiAspectRatio(aspect: Aspect): '1:1' | '9:16' | '16:9' {
  if (aspect === 'portrait') return '9:16';
  if (aspect === 'landscape') return '16:9';
  return '1:1';
}

function geminiImageSize(quality: Quality): '1K' | '4K' {
  return quality === 'high' ? '4K' : '1K';
}

async function generateWithGemini(opts: GenerateOptions): Promise<GenerateResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY 환경변수가 필요합니다');

  const ai = new GoogleGenAI({ apiKey });
  const model = 'gemini-3.1-flash-image-preview';
  const prompt = `${BASE_PROMPT}\n주제: ${opts.description}`;

  const parts: Array<Record<string, unknown>> = [{ text: prompt }];

  if (opts.reference) {
    const buf = await fs.readFile(opts.reference);
    parts.unshift({
      inlineData: {
        mimeType: detectMimeType(opts.reference),
        data: buf.toString('base64'),
      },
    });
  }

  const response = await ai.models.generateContent({
    model,
    contents: [{ role: 'user', parts: parts as never }],
    config: {
      responseModalities: ['TEXT', 'IMAGE'],
      imageConfig: {
        imageSize: geminiImageSize(opts.quality),
        aspectRatio: geminiAspectRatio(opts.aspect),
      },
    },
  });

  const respParts = response.candidates?.[0]?.content?.parts ?? [];
  for (const part of respParts) {
    if (part.inlineData?.data) {
      await fs.mkdir(opts.outputDir, { recursive: true });
      const ext = extFromMimeType(part.inlineData.mimeType);
      const outputPath = buildOutputPath(opts.description, opts.outputDir, ext);
      const buffer = Buffer.from(part.inlineData.data, 'base64');
      await fs.writeFile(outputPath, buffer);
      return {
        filePath: outputPath,
        description: opts.description,
        provider: 'gemini',
        model,
        quality: opts.quality,
        aspect: opts.aspect,
        edited: Boolean(opts.reference),
      };
    }
  }

  throw new Error(`Gemini 이미지 생성 실패: ${opts.description}`);
}

// ─────────────────────────────────────────────────────────────
// OpenAI
// ─────────────────────────────────────────────────────────────

function openAiSize(aspect: Aspect): '1024x1024' | '1024x1536' | '1536x1024' {
  if (aspect === 'portrait') return '1024x1536';
  if (aspect === 'landscape') return '1536x1024';
  return '1024x1024';
}

function openAiQuality(quality: Quality): 'medium' | 'high' {
  return quality === 'high' ? 'high' : 'medium';
}

async function generateWithOpenAI(opts: GenerateOptions): Promise<GenerateResult> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error('OPENAI_API_KEY 환경변수가 필요합니다');

  const client = new OpenAI({ apiKey });
  const model = 'gpt-image-2';
  const prompt = `${BASE_PROMPT}\n주제: ${opts.description}`;

  const size = openAiSize(opts.aspect);
  const quality = openAiQuality(opts.quality);

  let b64: string | undefined;

  if (opts.reference) {
    const refBuffer = await fs.readFile(opts.reference);
    const refFile = await toFile(refBuffer, path.basename(opts.reference), {
      type: detectMimeType(opts.reference),
    });
    const editRes = await client.images.edit({
      model,
      image: refFile,
      prompt,
      size,
      quality,
      ...(opts.transparent ? { background: 'transparent' as const } : {}),
    });
    b64 = editRes.data?.[0]?.b64_json;
  } else {
    const genRes = await client.images.generate({
      model,
      prompt,
      size,
      quality,
      ...(opts.transparent ? { background: 'transparent' as const } : {}),
    });
    b64 = genRes.data?.[0]?.b64_json;
  }

  if (!b64) throw new Error(`OpenAI 이미지 생성 실패: ${opts.description}`);

  await fs.mkdir(opts.outputDir, { recursive: true });
  const outputPath = buildOutputPath(opts.description, opts.outputDir);
  await fs.writeFile(outputPath, Buffer.from(b64, 'base64'));

  return {
    filePath: outputPath,
    description: opts.description,
    provider: 'openai',
    model,
    quality: opts.quality,
    aspect: opts.aspect,
    edited: Boolean(opts.reference),
  };
}

// ─────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────

function parseArgs(argv: string[]): GenerateOptions {
  let description = '';
  let provider: Provider = 'gemini';
  let quality: Quality = 'standard';
  let aspect: Aspect = 'square';
  let transparent = false;
  let reference: string | undefined;
  let outputDir = process.cwd();

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--provider' && argv[i + 1]) {
      const v = argv[++i];
      if (v !== 'gemini' && v !== 'openai') {
        throw new Error(`알 수 없는 provider: ${v} (gemini|openai)`);
      }
      provider = v;
    } else if (arg === '--quality' && argv[i + 1]) {
      const v = argv[++i];
      if (v !== 'standard' && v !== 'high') {
        throw new Error(`알 수 없는 quality: ${v} (standard|high)`);
      }
      quality = v;
    } else if (arg === '--aspect' && argv[i + 1]) {
      const v = argv[++i];
      if (v !== 'square' && v !== 'portrait' && v !== 'landscape') {
        throw new Error(`알 수 없는 aspect: ${v} (square|portrait|landscape)`);
      }
      aspect = v;
    } else if (arg === '--resolution' && argv[i + 1]) {
      // Legacy alias: --resolution 1K|4K → --quality standard|high
      const v = argv[++i];
      if (v === '4K') quality = 'high';
      else if (v === '1K') quality = 'standard';
      else throw new Error(`알 수 없는 resolution: ${v} (1K|4K)`);
    } else if (arg === '--transparent') {
      transparent = true;
    } else if (arg === '--reference' && argv[i + 1]) {
      reference = argv[++i];
    } else if (arg === '--output-dir' && argv[i + 1]) {
      outputDir = argv[++i];
    } else if (!arg.startsWith('--')) {
      description = arg;
    }
  }

  if (!description) {
    throw new Error('이미지 설명이 필요합니다.');
  }

  return { description, provider, quality, aspect, transparent, reference, outputDir };
}

function printHelp(): void {
  console.log(`Usage: npx tsx generate.ts "설명" [옵션]

옵션:
  --provider gemini|openai           (기본: gemini)
  --quality  standard|high           (기본: standard)
  --aspect   square|portrait|landscape  (기본: square)
  --resolution 1K|4K                 (legacy alias for --quality, gemini only)
  --transparent                      (openai: 투명 배경 PNG)
  --reference <path>                 (이미지 편집 모드 — 레퍼런스 이미지)
  --output-dir <path>                (기본: 현재 디렉토리)

환경변수:
  GEMINI_API_KEY  (--provider gemini 필수)
  OPENAI_API_KEY  (--provider openai 필수)
`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    printHelp();
    process.exit(0);
  }

  let opts: GenerateOptions;
  try {
    opts = parseArgs(args);
  } catch (e) {
    console.error(`Error: ${(e as Error).message}`);
    process.exit(1);
  }

  // Provider별 옵션 경고
  if (opts.transparent && opts.provider !== 'openai') {
    console.error('Warning: --transparent는 openai provider에서만 적용됩니다. 무시합니다.');
    opts.transparent = false;
  }

  if (opts.reference) {
    try {
      await fs.access(opts.reference);
    } catch {
      console.error(`Error: --reference 파일이 존재하지 않습니다: ${opts.reference}`);
      process.exit(1);
    }
  }

  const result =
    opts.provider === 'openai'
      ? await generateWithOpenAI(opts)
      : await generateWithGemini(opts);

  console.log(JSON.stringify(result));
}

main().catch((e) => {
  console.error(`Error: ${(e as Error).message}`);
  process.exit(1);
});
