// src/components/ChatBubble.tsx
type MessageStatus = 'pending' | 'acked'

type ChatBubbleProps = {
  text: string
  side: 'outgoing' | 'incoming'
  status?: MessageStatus
}

export function ChatBubble({ text, side, status }: ChatBubbleProps) {
  const isOutgoing = side === 'outgoing'
  const isPending = status === 'pending'
  const isAcked = status === 'acked'
  const isFailed = status === 'failed'

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: isOutgoing ? 'flex-end' : 'flex-start',
        marginBottom: 8,
      }}
    >
      <div
        style={{
          maxWidth: '70%',
          padding: '6px 10px',
          borderRadius: 12,
          fontSize: 14,
          lineHeight: 1.4,
          background: isOutgoing
            ? 'var(--bgColor-accent-emphasis, #238636)'
            : 'var(--bgColor-default, #0d1117)',
          color: isOutgoing
            ? 'var(--fgColor-onEmphasis, #ffffff)'
            : 'var(--fgColor-default, #e6edf3)',
          border: !isOutgoing
            ? '1px solid var(--borderColor-muted, #30363d)'
            : 'none',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          {/* text on the left */}
          <div style={{ flex: 1 }}>{text}</div>

          {/* status icon on the right (only for outgoing) */}
          {isOutgoing && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                fontSize: 11,
                opacity: 0.9,
              }}
            >
              {isPending ? (
                <svg
                  width="14"
                  height="14"
                  viewBox="0 0 16 16"
                  fill="none"
                  style={{
                    animation: 'spin 1s linear infinite',
                  }}
                  aria-label="Sending…"
                >
                  <circle
                    cx="8"
                    cy="8"
                    r="7"
                    stroke="currentColor"
                    strokeOpacity="0.25"
                    strokeWidth="2"
                  />
                  <path
                    d="M15 8a7.002 7.002 0 00-7-7"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                  />
                </svg>
              ) : isAcked ? (
                <span style={{ fontSize: 14 }}>✓</span>
              ) : isFailed ? (
                <span style={{ fontSize: 14, color: '#f85149' }} title="Message expired - not delivered">✕</span>
              ) : null}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
