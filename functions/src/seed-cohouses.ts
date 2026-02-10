/**
 * Seed script: creates fake cohouses in Firestore for testing the matching algorithm.
 *
 * Usage:
 *   cd functions
 *   npm run build
 *   node lib/seed-cohouses.js [--count 40] [--clean]
 *
 * Options:
 *   --count N   Number of cohouses to create (must be multiple of 4, default 40)
 *   --clean     Delete previously seeded cohouses before creating new ones
 *
 * Prerequisites:
 *   - Firebase Admin SDK initialised via GOOGLE_APPLICATION_CREDENTIALS or
 *     default application credentials (e.g. `gcloud auth application-default login`)
 *   - Or run with `firebase functions:shell` environment
 */

import * as admin from "firebase-admin";
import { randomUUID } from "crypto";

// --- Init Firebase Admin ---
admin.initializeApp();
const db = admin.firestore();

// --- Brussels & surroundings GPS data ---
// Real street names grouped by commune with approximate GPS coordinates
const BRUSSELS_LOCATIONS: Array<{
  street: string;
  city: string;
  postalCode: string;
  lat: number;
  lon: number;
}> = [
  // Ixelles
  { street: "Rue de la Paix 12", city: "Ixelles", postalCode: "1050", lat: 50.8292, lon: 4.3676 },
  { street: "Chaussée de Boondael 450", city: "Ixelles", postalCode: "1050", lat: 50.8185, lon: 4.3830 },
  { street: "Rue du Trône 98", city: "Ixelles", postalCode: "1050", lat: 50.8362, lon: 4.3693 },
  { street: "Avenue de la Couronne 227", city: "Ixelles", postalCode: "1050", lat: 50.8256, lon: 4.3787 },
  { street: "Rue Malibran 45", city: "Ixelles", postalCode: "1050", lat: 50.8270, lon: 4.3725 },
  // Etterbeek
  { street: "Avenue des Casernes 55", city: "Etterbeek", postalCode: "1040", lat: 50.8370, lon: 4.3890 },
  { street: "Rue des Champs 78", city: "Etterbeek", postalCode: "1040", lat: 50.8350, lon: 4.3940 },
  { street: "Avenue d'Auderghem 130", city: "Etterbeek", postalCode: "1040", lat: 50.8380, lon: 4.3960 },
  { street: "Rue Louis Hap 162", city: "Etterbeek", postalCode: "1040", lat: 50.8345, lon: 4.3915 },
  // Saint-Gilles
  { street: "Chaussée de Charleroi 110", city: "Saint-Gilles", postalCode: "1060", lat: 50.8310, lon: 4.3465 },
  { street: "Rue de la Victoire 67", city: "Saint-Gilles", postalCode: "1060", lat: 50.8280, lon: 4.3490 },
  { street: "Parvis de Saint-Gilles 1", city: "Saint-Gilles", postalCode: "1060", lat: 50.8275, lon: 4.3460 },
  { street: "Rue de Moscou 25", city: "Saint-Gilles", postalCode: "1060", lat: 50.8260, lon: 4.3440 },
  // Schaerbeek
  { street: "Rue Royale Sainte-Marie 85", city: "Schaerbeek", postalCode: "1030", lat: 50.8580, lon: 4.3680 },
  { street: "Avenue Louis Bertrand 42", city: "Schaerbeek", postalCode: "1030", lat: 50.8620, lon: 4.3710 },
  { street: "Chaussée de Haecht 299", city: "Schaerbeek", postalCode: "1030", lat: 50.8650, lon: 4.3750 },
  { street: "Rue des Palais 120", city: "Schaerbeek", postalCode: "1030", lat: 50.8590, lon: 4.3620 },
  // Woluwe-Saint-Lambert
  { street: "Avenue Georges Henri 310", city: "Woluwe-Saint-Lambert", postalCode: "1200", lat: 50.8430, lon: 4.4110 },
  { street: "Boulevard Brand Whitlock 95", city: "Woluwe-Saint-Lambert", postalCode: "1200", lat: 50.8410, lon: 4.4050 },
  { street: "Avenue de Broqueville 12", city: "Woluwe-Saint-Lambert", postalCode: "1200", lat: 50.8440, lon: 4.4200 },
  { street: "Rue Saint-Lambert 70", city: "Woluwe-Saint-Lambert", postalCode: "1200", lat: 50.8420, lon: 4.4150 },
  // Uccle
  { street: "Chaussée d'Alsemberg 450", city: "Uccle", postalCode: "1180", lat: 50.8040, lon: 4.3440 },
  { street: "Avenue Brugmann 180", city: "Uccle", postalCode: "1180", lat: 50.8120, lon: 4.3510 },
  { street: "Rue de Stalle 95", city: "Uccle", postalCode: "1180", lat: 50.8020, lon: 4.3290 },
  { street: "Avenue Winston Churchill 12", city: "Uccle", postalCode: "1180", lat: 50.8150, lon: 4.3540 },
  // Forest
  { street: "Avenue du Globe 45", city: "Forest", postalCode: "1190", lat: 50.8100, lon: 4.3240 },
  { street: "Chaussée de Bruxelles 245", city: "Forest", postalCode: "1190", lat: 50.8135, lon: 4.3180 },
  { street: "Rue de Mérode 78", city: "Forest", postalCode: "1190", lat: 50.8110, lon: 4.3210 },
  { street: "Avenue Albert 67", city: "Forest", postalCode: "1190", lat: 50.8090, lon: 4.3250 },
  // Anderlecht
  { street: "Rue Wayez 50", city: "Anderlecht", postalCode: "1070", lat: 50.8340, lon: 4.3150 },
  { street: "Boulevard Sylvain Dupuis 233", city: "Anderlecht", postalCode: "1070", lat: 50.8310, lon: 4.3050 },
  { street: "Chaussée de Mons 220", city: "Anderlecht", postalCode: "1070", lat: 50.8290, lon: 4.3100 },
  { street: "Rue Eloy 70", city: "Anderlecht", postalCode: "1070", lat: 50.8360, lon: 4.3120 },
  // Auderghem
  { street: "Boulevard du Souverain 142", city: "Auderghem", postalCode: "1160", lat: 50.8220, lon: 4.4060 },
  { street: "Chaussée de Wavre 1530", city: "Auderghem", postalCode: "1160", lat: 50.8190, lon: 4.4120 },
  { street: "Avenue du Kouter 21", city: "Auderghem", postalCode: "1160", lat: 50.8200, lon: 4.4200 },
  { street: "Rue Idiers 15", city: "Auderghem", postalCode: "1160", lat: 50.8180, lon: 4.4090 },
  // Centre / Bruxelles-Ville
  { street: "Rue Antoine Dansaert 70", city: "Bruxelles", postalCode: "1000", lat: 50.8510, lon: 4.3450 },
  { street: "Boulevard Anspach 150", city: "Bruxelles", postalCode: "1000", lat: 50.8490, lon: 4.3480 },
  { street: "Rue Haute 321", city: "Bruxelles", postalCode: "1000", lat: 50.8400, lon: 4.3470 },
  // Jette
  { street: "Rue Léon Théodor 88", city: "Jette", postalCode: "1090", lat: 50.8740, lon: 4.3280 },
  { street: "Boulevard de Smet de Naeyer 115", city: "Jette", postalCode: "1090", lat: 50.8780, lon: 4.3200 },
  { street: "Avenue de l'Exposition 20", city: "Jette", postalCode: "1090", lat: 50.8760, lon: 4.3250 },
  { street: "Rue Meyerbeer 44", city: "Jette", postalCode: "1090", lat: 50.8730, lon: 4.3310 },
  // Molenbeek
  { street: "Chaussée de Gand 60", city: "Molenbeek-Saint-Jean", postalCode: "1080", lat: 50.8530, lon: 4.3310 },
  { street: "Rue de Ribaucourt 120", city: "Molenbeek-Saint-Jean", postalCode: "1080", lat: 50.8560, lon: 4.3350 },
  { street: "Boulevard Léopold II 200", city: "Molenbeek-Saint-Jean", postalCode: "1080", lat: 50.8570, lon: 4.3290 },
  { street: "Rue de l'Intendant 15", city: "Molenbeek-Saint-Jean", postalCode: "1080", lat: 50.8540, lon: 4.3330 },
  // Woluwe-Saint-Pierre
  { street: "Avenue de Tervueren 364", city: "Woluwe-Saint-Pierre", postalCode: "1150", lat: 50.8370, lon: 4.4280 },
  { street: "Avenue des Éperviers 88", city: "Woluwe-Saint-Pierre", postalCode: "1150", lat: 50.8360, lon: 4.4350 },
  { street: "Rue au Bois 40", city: "Woluwe-Saint-Pierre", postalCode: "1150", lat: 50.8340, lon: 4.4310 },
  { street: "Avenue Orban 152", city: "Woluwe-Saint-Pierre", postalCode: "1150", lat: 50.8380, lon: 4.4260 },
];

