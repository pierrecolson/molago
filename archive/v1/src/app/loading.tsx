export default function Loading() {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100dvh',
        background: '#F7F5F1',
        gap: '16px',
      }}
    >
      <div style={{ display: 'flex', gap: '6px' }}>
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: '#F35D48',
              animation: `loadPulseInline 1.2s ease-in-out ${i * 0.2}s infinite`,
            }}
          />
        ))}
      </div>
      <p
        style={{
          fontSize: '14px',
          color: '#AFACA5',
          fontFamily: '-apple-system, sans-serif',
        }}
      >
        Loading your words...
      </p>
      <style>{`
        @keyframes loadPulseInline {
          0%, 100% { opacity: 0.3; transform: scale(0.85); }
          50% { opacity: 1; transform: scale(1); }
        }
      `}</style>
    </div>
  );
}
