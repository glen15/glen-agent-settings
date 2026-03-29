import { z } from 'zod/v4';

// --- Source Reader ---

export const SourceType = z.enum([
  'url',
  'markdown',
  'pdf',
  'json',
  'github',
  'folder',
]);
export type SourceType = z.infer<typeof SourceType>;

export interface RawContent {
  text: string;
  sourceType: SourceType;
  source: string;
  title?: string;
  files?: string[];
}

export interface SourceReader {
  canHandle(input: string): boolean;
  read(input: string): Promise<RawContent>;
}

// --- Content Plan ---

export const SectionSchema = z.object({
  heading: z.string(),
  imagePlaceholder: z.string().optional(),
  toggleTitle: z.string(),
  bullets: z.array(z.string()),
});
export type Section = z.infer<typeof SectionSchema>;

export const ContentPlanSchema = z.object({
  title: z.string(),
  author: z.string(),
  category: z.string(),
  keywords: z.array(z.string()),
  summary: z.string(),
  tldrBullets: z.array(z.string()).length(5),
  sections: z.array(SectionSchema).min(2),
});
export type ContentPlan = z.infer<typeof ContentPlanSchema>;

// --- Image ---

export interface ImageAsset {
  localPath: string;
  remotePath: string;
  rawUrl: string;
  caption: string;
}

// --- Pipeline Result ---

export interface ContentResult {
  markdown: string;
  images: ImageAsset[];
  plan: ContentPlan;
  source: RawContent;
}

// --- Pipeline Options ---

export interface PipelineOptions {
  generateImages?: boolean;
  maxImages?: number;
  imageResolution?: '1K' | '4K';
}

// --- Section Expansion ---

export const ExpandedSectionSchema = z.object({
  heading: z.string(),
  body: z.string(),
  imagePlaceholders: z.array(z.string()).optional(),
  charCount: z.number(),
});
export type ExpandedSection = z.infer<typeof ExpandedSectionSchema>;

export const ExpansionResultSchema = z.object({
  planTitle: z.string(),
  sections: z.array(ExpandedSectionSchema),
  expandedAt: z.string(),
});
export type ExpansionResult = z.infer<typeof ExpansionResultSchema>;

export interface ExpandOptions {
  sectionIndices?: number[];
  targetCharsPerSection?: number;
  generateImagePlaceholders?: boolean;
  maxImagePlaceholders?: number;
  sourceText?: string;
  instruction?: string;
}

export interface AssembleOptions {
  generateImages?: boolean;
  maxImages?: number;
  imageResolution?: '1K' | '4K';
}
