import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Molago',
    short_name: 'Molago',
    description: 'Korean vocabulary through etymology and morpheme families',
    start_url: '/',
    display: 'standalone',
    background_color: '#F7F5F1',
    theme_color: '#F7F5F1',
    icons: [
      {
        src: '/icons/icon-192.png',
        sizes: '192x192',
        type: 'image/png',
      },
      {
        src: '/icons/icon-512.png',
        sizes: '512x512',
        type: 'image/png',
      },
    ],
  };
}
