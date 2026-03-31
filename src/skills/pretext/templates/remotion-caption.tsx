/**
 * Pretext + Remotion 캡션 컴포넌트 템플릿
 *
 * 사용법:
 * 1. @chenglou/pretext 설치: npm install @chenglou/pretext
 * 2. 이 파일을 Remotion 프로젝트에 복사
 * 3. CaptionSequence 컴포넌트를 메인 Composition에서 사용
 *
 * Pretext가 DOM 없이 캡션 높이/줄 수를 계산하고,
 * 줄 수 기반으로 프레임 타이밍을 자동 배분합니다.
 */

import { prepare, layout, prepareWithSegments, walkLineRanges } from '@chenglou/pretext'
import { AbsoluteFill, Sequence, useCurrentFrame, interpolate, spring, useVideoConfig } from 'remotion'

// ========== 타입 ==========

type CaptionConfig = {
  text: string
  font?: string
  lineHeight?: number
  captionWidth?: number
  secPerLine?: number
}

type ComputedCaption = CaptionConfig & {
  lineCount: number
  height: number
  shrinkWidth: number
  durationInFrames: number
  startFrame: number
}

// ========== 핵심: Pretext로 프레임 타이밍 계산 ==========

function computeCaptionTimings(
  captions: CaptionConfig[],
  fps: number,
  defaults: { font: string; lineHeight: number; captionWidth: number; secPerLine: number }
): ComputedCaption[] {
  let frameOffset = 0

  return captions.map(cap => {
    const font = cap.font ?? defaults.font
    const lineHeight = cap.lineHeight ?? defaults.lineHeight
    const captionWidth = cap.captionWidth ?? defaults.captionWidth
    const secPerLine = cap.secPerLine ?? defaults.secPerLine

    const prepared = prepare(cap.text, font)
    const { lineCount, height } = layout(prepared, captionWidth, lineHeight)

    // shrinkwrap: 최적 너비 계산
    const preparedSeg = prepareWithSegments(cap.text, font)
    let maxLineWidth = 0
    walkLineRanges(preparedSeg, captionWidth, line => {
      if (line.width > maxLineWidth) maxLineWidth = line.width
    })

    const durationInFrames = Math.ceil(lineCount * secPerLine * fps)
    const result: ComputedCaption = {
      ...cap,
      lineCount,
      height,
      shrinkWidth: Math.ceil(maxLineWidth) + 1,
      durationInFrames,
      startFrame: frameOffset,
    }
    frameOffset += durationInFrames
    return result
  })
}

// ========== 캡션 컴포넌트 ==========

function Caption({ text, shrinkWidth, height }: { text: string; shrinkWidth: number; height: number }) {
  const frame = useCurrentFrame()
  const { fps } = useVideoConfig()

  const opacity = interpolate(frame, [0, 10], [0, 1], { extrapolateRight: 'clamp' })
  const scale = spring({ frame, fps, config: { damping: 15, stiffness: 120 } })

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 80,
        left: '50%',
        transform: `translateX(-50%) scale(${scale})`,
        opacity,
        maxWidth: shrinkWidth + 32,
        background: 'rgba(0, 0, 0, 0.75)',
        color: '#fff',
        padding: '12px 16px',
        borderRadius: 12,
        fontSize: 14,
        lineHeight: '20px',
        textAlign: 'center',
        fontFamily: 'Inter, sans-serif',
      }}
    >
      {text}
    </div>
  )
}

// ========== 시퀀스 컴포넌트 (export) ==========

type CaptionSequenceProps = {
  captions: CaptionConfig[]
  font?: string
  lineHeight?: number
  captionWidth?: number
  secPerLine?: number
}

export function CaptionSequence({
  captions,
  font = '14px Inter, sans-serif',
  lineHeight = 20,
  captionWidth = 400,
  secPerLine = 1.0,
}: CaptionSequenceProps) {
  const { fps } = useVideoConfig()
  const computed = computeCaptionTimings(captions, fps, { font, lineHeight, captionWidth, secPerLine })

  return (
    <AbsoluteFill>
      {computed.map((cap, i) => (
        <Sequence key={i} from={cap.startFrame} durationInFrames={cap.durationInFrames}>
          <Caption text={cap.text} shrinkWidth={cap.shrinkWidth} height={cap.height} />
        </Sequence>
      ))}
    </AbsoluteFill>
  )
}

// ========== 유틸리티 (export) ==========

export { computeCaptionTimings }
export type { CaptionConfig, ComputedCaption }
