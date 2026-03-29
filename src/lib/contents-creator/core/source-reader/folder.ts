import fs from 'node:fs/promises';
import path from 'node:path';
import type { RawContent, SourceReader } from './types.ts';

const IGNORE_DIRS = new Set(['node_modules', '.git', 'dist', '.next', '__pycache__', '.venv', 'vendor']);
const READABLE_EXTS = new Set(['.ts', '.tsx', '.js', '.jsx', '.md', '.json', '.py', '.go', '.rs', '.toml', '.yaml', '.yml']);
const MAX_FILE_SIZE = 50_000;
const MAX_TOTAL_SIZE = 200_000;

async function isDirectory(p: string): Promise<boolean> {
  try {
    const stat = await fs.stat(p);
    return stat.isDirectory();
  } catch {
    return false;
  }
}

async function collectFiles(dir: string, depth = 0): Promise<string[]> {
  if (depth > 3) return [];

  const entries = await fs.readdir(dir, { withFileTypes: true });
  const result: string[] = [];

  for (const entry of entries) {
    if (entry.name.startsWith('.') || IGNORE_DIRS.has(entry.name)) continue;

    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const sub = await collectFiles(fullPath, depth + 1);
      result.push(...sub);
    } else if (READABLE_EXTS.has(path.extname(entry.name))) {
      result.push(fullPath);
    }
  }

  return result;
}

export const folderReader: SourceReader = {
  canHandle(input: string): boolean {
    return !input.startsWith('http') && !path.extname(input);
  },

  async read(input: string): Promise<RawContent> {
    const resolved = path.resolve(input);
    if (!(await isDirectory(resolved))) {
      throw new Error(`디렉토리가 아닙니다: ${resolved}`);
    }

    const files = await collectFiles(resolved);
    const parts: string[] = [];
    let totalSize = 0;

    const readme = files.find((f) => path.basename(f).toLowerCase().startsWith('readme'));
    if (readme) {
      const text = await fs.readFile(readme, 'utf8');
      if (text.length <= MAX_FILE_SIZE) {
        parts.push(`--- ${path.relative(resolved, readme)} ---\n${text}`);
        totalSize += text.length;
      }
    }

    for (const file of files) {
      if (file === readme) continue;
      if (totalSize >= MAX_TOTAL_SIZE) break;

      const text = await fs.readFile(file, 'utf8');
      if (text.length > MAX_FILE_SIZE) continue;

      parts.push(`--- ${path.relative(resolved, file)} ---\n${text}`);
      totalSize += text.length;
    }

    return {
      text: parts.join('\n\n'),
      sourceType: 'folder',
      source: resolved,
      title: path.basename(resolved),
      files: files.map((f) => path.relative(resolved, f)),
    };
  },
};
