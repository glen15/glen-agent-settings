import fs from 'node:fs/promises';
import path from 'node:path';
import type { ContentResult } from '../../core/types.ts';

export async function writeToFile(
  result: ContentResult,
  outputPath?: string,
): Promise<string> {
  const slug = result.plan.title
    .replace(/[^a-zA-Z0-9가-힣]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 80);

  const filename = outputPath
    ? path.join(outputPath, `${slug}.md`)
    : `output/${slug}.md`;
  const resolved = path.resolve(filename);

  await fs.mkdir(path.dirname(resolved), { recursive: true });
  await fs.writeFile(resolved, result.markdown, 'utf8');

  const planPath = resolved.replace(/\.md$/, '.plan.json');
  await fs.writeFile(planPath, JSON.stringify(result.plan, null, 2), 'utf8');

  return resolved;
}
