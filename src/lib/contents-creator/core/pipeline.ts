import { readSource } from './source-reader/index.ts';
import { renderMarkdown, extractImagePlaceholders, replaceImagePlaceholder } from './renderer.ts';
import { generateImages as genImages } from './image-gen.ts';
import type { ContentPlan, ContentResult, PipelineOptions, RawContent } from './types.ts';

export async function stepRead(input: string): Promise<RawContent> {
  return readSource(input);
}

export async function stepRender(
  plan: ContentPlan,
  options: PipelineOptions = {},
): Promise<{ markdown: string; images: ContentResult['images'] }> {
  const {
    generateImages = false,
    maxImages = 5,
    imageResolution = '1K',
  } = options;

  let markdown = renderMarkdown(plan);
  const placeholders = extractImagePlaceholders(markdown);
  console.error(`  마크다운: ${markdown.length}자 | 플레이스홀더 ${placeholders.length}개`);

  let images: ContentResult['images'] = [];
  if (generateImages && placeholders.length > 0) {
    console.error(`  히어로 이미지 생성 중...`);
    images = await genImages(placeholders, { max: 1, resolution: imageResolution });

    const sorted = [...images]
      .map((img, i) => ({ ...img, lineIndex: placeholders[i].index }))
      .sort((a, b) => b.lineIndex - a.lineIndex);

    for (const img of sorted) {
      markdown = replaceImagePlaceholder(markdown, img.lineIndex, img.rawUrl, img.caption);
    }
    console.error(`  이미지 ${images.length}개 완료`);
  }

  return { markdown, images };
}
