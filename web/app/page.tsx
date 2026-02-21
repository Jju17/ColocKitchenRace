export default function Home() {
  return (
    <main className="container">
      <div className="hero">
        <h1>Colocs Kitchen Race</h1>
        <p className="subtitle">
          Organise des repas communautaires entre colocs a Bruxelles !
        </p>
        <div className="badges">
          <a
            href="https://apps.apple.com"
            className="badge"
            target="_blank"
            rel="noopener noreferrer"
          >
            Disponible sur iOS
          </a>
          <a
            href="https://play.google.com"
            className="badge"
            target="_blank"
            rel="noopener noreferrer"
          >
            Disponible sur Android
          </a>
        </div>
        <p className="coming-soon">Version web - bientot disponible</p>
      </div>
    </main>
  );
}
