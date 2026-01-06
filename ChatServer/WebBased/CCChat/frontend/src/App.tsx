// src/App.tsx
import { useState, useEffect } from 'react'
import { ChatBubble } from './components/ChatBubble'

type MessageStatus = 'pending' | 'acked' | 'failed'

type ChatMessage = {
  id: number
  text: string
  side: 'outgoing' | 'incoming'
  status?: MessageStatus
}

type ConnectionStatus = 'connected' | 'disconnected' | 'checking'

type ServerStatus = {
  cc_connected: boolean
  queued_messages: number
}

export default function App() {
  const [server, setServer] = useState('CraftoriaNA')
  const [name, setName] = useState('Player')

  const [message, setMessage] = useState('')
  const [isSending, setIsSending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [nextId, setNextId] = useState(1)

  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('checking')
  const [serverStatus, setServerStatus] = useState<ServerStatus | null>(null)

  const API_BASE_URL = 'http://localhost:8000'

  // Check CC computer connection status for current server
  async function checkServerStatus() {
    try {
      const res = await fetch(`${API_BASE_URL}/api/status/${encodeURIComponent(server)}`)
      if (res.ok) {
        const data = await res.json()
        setServerStatus(data)
        setConnectionStatus('connected')
      } else {
        setConnectionStatus('disconnected')
        setServerStatus(null)
      }
    } catch (err) {
      setConnectionStatus('disconnected')
      setServerStatus(null)
    }
  }

  // Check connection on mount and periodically
  useEffect(() => {
    checkServerStatus()
    const interval = setInterval(checkServerStatus, 5000) // Check every 5 seconds
    return () => clearInterval(interval)
  }, [server]) // Re-check when server changes

  // Listen for ack events from backend via Server-Sent Events
  useEffect(() => {
    const eventSource = new EventSource(`${API_BASE_URL}/api/events/${encodeURIComponent(server)}`)

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.type === 'ack' && data.id) {
          markMessageAcked(data.id)
        } else if (data.type === 'failed' && data.id) {
          markMessageFailed(data.id)
        }
      } catch (err) {
        console.error('[SSE] Error parsing event:', err)
      }
    }

    eventSource.onerror = (err) => {
      console.error('[SSE] Connection error:', err)
      eventSource.close()
    }

    return () => {
      eventSource.close()
    }
  }, [server])

  async function handleSend() {
    const trimmed = message.trim()
    if (!trimmed) return

    setIsSending(true)
    setError(null)

    // Use a temporary ID that will be replaced with the real one
    const tempId = Date.now()

    // Add message optimistically to UI immediately
    setMessages(prev => [
      ...prev,
      {
        id: tempId,
        text: trimmed,
        side: 'outgoing',
        status: 'pending',
      },
    ])
    setMessage('')

    try {
      // Send the message without delay first
      const res = await fetch(
        `${API_BASE_URL}/api/messages/${encodeURIComponent(server)}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: trimmed,
            name: name.trim() || 'Player',
          }),
        },
      )

      if (!res.ok) {
        let detail = ''
        try {
          const data = await res.json()
          detail = data.detail || ''
        } catch {
          // ignore JSON parse errors
        }
        throw new Error(detail || `HTTP ${res.status}`)
      }

      // Get the real ID assigned by the backend IMMEDIATELY
      const responseData = await res.json()
      const realId = responseData.id

      // Replace temp ID with real ID from backend IMMEDIATELY
      setMessages(prev => prev.map(m => (m.id === tempId ? { ...m, id: realId } : m)))

      // Now add the minimum delay so spinner is visible
      await new Promise(resolve => setTimeout(resolve, 500))

    } catch (err: any) {
      console.error('Send failed:', err)
      setError(err.message || 'Failed to send message')
      // Remove the optimistic message on error
      setMessages(prev => prev.filter(m => m.id !== tempId))
    } finally {
      setIsSending(false)
    }
  }

  function markMessageAcked(id: number) {
    setMessages(prev => prev.map(m =>
      m.id === id ? { ...m, status: 'acked' as const } : m
    ))
  }

  function markMessageFailed(id: number) {
    setMessages(prev => prev.map(m =>
      m.id === id ? { ...m, status: 'failed' as const } : m
    ))
  }

  return (
    <div
      style={{
        height: '100vh',
        padding: 16,
        border: '2px solid var(--borderColor-muted, #30363d)',
        borderRadius: 3,
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
      }}
    >
      <h1
        style={{
          fontSize: 24,
          margin: 0,
          marginBottom: 16,
          textAlign: 'center',
        }}
      >
        CC Remote Chat
      </h1>

      <hr
        style={{
          margin: '0 0 16px 0',
          border: 'none',
          borderBottom: '1px solid var(--borderColor-muted, #30363d)',
        }}
      />

      <div
        style={{
          display: 'flex',
          gap: 16,
          marginTop: 16,
          flex: 1,
          minHeight: 0,
          overflow: 'hidden',
        }}
      >
        {/* SIDEBAR */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 12,
            maxWidth: 200,
            minWidth: 200,
            padding: 12,
            borderRadius: 8,
            border: '1px solid var(--borderColor-muted, #30363d)',
            background: 'var(--bgColor-default, #0d1117)',
          }}
        >
          {/* Backend Connection Status */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '6px 8px',
              borderRadius: 4,
              background: 'var(--bgColor-muted, #161b22)',
              fontSize: 11,
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background:
                  connectionStatus === 'connected'
                    ? '#3fb950'
                    : connectionStatus === 'disconnected'
                    ? '#f85149'
                    : '#848d97',
                boxShadow:
                  connectionStatus === 'connected'
                    ? '0 0 8px rgba(63, 185, 80, 0.6)'
                    : connectionStatus === 'disconnected'
                    ? '0 0 8px rgba(248, 81, 73, 0.6)'
                    : 'none',
              }}
            />
            <span style={{ color: 'var(--fgColor-muted, #8b949e)' }}>
              Backend
            </span>
          </div>

          {/* CC Computer Connection Status */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              padding: '6px 8px',
              borderRadius: 4,
              background: 'var(--bgColor-muted, #161b22)',
              fontSize: 11,
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                borderRadius: '50%',
                background:
                  serverStatus?.cc_connected
                    ? '#3fb950'
                    : '#f85149',
                boxShadow:
                  serverStatus?.cc_connected
                    ? '0 0 8px rgba(63, 185, 80, 0.6)'
                    : '0 0 8px rgba(248, 81, 73, 0.6)',
              }}
            />
            <div style={{ flex: 1 }}>
              <div style={{ color: 'var(--fgColor-muted, #8b949e)' }}>
                CC Computer
              </div>
              {serverStatus && serverStatus.queued_messages > 0 && (
                <div style={{ color: '#f85149', fontSize: 10, marginTop: 2 }}>
                  {serverStatus.queued_messages} queued
                </div>
              )}
            </div>
          </div>

          <label
            style={{
              display: 'inline-flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            <span style={{ fontSize: 14 }}>Server</span>
            <select
              value={server}
              onChange={e => setServer(e.target.value)}
              style={{
                padding: '4px 8px',
                fontSize: 14,
                borderRadius: 4,
                border: '1px solid var(--borderColor-muted, #30363d)',
                background: 'var(--bgColor-default, #0d1117)',
                color: 'var(--fgColor-default, #e6edf3)',
              }}
            >
              <option value="CraftoriaNA">CraftoriaNA</option>
              <option value="CraftoriaEU">CraftoriaEU</option>
              <option value="SimplicitySMP">SimplicitySMP</option>
            </select>
          </label>

          <label
            style={{
              display: 'inline-flex',
              flexDirection: 'column',
              gap: 4,
              marginTop: 12,
            }}
          >
            <span style={{ fontSize: 14 }}>Name</span>
            <input
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              style={{
                padding: '4px 8px',
                fontSize: 14,
                borderRadius: 4,
                border: '1px solid var(--borderColor-muted, #30363d)',
                background: 'var(--bgColor-default, #0d1117)',
                color: 'var(--fgColor-default, #e6edf3)',
              }}
            />
          </label>
        </div>

        {/* RIGHT PANEL */}
        <div
          style={{
            marginTop: 0,
            padding: 12,
            borderRadius: 8,
            border: '1px solid var(--borderColor-muted, #30363d)',
            background: 'var(--bgColor-default, #0d1117)',
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            overflow: 'hidden',
          }}
        >
          {/* messages area */}
          <div
            style={{
              flex: 1,
              overflowY: 'auto',
              paddingRight: 4,
              paddingBottom: 8,
            }}
          >
            {messages.length === 0 && (
              <div
                style={{
                  color: 'var(--fgColor-muted, #8b949e)',
                  fontSize: 13,
                }}
              >
                No messages yet.
              </div>
            )}

            {messages.map(m => (
              <ChatBubble
                key={m.id}
                text={m.text}
                side={m.side}
                status={m.status}
              />
            ))}
          </div>

          {/* bottom input bar */}
          <div
            style={{
              marginTop: 'auto',
              display: 'flex',
              gap: 8,
              alignItems: 'flex-start',
            }}
          >
            <div style={{ flex: 1, position: 'relative' }}>
              <textarea
                placeholder="Type a message..."
                maxLength={256}
                value={message}
                onChange={e => setMessage(e.target.value)}
                onKeyDown={e => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault()
                    handleSend()
                  }
                }}
                rows={1}
                style={{
                  width: '100%',
                  boxSizing: 'border-box',
                  padding: '8px 8px 20px 8px',
                  borderRadius: 8,
                  border: '1px solid var(--borderColor-muted, #30363d)',
                  background: 'var(--bgColor-default, #0d1117)',
                  color: 'var(--fgColor-default, #e6edf3)',
                  resize: 'none',
                  fontFamily: 'inherit',
                  fontSize: 14,
                  lineHeight: 1.5,
                }}
              />
              <div
                style={{
                  position: 'absolute',
                  bottom: 8,
                  right: 8,
                  fontSize: 11,
                  color: 'var(--fgColor-muted, #8b949e)',
                  pointerEvents: 'none',
                }}
              >
                {message.length}/256
              </div>
            </div>

            <button
              className="send-button"
              onClick={handleSend}
              disabled={isSending || !message.trim()}
              style={{
                minWidth: 96,
                padding: '16px 16px',
                borderRadius: 8,
                border: '1px solid var(--borderColor-muted, #30363d)',
                fontWeight: 600,
                cursor:
                  isSending || !message.trim()
                    ? 'default'
                    : 'pointer',
                opacity: isSending || !message.trim() ? 0.6 : 1,
              }}
            >
              {isSending ? 'Sending…' : 'Send'}
            </button>
          </div>

          {error && (
            <div
              style={{
                marginTop: 8,
                color: '#f85149',
                fontSize: 12,
              }}
            >
              {error}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
