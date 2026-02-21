import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Colocs Kitchen Race",
  description:
    "Organise des repas communautaires entre colocs a Bruxelles !",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
