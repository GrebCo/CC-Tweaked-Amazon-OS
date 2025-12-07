// src/main.tsx
import React, {StrictMode} from 'react'
import {createRoot} from 'react-dom/client'

// If you have index.css and want default Vite styles:
import './index.css'

import App from './App.tsx'

const rootElement = document.getElementById('root')
if (!rootElement) {
    throw new Error('Could not find root element with id "root"')
}

createRoot(rootElement).render(
    <StrictMode>
        <App/>
    </StrictMode>
)
