import type { ContentPlan } from './types.ts';

const IMAGE_PLACEHOLDER_PREFIX = '<!-- IMAGE_PLACEHOLDER:';
const IMAGE_PLACEHOLDER_SUFFIX = ' -->';

export function makeImagePlaceholder(description: string): string {
  return `${IMAGE_PLACEHOLDER_PREFIX} ${description} ${IMAGE_PLACEHOLDER_SUFFIX}`;
}

export function renderMarkdown(plan: ContentPlan): string {
  const lines: string[] = [];

  lines.push(`# ${plan.title}`);
  lines.push('');

  lines.push(`> **저자**: ${plan.author} | **카테고리**: ${plan.category}`);
  lines.push(`> **키워드**: ${plan.keywords.join(', ')}`);
  lines.push('');

  const heroDesc = buildHeroImageDescription(plan);
  lines.push(makeImagePlaceholder(heroDesc));
  lines.push('');

  lines.push('## 요약');
  lines.push('');
  lines.push(plan.summary);
  lines.push('');

  lines.push('## TL;DR');
  lines.push('');
  for (const bullet of plan.tldrBullets) {
    lines.push(`- ${bullet}`);
  }
  lines.push('');
  lines.push('---');
  lines.push('');

  for (const section of plan.sections) {
    lines.push(`## ${section.heading}`);
    lines.push('');

    lines.push(`<details>`);
    lines.push(`<summary>${section.toggleTitle}</summary>`);
    lines.push('');
    for (const bullet of section.bullets) {
      lines.push(`- ${bullet}`);
    }
    lines.push('');
    lines.push('</details>');
    lines.push('');
  }

  return lines.join('\n');
}

function buildHeroImageDescription(plan: ContentPlan): string {
  const keywords = plan.sections
    .slice(0, 6)
    .map(s => s.heading.replace(/[—\-:].*/g, '').trim().split(/\s+/).slice(0, 4).join(' '))
    .join(', ');
  return [
    `${plan.title}.`,
    `핵심 키워드를 아이콘으로 표현한 인포그래픽.`,
    `키워드: ${keywords}.`,
    `텍스트 최소화, 아이콘/다이어그램 중심, 라벨은 2~3단어 이내`,
  ].join(' ');
}

export function extractImagePlaceholders(markdown: string): { index: number; description: string }[] {
  const results: { index: number; description: string }[] = [];
  const lines = markdown.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith(IMAGE_PLACEHOLDER_PREFIX)) {
      const desc = line
        .replace(IMAGE_PLACEHOLDER_PREFIX, '')
        .replace(IMAGE_PLACEHOLDER_SUFFIX, '')
        .trim();
      results.push({ index: i, description: desc });
    }
  }

  return results;
}

export function replaceImagePlaceholder(
  markdown: string,
  lineIndex: number,
  imageUrl: string,
  caption: string,
): string {
  const lines = markdown.split('\n');
  lines[lineIndex] = `![${caption}](${imageUrl})`;
  return lines.join('\n');
}
