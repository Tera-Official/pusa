import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Pusa — Smart Saving",
  description: "Your money, automatically put to purpose.",
  applicationName: "Pusa"
};

export const viewport: Viewport = {
  themeColor: "#102c25",
  width: "device-width",
  initialScale: 1
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
