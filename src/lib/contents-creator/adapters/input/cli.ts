import type { PipelineOptions } from '../../core/types.ts';

export type Command = 'read' | 'render';

interface CliArgs {
  command: Command;
  input: string;
  options: PipelineOptions;
  outputFormat: 'file' | 'stdout';
  outputPath?: string;
}

function printUsage(): never {
  console.error(`사용법: npx tsx cli.ts <command> <입력> [옵션]

커맨드:
  read <입력>              소스를 읽어 raw text 출력 (JSON)
  render <plan.json>       Plan JSON → 마크다운 렌더링 + 이미지

입력:
  URL                      https://example.com/article
  .md 파일                 ./content.md
  .pdf 파일                ./document.pdf
  .json 파일               ./data.json
  GitHub 레포              https://github.com/owner/repo
  로컬 폴더                ./my-project

옵션:
  --images                 이미지 생성 활성화
  --max-images N           최대 이미지 수 (기본: 5)
  --resolution 1K|4K       이미지 해상도 (기본: 1K)
  --output file|stdout     출력 대상 (기본: file)
  --output-dir PATH        출력 디렉토리`);
  process.exit(1);
}

export function parseCliArgs(argv: string[]): CliArgs {
  const args = argv.slice(2);
  if (args.length === 0) printUsage();

  const command = args[0] as Command;
  if (!['read', 'render'].includes(command)) {
    console.error(`알 수 없는 커맨드: ${command}`);
    printUsage();
  }

  const rest = args.slice(1);
  const input = rest.find((a) => !a.startsWith('--')) ?? '';
  if (!input) {
    console.error(`${command} 커맨드에 입력이 필요합니다`);
    printUsage();
  }

  const getFlag = (name: string) => rest.includes(`--${name}`);
  const getArg = (name: string, def: string) => {
    const i = rest.indexOf(`--${name}`);
    return i !== -1 && rest[i + 1] ? rest[i + 1] : def;
  };

  const outputFormat = getArg('output', 'file') as CliArgs['outputFormat'];
  const outputPath = getArg('output-dir', '');

  return {
    command,
    input,
    options: {
      generateImages: getFlag('images'),
      maxImages: Number(getArg('max-images', '5')),
      imageResolution: getArg('resolution', '1K') as '1K' | '4K',
    },
    outputFormat,
    outputPath: outputPath || undefined,
  };
}