// Fun cohouse names
const COHOUSE_NAMES = [
  "Les Joyeux Colocataires", "La Maison du Soleil", "Les Quatre Fantastiques",
  "Chez Nous Tous", "Villa Harmony", "Le Nid Douillet", "La Coloc des Champions",
  "Les Bons Vivants", "Maison Étoile", "Le Refuge Urbain",
  "Les Copains d'Abord", "La Maison Arc-en-Ciel", "Villa Liberté",
  "Le Loft des Artistes", "Les Aventuriers", "Chez les Bons Amis",
  "La Maison Verte", "Les Inséparables", "Villa Paradis", "Le QG",
  "Les Épicuriens", "La Tribu Joyeuse", "Maison Soleil Levant",
  "Le Cocon Partagé", "Les Globe-Trotters", "Villa Sérénité",
  "La Coloc Musicale", "Les Compagnons", "Maison des Rêves", "Le Spot",
  "Les Explorateurs", "La Maison du Bonheur", "Villa Créative",
  "Le Repaire Joyeux", "Les Amis Réunis", "Chez Colocs",
  "La Maison Ouverte", "Les Dynamiques", "Villa Complice", "Le Phare",
  "Les Joyeux Drilles", "La Coloc en Or", "Maison Boréale",
  "Le Jardin Partagé", "Les Potes en Coloc", "Villa Bohème",
  "La Maison Lumière", "Les Compères", "Maison Horizon", "Le Coeur Partagé",
  "Les Nomades Heureux", "La Coloc Zen",
];

