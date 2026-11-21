import type { Config } from 'tailwindcss';

// Colour tokens mirror docs/DESIGN.md. Keep them in sync with the mobile app.
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // "Skorbord" (ADR-10). accent is the pitch green so white text on it passes AA;
        // volt is a fill only, always with primary (ink) text on it.
        primary: '#0E0F0C',
        accent: '#1E5A37',
        accentSoft: '#EEF7C8',
        volt: '#D4FF3A',
        surface: '#F7F7F3',
        card: '#FFFFFF',
        textPrimary: '#0E0F0C',
        textSecondary: '#5C5F57',
        border: '#E3E3DC',
        warning: '#F5C84B', // fill only, dark text on it
        danger: '#C4232F',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      borderRadius: {
        xl: '14px',
        '2xl': '16px',
      },
    },
  },
  plugins: [],
};

export default config;
