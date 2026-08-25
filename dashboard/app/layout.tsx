import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SENTRY Mission Control",
  description: "On-call incident responder on TrueForge - chaos lab and live incident telemetry",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="topbar">
          <div className="brand">
            <span className="pulse-dot" aria-hidden />
            <span className="brand-name">SENTRY</span>
            <span className="brand-sub">Mission Control</span>
          </div>
          <nav className="topnav">
            <a href="http://localhost:3001" target="_blank" rel="noreferrer">Grafana</a>
            <a href="http://localhost:8791" target="_blank" rel="noreferrer">TrueForge Chat</a>
            <a href="https://github.com/instax-dutta/trueforge-sentry" target="_blank" rel="noreferrer">Repo</a>
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}
