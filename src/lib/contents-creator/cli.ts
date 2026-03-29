import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { parseCliArgs } from './adapters/input/cli.ts';
import { stepRead, stepRender } from './core/pipeline.ts';
import { ContentPlanSchema } from './core/types.ts';
import { writeToFile } from './adapters/output/file.ts';

async function main() {
  const { command, input, options, outputFormat, outputPath } = parseCliArgs(process.argv);

  switch (command) {
    case 'read': {
      const source = await stepRead(input);
      process.stdout.write(JSON.stringify(source, null, 2));
      break;
    }

    case 'render': {
      const raw = await fs.readFile(path.resolve(input), 'utf8');
      const plan = ContentPlanSchema.parse(JSON.parse(raw));

      const { markdown, images } = await stepRender(plan, options);

      if (outputFormat === 'stdout') {
        process.stdout.write(markdown);
      } else {
        const saved = await writeToFile({ markdown, images, plan, source: { text: '', sourceType: 'json', source: input } }, outputPath);
        console.error(`파일 저장: ${saved}`);
      }
      break;
    }
  }
}

main().catch((e) => {
  console.error('오류:', e instanceof Error ? e.message : e);
  process.exit(1);
});
