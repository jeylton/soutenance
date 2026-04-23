import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
    plugins: [react()],
    server: {
        host: '127.0.0.1',
        port: 55000,
        strictPort: false,
        hmr: {
            host: '127.0.0.1',
            protocol: 'ws',
        },
    },
    preview: {
        host: '127.0.0.1',
        port: 55000,
        strictPort: false,
    },
})
