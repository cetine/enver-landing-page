
import { useState, useEffect } from 'react';
import { AnimatePresence } from 'framer-motion';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import TechMapReactFlow from './components/TechMapReactFlow';
import ProjectsSection from './components/ProjectsSection';
import ContactSection from './components/ContactSection';
import VenturesSection from './components/VenturesSection';
import Labs from './components/Labs';
import PageTransition from './components/PageTransition';
import IntroOverlay from './components/IntroOverlay';
import ScrollProgressBar from './components/ScrollProgressBar';
import CustomCursor from './components/CustomCursor';
import ParallaxBackground from './components/ParallaxBackground';

function App() {
  const [currentPage, setCurrentPage] = useState(window.location.hash);
  const [introComplete, setIntroComplete] = useState(
    () => !!sessionStorage.getItem('intro-seen')
  );

  useEffect(() => {
    const onHashChange = () => setCurrentPage(window.location.hash);
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  const isLabs = currentPage === '#labs';
  const isVentures = currentPage === '#ventures';

  const handleIntroComplete = () => {
    sessionStorage.setItem('intro-seen', 'true');
    setIntroComplete(true);
  };

  return (
    <>
      <CustomCursor />

      <AnimatePresence>
        {!introComplete && (
          <IntroOverlay onComplete={handleIntroComplete} />
        )}
      </AnimatePresence>

      <AnimatePresence mode="wait">
        {isLabs ? (
          <PageTransition
            key="labs"
            onEntered={() => window.scrollTo(0, 0)}
          >
            <div className="min-h-screen font-sans">
              <Labs />
            </div>
          </PageTransition>
        ) : isVentures ? (
          <PageTransition
            key="ventures"
            onEntered={() => window.scrollTo(0, 0)}
          >
            <div className="min-h-screen font-sans">
              <VenturesSection />
            </div>
          </PageTransition>
        ) : (
          <PageTransition key="main">
            <div className="min-h-screen bg-slate-50 font-sans text-slate-900 selection:bg-blue-100 selection:text-blue-900">
              <Navbar />
              <ScrollProgressBar />
              <main className="relative">
                <ParallaxBackground />
                <Hero />
                <TechMapReactFlow />
                <ProjectsSection />
                <ContactSection />
              </main>
            </div>
          </PageTransition>
        )}
      </AnimatePresence>
    </>
  );
}

export default App;
