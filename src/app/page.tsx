const pillars = [
  { number: "01", title: "Create your pockets", description: "Give your money a purpose: rent, food, savings, bills and the goals that matter to you." },
  { number: "02", title: "Set your allocation", description: "Choose the percentage each pocket should receive. Your plan must add up to 100%." },
  { number: "03", title: "Allocate verified income", description: "When a deposit is verified, Pusa records it and distributes it according to your active plan." }
];

export default function Home() {
  return (
    <main>
      <nav className="nav">
        <a className="brand" href="/" aria-label="Pusa home"><span className="brand-mark">p</span> pusa</a>
        <span className="nav-note">SMART SAVING</span>
      </nav>

      <section className="hero">
        <div className="eyebrow"><span className="live-dot" /> A smarter way to manage money</div>
        <h1>Your money,<br /><em>put to purpose.</em></h1>
        <p className="hero-copy">Pusa helps you organize incoming money into the things that matter — automatically, clearly, and on your terms.</p>
        <div className="hero-actions">
          <a className="primary-button" href="#how-it-works">Discover how it works <span aria-hidden="true">↗</span></a>
          <span className="currency-note">Built for Cameroon · XAF</span>
        </div>
        <div className="hero-art" aria-label="Illustration of money being allocated into savings pockets">
          <div className="orbit orbit-one" /><div className="orbit orbit-two" />
          <div className="center-card"><span className="center-label">YOUR INCOME</span><strong>100,000 <small>XAF</small></strong><span className="center-status">Ready to allocate</span></div>
          <div className="float-pocket pocket-rent"><span>⌂</span><b>Rent</b><strong>30,000</strong><small>30%</small></div>
          <div className="float-pocket pocket-save"><span>✳</span><b>Savings</b><strong>25,000</strong><small>25%</small></div>
          <div className="float-pocket pocket-life"><span>◈</span><b>Everyday</b><strong>45,000</strong><small>45%</small></div>
        </div>
      </section>

      <section className="how" id="how-it-works">
        <div className="section-heading"><span className="section-kicker">THE PUSA METHOD</span><h2>One income. Clear intentions.</h2><p>Make a plan once. Let every verified deposit follow it.</p></div>
        <div className="steps">{pillars.map((pillar) => <article className="step" key={pillar.number}><span className="step-number">{pillar.number}</span><h3>{pillar.title}</h3><p>{pillar.description}</p></article>)}</div>
      </section>
      <footer><a className="brand footer-brand" href="/"><span className="brand-mark">p</span> pusa</a><span>Receive. Allocate. Protect. Grow.</span><span>© {new Date().getFullYear()} Pusa</span></footer>
    </main>
  );
}
