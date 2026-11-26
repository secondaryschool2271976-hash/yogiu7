import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';

function App() {
  return (
    <div className="min-h-screen bg-[#0B0F17] text-[#EEF2F7] flex flex-col items-center justify-center p-6">
      <div className="max-w-xl text-center space-y-4">
        <h1 className="text-3xl font-bold text-[#D4A442]">Yu-Gi-Oh! Power of Chaos Remake</h1>
        <p className="text-gray-300">
          مشغل الويب ونظام المبارزات وقاعدة بيانات البطاقات تعمل بكفاءة عالية مع دعم اللغات والأونلاين والبطاقات الجديدة.
        </p>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
