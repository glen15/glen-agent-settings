import { GoogleGenAI } from '@google/genai';
import fs from 'node:fs/promises';
import path from 'node:path';
import type { ImageAsset } from './types.ts';

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

export type ImageResolution = '1K' | '4K';

export async function generateImage(
  description: string,
  outputDir: string,
  resolution: ImageResolution = '1K',
): Promise<string> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY 환경변수가 필요합니다');

  const ai = new GoogleGenAI({ apiKey });

  const prompt = [
    '한국어로 작성된 설명을 바탕으로, 교육용 문서에 넣을 수 있는 깔끔한 인포그래픽/다이어그램 스타일 이미지를 생성한다.',
    '이미지 안의 텍스트는 "기본 한글 + 일부 영어(키워드/라벨)"로 구성한다.',
    '- 한글 70~90%, 영어 10~30% (예: BM25, AST, MCP, locate/expand, tokens-to-complete 등은 영어 유지)',
    '- 문장형 설명 금지: 라벨/짧은 구문만',
    '- 로고/워터마크 금지, 과도한 텍스트 금지, 산세리프 폰트 느낌',
    `주제: ${description}`,
  ].join('\n');

  const response = await ai.models.generateContent({
    model: 'gemini-3.1-flash-image-preview',
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    config: {
      responseModalities: ['TEXT', 'IMAGE'],
      imageConfig: {
        imageSize: resolution,
      },
    },
  });

  const parts = response.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    if (part.inlineData?.data) {
      const slug = safeSlug(description);
      const filename = `${nowStamp()}-${slug}.png`;
      const outputPath = path.join(outputDir, filename);

      await fs.mkdir(outputDir, { recursive: true });

      const buffer = Buffer.from(part.inlineData.data, 'base64');
      await fs.writeFile(outputPath, buffer);

      return outputPath;
    }
  }

  throw new Error(`이미지 생성 실패: ${description}`);
}

export async function generateImages(
  placeholders: { index: number; description: string }[],
  options: { max?: number; resolution?: ImageResolution } = {},
): Promise<ImageAsset[]> {
  const max = options.max ?? 5;
  const resolution = options.resolution ?? '1K';
  const targets = placeholders.slice(0, max);

  const results: ImageAsset[] = [];
  for (const target of targets) {
    const tmpDir = path.join(process.env.TMPDIR || '/tmp', `contents-img-${Date.now()}`);
    const localPath = await generateImage(target.description, tmpDir, resolution);
    results.push({
      localPath,
      remotePath: path.basename(localPath),
      rawUrl: localPath,
      caption: target.description,
    });
  }

  return results;
}
