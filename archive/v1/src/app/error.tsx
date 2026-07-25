'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
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
        padding: '24px',
        textAlign: 'center',
      }}
    >
      <div
        style={{
          fontSize: '20px',
          fontWeight: 600,
          color: '#2C2C2C',
        }}
      >
        Something went wrong
      </div>
      <div
        style={{
          fontSize: '14px',
          color: '#AFACA5',
          lineHeight: '1.5',
        }}
      >
        An error occurred while loading the page.
      </div>
      <button
        onClick={reset}
        style={{
          marginTop: '8px',
          padding: '10px 24px',
          background: '#F35D48',
          color: '#FFFFFF',
          border: 'none',
          borderRadius: '10px',
          fontSize: '14px',
          fontWeight: 500,
          cursor: 'pointer',
          fontFamily: '-apple-system, sans-serif',
        }}
      >
        Try again
      </button>
    </div>
  );
}
