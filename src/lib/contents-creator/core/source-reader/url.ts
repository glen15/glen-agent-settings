import { Readability } from '@mozilla/readability';
import { parseHTML } from 'linkedom';
import type { RawContent, SourceReader } from './types.ts';

const FIRECRAWL_API = 'https://api.firecrawl.dev/v1';
const MIN_CONTENT_LENGTH = 200;

// --- X (Twitter) 전용 ---

const X_URL_RE = /^https?:\/\/(x\.com|twitter\.com)\/\w+\/status\/(\d+)/;

function isXUrl(url: string): boolean {
  return X_URL_RE.test(url);
}

async function scrapeX(url: string): Promise<string | null> {
  const match = url.match(X_URL_RE);
  if (!match) return null;
  const tweetId = match[2];

  // 1차: Syndication API (짧은 트윗용, 무료/빠름)
  try {
    const res = await fetch(
      `https://cdn.syndication.twimg.com/tweet-result?id=${tweetId}&token=x`,
      { headers: { 'User-Agent': 'Mozilla/5.0' } },
    );
    if (res.ok) {
      const json = await res.json() as {
        text?: string;
        user?: { name?: string; screen_name?: string };
        created_at?: string;
        note_tweet?: { id?: string };
      };

      if (!json.note_tweet && json.text && json.text.length >= MIN_CONTENT_LENGTH) {
        const author = json.user?.name ?? '';
        const handle = json.user?.screen_name ?? '';
        const date = json.created_at ?? '';
        return `# ${author} (@${handle})\n${date}\n\n${json.text}`;
      }
    }
  } catch {
    // syndication 실패 시 Playwright로 진행
  }

  // 2차: Playwright (Long post 대응)
  try {
    const { chromium } = await import('playwright');
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      viewport: { width: 1280, height: 900 },
    });
    const page = await context.newPage();

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
    await page.locator('[data-testid="tweetText"]').first().waitFor({ timeout: 15000 });

    const texts = await page.locator('[data-testid="tweetText"]').allInnerTexts();
    const author = await page.locator('[data-testid="User-Name"]').first().innerText().catch(() => '');
    const date = await page.locator('time').first().getAttribute('datetime').catch(() => '');

    await browser.close();

    if (texts.length > 0 && texts[0].length >= MIN_CONTENT_LENGTH) {
      const cleanAuthor = author.split('\n').slice(0, 2).join(' ');
      return `# ${cleanAuthor}\n${date}\n\n${texts[0]}`;
    }
  } catch {
    // Playwright 실패
  }

  return null;
}

async function scrapeWithFirecrawl(url: string): Promise<string | null> {
  const apiKey = process.env.FIRECRAWL_API_KEY;
  if (!apiKey) return null;

  try {
    const res = await fetch(`${FIRECRAWL_API}/scrape`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        url,
        formats: ['markdown'],
        onlyMainContent: true,
      }),
    });

    if (!res.ok) return null;

    const json = await res.json() as { success?: boolean; data?: { markdown?: string } };
    const md = json?.data?.markdown ?? '';
    return md.length >= MIN_CONTENT_LENGTH ? md : null;
  } catch {
    return null;
  }
}

async function scrapeWithFetch(url: string): Promise<string | null> {
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; ContentCreator/1.0)',
      },
    });

    if (!res.ok) return null;

    const html = await res.text();
    const { document } = parseHTML(html);
    const reader = new Readability(document);
    const article = reader.parse();

    if (!article?.textContent) return null;

    const text = article.textContent.trim();
    return text.length >= MIN_CONTENT_LENGTH ? text : null;
  } catch {
    return null;
  }
}

export const urlReader: SourceReader = {
  canHandle(input: string): boolean {
    return /^https?:\/\//i.test(input) && !input.includes('github.com/');
  },

  async read(input: string): Promise<RawContent> {
    // X (Twitter) 전용 경로
    if (isXUrl(input)) {
      const xResult = await scrapeX(input);
      if (xResult) {
        return { text: xResult, sourceType: 'url', source: input };
      }
      throw new Error(`X 포스트를 추출하지 못했습니다: ${input}`);
    }

    // 1차: Firecrawl
    const firecrawlResult = await scrapeWithFirecrawl(input);
    if (firecrawlResult) {
      return { text: firecrawlResult, sourceType: 'url', source: input };
    }

    // 2차: 기본 fetch + readability
    const fetchResult = await scrapeWithFetch(input);
    if (fetchResult) {
      return { text: fetchResult, sourceType: 'url', source: input };
    }

    throw new Error(`URL에서 충분한 콘텐츠를 추출하지 못했습니다: ${input}`);
  },
};
