import { CaseSection } from "@/components/site/CaseSection";
import { ClubhouseSection } from "@/components/site/ClubhouseSection";
import { ComingSoon, Footer } from "@/components/site/ComingSoon";
import { Header } from "@/components/site/Header";
import { Hero } from "@/components/site/Hero";
import { ProfilesSection } from "@/components/site/ProfilesSection";
import { SeasonSection } from "@/components/site/SeasonSection";

const Index = () => (
  <div className="min-h-screen">
    <Header />
    <main>
      <Hero />
      <CaseSection />
      <ProfilesSection />
      <SeasonSection />
      <ClubhouseSection />
      <ComingSoon />
    </main>
    <Footer />
  </div>
);

export default Index;
