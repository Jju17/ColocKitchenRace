/**
 * Cohouse Matching Algorithm — Pure functions (no Firebase dependency).
 *
 * Implements the Double Perfect Matching Heuristic:
 *   Phase 1 — match individual cohouses into optimal pairs (greedy MWPM)
 *   Phase 2 — match pairs into groups of 4 (second greedy MWPM)
 *
 * Distance metric: Euclidean GPS distance (equirectangular approx) raised to the cube.
 */

// ── Types ──────────────────────────────────────────────────────────────────────

export interface CohousePoint {
  id: string;
  latitude: number;
  longitude: number;
}

export interface Edge {
  u: number;
  v: number;
  weight: number;
}

// ── Distance helpers ───────────────────────────────────────────────────────────

/**
 * Euclidean distance between two GPS points.
 * Uses a simple equirectangular approximation (valid for short distances like within Belgium).
 * Returns distance in km.
 */
export function euclideanDistanceKm(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const avgLat = (lat1 + lat2) / 2 * Math.PI / 180;
  const dx = dLon * Math.cos(avgLat) * R;
  const dy = dLat * R;
  return Math.sqrt(dx * dx + dy * dy);
}

/**
 * Compute cubic distance matrix for all pairs.
 * Key format: "i,j" where i < j (sorted indices).
 */
export function computeCubicDistances(points: CohousePoint[]): Map<string, number> {
  const distances = new Map<string, number>();
  for (let i = 0; i < points.length; i++) {
    for (let j = i + 1; j < points.length; j++) {
      const d = euclideanDistanceKm(
        points[i].latitude, points[i].longitude,
        points[j].latitude, points[j].longitude
      );
      distances.set(`${i},${j}`, d * d * d); // cubic
    }
  }
  return distances;
}

/**
 * Get cubic distance between two point indices.
 */
export function getCubicDist(dCubic: Map<string, number>, i: number, j: number): number {
  const key = i < j ? `${i},${j}` : `${j},${i}`;
  return dCubic.get(key) ?? Infinity;
}

// ── Matching ───────────────────────────────────────────────────────────────────

/**
 * Greedy Minimum Weight Perfect Matching.
 * Sorts all edges by weight, greedily picks the lightest edge
 * whose both endpoints are still unmatched.
 * Returns pairs of node indices.
 */
export function greedyMinWeightMatching(
  nodeCount: number,
  edges: Edge[]
): Array<[number, number]> {
  // Sort edges by weight ascending
  edges.sort((a, b) => a.weight - b.weight);

  const matched = new Set<number>();
  const pairs: Array<[number, number]> = [];

  for (const edge of edges) {
    if (matched.has(edge.u) || matched.has(edge.v)) continue;
    pairs.push([edge.u, edge.v]);
    matched.add(edge.u);
    matched.add(edge.v);
    if (pairs.length * 2 >= nodeCount) break;
  }

  return pairs;
}

/**
 * Double Perfect Matching Heuristic — adapted from coloc_matcher.py
 *
 * Phase 1: Match individual cohouses into optimal pairs via greedy MWPM.
 * Phase 2: Match pairs into groups of 4 via a second greedy MWPM.
 *
 * @param points - Array of cohouse points with GPS coordinates
 * @param dCubic - Precomputed cubic distance matrix
 * @returns Array of groups, each group is an array of 4 cohouse IDs
 */
export function doubleMatchingHeuristic(
  points: CohousePoint[],
  dCubic: Map<string, number>
): string[][] {
  const N = points.length;

  // --- Phase 1: Match individual points into optimal pairs ---
  const edges1: Edge[] = [];
  for (let i = 0; i < N; i++) {
    for (let j = i + 1; j < N; j++) {
      edges1.push({ u: i, v: j, weight: getCubicDist(dCubic, i, j) });
    }
  }

  const pairs = greedyMinWeightMatching(N, edges1);

  // --- Phase 2: Match the pairs into optimal groups of 4 ---
  const numPairs = pairs.length;
  const edges2: Edge[] = [];

  for (let idx1 = 0; idx1 < numPairs; idx1++) {
    for (let idx2 = idx1 + 1; idx2 < numPairs; idx2++) {
      const pair1 = pairs[idx1];
      const pair2 = pairs[idx2];

      // Cost = max of 4 cross-distances (conservative estimate)
      const cost = Math.max(
        getCubicDist(dCubic, pair1[0], pair2[0]),
        getCubicDist(dCubic, pair1[0], pair2[1]),
        getCubicDist(dCubic, pair1[1], pair2[0]),
        getCubicDist(dCubic, pair1[1], pair2[1])
      );

      edges2.push({ u: idx1, v: idx2, weight: cost });
    }
  }

  const matchedPairs = greedyMinWeightMatching(numPairs, edges2);

  // Reconstruct final groups using cohouse IDs
  const groups: string[][] = [];
  for (const [pairIdx1, pairIdx2] of matchedPairs) {
    const group = [
      points[pairs[pairIdx1][0]].id,
      points[pairs[pairIdx1][1]].id,
      points[pairs[pairIdx2][0]].id,
      points[pairs[pairIdx2][1]].id,
    ];
    groups.push(group);
  }

  return groups;
}
