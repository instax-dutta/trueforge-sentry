import type { Metadata } from "next";
import "./globals.css";

const GRAFANA_URL = process.env.NEXT_PUBLIC_GRAFANA_URL ?? "http://localhost:3001";
const TF_CHAT_URL = process.env.NEXT_PUBLIC_TF_CHAT_URL ?? "http://localhost:8791";
const REPO_URL = process.env.NEXT_PUBLIC_REPO_URL ?? "https://github.com/instax-dutta/trueforge-sentry";

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
            <a href={GRAFANA_URL} target="_blank" rel="noreferrer">Grafana</a>
            <a href={TF_CHAT_URL} target="_blank" rel="noreferrer">TrueForge Chat</a>
            <a href={REPO_URL} target="_blank" rel="noreferrer">Repo</a>
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}