function generateCode(): string {
  return String(Math.floor(1000 + Math.random() * 9000));
}

/**
 * Add small random jitter to GPS coordinates (±200m)
 */
function jitter(value: number, range = 0.002): number {
  return value + (Math.random() - 0.5) * 2 * range;
}

async function main() {
  const args = process.argv.slice(2);
  const cleanFlag = args.includes("--clean");
  const countIdx = args.indexOf("--count");
  let count = 40;
  if (countIdx !== -1 && args[countIdx + 1]) {
    count = parseInt(args[countIdx + 1], 10);
  }

  if (count % 4 !== 0) {
    console.error(`❌ Count must be a multiple of 4 (got ${count})`);
    process.exit(1);
  }

  // --- Clean previous seeds ---
  if (cleanFlag) {
    console.log("🧹 Cleaning previously seeded cohouses...");
    const snapshot = await db.collection("cohouses")
      .where("nameLower", ">=", "")
      .get();

    // Only delete cohouses that have the "seeded" marker
    const seededDocs = snapshot.docs.filter((doc) => doc.data().seeded === true);
    if (seededDocs.length > 0) {
      const batch = db.batch();
      seededDocs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`   Deleted ${seededDocs.length} seeded cohouses.`);
    } else {
      console.log("   No seeded cohouses to clean.");
    }
  }

  // --- Create cohouses ---
  console.log(`\n🏠 Creating ${count} fake cohouses around Brussels...\n`);

  const cohouseIds: string[] = [];
  const batch = db.batch();

  for (let i = 0; i < count; i++) {
    const id = randomUUID();
    const loc = BRUSSELS_LOCATIONS[i % BRUSSELS_LOCATIONS.length];
    const name = i < COHOUSE_NAMES.length
      ? COHOUSE_NAMES[i]
      : `${COHOUSE_NAMES[i % COHOUSE_NAMES.length]} ${Math.floor(i / COHOUSE_NAMES.length) + 1}`;

    const lat = jitter(loc.lat);
    const lon = jitter(loc.lon);

    const cohouseData = {
      id: id,
      name: name,
      nameLower: name.trim().toLowerCase(),
      address: {
        street: loc.street,
        city: loc.city,
        postalCode: loc.postalCode,
        country: "Belgique",
      },
      addressLower: {
        street: loc.street.trim().toLowerCase(),
        city: loc.city.trim().toLowerCase(),
        postalCode: loc.postalCode,
        country: "belgique",
      },
      code: generateCode(),
      latitude: parseFloat(lat.toFixed(6)),
      longitude: parseFloat(lon.toFixed(6)),
      seeded: true, // Marker for easy cleanup
    };

    const ref = db.collection("cohouses").doc(id);
    batch.set(ref, cohouseData);
    cohouseIds.push(id);

    const emoji = ["🏠", "🏡", "🏘️", "🏗️"][i % 4];
    console.log(`  ${emoji} ${name.padEnd(35)} ${loc.city.padEnd(25)} (${lat.toFixed(4)}, ${lon.toFixed(4)})`);
  }

  await batch.commit();
  console.log(`\n✅ ${count} cohouses created in Firestore.\n`);

  // --- Create or update CKR Game ---
  console.log("🎮 Creating/updating CKR Game with participant IDs...\n");

  // Check if a game already exists
  const gamesSnapshot = await db.collection("ckrGames").get();

  if (gamesSnapshot.empty) {
    // Create a new game
    const gameId = randomUUID();
    const now = new Date();
    const gameDate = new Date(now.getTime() + 60 * 24 * 60 * 60 * 1000); // +60 days
    const deadline = new Date(gameDate.getTime() - 14 * 24 * 60 * 60 * 1000); // -14 days

    await db.collection("ckrGames").doc(gameId).set({
      id: gameId,
      editionNumber: 1,
      nextGameDate: admin.firestore.Timestamp.fromDate(gameDate),
      registrationDeadline: admin.firestore.Timestamp.fromDate(deadline),
      maxParticipants: Math.max(100, count),
      publishedTimestamp: admin.firestore.Timestamp.fromDate(now),
      participantsID: cohouseIds,
    });

    console.log(`  Created new CKR Game: ${gameId}`);
    console.log(`  Edition #1, ${count} participants`);
    console.log(`  Game date: ${gameDate.toLocaleDateString()}`);
  } else {
    // Update existing game
    const existingGame = gamesSnapshot.docs[0];
    await existingGame.ref.update({
      participantsID: cohouseIds,
      maxParticipants: Math.max(
        (existingGame.data().maxParticipants as number) || 100,
        count
      ),
    });

    console.log(`  Updated existing CKR Game: ${existingGame.id}`);
    console.log(`  Set ${count} participants`);
  }

  console.log("\n🎉 Seeding complete! You can now test the matching algorithm.\n");
  console.log("From the CKRAdmin app, tap the 'Match cohouses' button.");
  console.log("Or use --clean flag to remove seeded data later.\n");

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Error:", err);
  process.exit(1);
});
