
import { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import TechMapReactFlow from './components/TechMapReactFlow';
import ProjectsSection from './components/ProjectsSection';
import ContactSection from './components/ContactSection';
import VenturesSection from './components/VenturesSection';
import Labs from './components/Labs';

function App() {
  const [currentPage, setCurrentPage] = useState(window.location.hash);

  useEffect(() => {
    const onHashChange = () => setCurrentPage(window.location.hash);
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  const isLabs = currentPage === '#labs';
  const isVentures = currentPage === '#ventures';

  if (isLabs) {
    return (
      <div className="min-h-screen font-sans">
        <Labs />
      </div>
    );
  }

  if (isVentures) {
    return (
      <div className="min-h-screen font-sans">
        <VenturesSection />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 font-sans text-slate-900 selection:bg-blue-100 selection:text-blue-900">
      <Navbar />
      <main>
        <Hero />
        <TechMapReactFlow />
        <ProjectsSection />
        <ContactSection />
      </main>
    </div>
  );
}

export default App;
