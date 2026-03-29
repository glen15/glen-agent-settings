import type { RawContent, SourceReader } from './types.ts';

const GITHUB_API = 'https://api.github.com';

interface GitHubFile {
  name: string;
  path: string;
  type: 'file' | 'dir';
  download_url: string | null;
}

function parseGitHubUrl(input: string): { owner: string; repo: string } | null {
  const match = input.match(/github\.com\/([^/]+)\/([^/]+)/);
  if (!match) return null;
  return { owner: match[1], repo: match[2].replace(/\.git$/, '') };
}

function makeHeaders(): Record<string, string> {
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'glen-agent-settings',
  };
  const token = process.env.GITHUB_TOKEN;
  if (token) headers['Authorization'] = `Bearer ${token}`;
  return headers;
}

const PRIORITY_FILES = ['README.md', 'README', 'readme.md', 'package.json', 'Cargo.toml', 'pyproject.toml', 'go.mod'];
const MAX_FILE_SIZE = 50_000;

export const githubReader: SourceReader = {
  canHandle(input: string): boolean {
    return /github\.com\/[^/]+\/[^/]+/.test(input);
  },

  async read(input: string): Promise<RawContent> {
    const parsed = parseGitHubUrl(input);
    if (!parsed) throw new Error(`GitHub URL 파싱 실패: ${input}`);

    const { owner, repo } = parsed;
    const headers = makeHeaders();

    const treeRes = await fetch(`${GITHUB_API}/repos/${owner}/${repo}/contents`, { headers });
    if (!treeRes.ok) throw new Error(`GitHub API 실패: ${treeRes.status}`);
    const files = await treeRes.json() as GitHubFile[];

    const fileNames = files.map((f) => f.path);

    const parts: string[] = [];
    for (const pf of PRIORITY_FILES) {
      const found = files.find((f) => f.name === pf && f.type === 'file' && f.download_url);
      if (!found?.download_url) continue;

      const res = await fetch(found.download_url, { headers });
      if (!res.ok) continue;

      const text = await res.text();
      if (text.length <= MAX_FILE_SIZE) {
        parts.push(`--- ${found.path} ---\n${text}`);
      }
    }

    if (parts.length === 0) {
      throw new Error(`GitHub 레포에서 읽을 수 있는 파일이 없습니다: ${input}`);
    }

    return {
      text: parts.join('\n\n'),
      sourceType: 'github',
      source: input,
      title: repo,
      files: fileNames,
    };
  },
};
