import type { Config } from 'tailwindcss';

// Colour tokens mirror docs/DESIGN.md. Keep them in sync with the mobile app.
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#0F2A44',
        accent: '#22B573',
        accentSoft: '#E6F7EF',
        surface: '#F5F7FA',
        card: '#FFFFFF',
        textPrimary: '#111827',
        textSecondary: '#6B7280',
        border: '#E5E7EB',
        warning: '#F59E0B',
        danger: '#E11D48',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      borderRadius: {
        xl: '12px',
        '2xl': '16px',
      },
    },
  },
  plugins: [],
};

export default config;
