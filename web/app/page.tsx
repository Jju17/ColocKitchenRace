export default function Home() {
  return (
    <main className="container">
      <div className="hero">
        <h1>
          Colocs
          <br />
          Kitchen
          <br />
          Race
        </h1>
        <p className="subtitle">
          Organise des repas communautaires entre colocs a Bruxelles !
        </p>
        <div className="badges">
          <a
            href="https://apps.apple.com/be/app/colocskitchenrace/id6759000795"
            className="badge"
            target="_blank"
            rel="noopener noreferrer"
          >
            <img src="/app-store-badge.svg" alt="Download on the App Store" />
          </a>
          <a
            href="https://play.google.com"
            className="badge"
            target="_blank"
            rel="noopener noreferrer"
          >
            <img src="/google-play-badge.svg" alt="Get it on Google Play" />
          </a>
        </div>
        <div className="footer-links">
          <a href="/privacy-policy.html">Politique de confidentialite</a>
          <a href="/support.html">Support</a>
        </div>
      </div>
    </main>
  );
}
