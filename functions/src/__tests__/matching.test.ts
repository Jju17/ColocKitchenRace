import {
  euclideanDistanceKm,
  computeCubicDistances,
  getCubicDist,
  greedyMinWeightMatching,
  doubleMatchingHeuristic,
  CohousePoint,
} from "../matching";

// ── euclideanDistanceKm ────────────────────────────────────────────────────────

describe("euclideanDistanceKm", () => {
  it("returns 0 for identical points", () => {
    expect(euclideanDistanceKm(50.85, 4.35, 50.85, 4.35)).toBe(0);
  });

  it("computes a reasonable distance between Brussels and Ixelles (~2 km)", () => {
    // Grand-Place ↔ Place Flagey ≈ 2.5 km
    const d = euclideanDistanceKm(50.8467, 4.3525, 50.8275, 4.3725);
    expect(d).toBeGreaterThan(1.5);
    expect(d).toBeLessThan(4);
  });

  it("computes a reasonable distance between Brussels and Antwerp (~45 km)", () => {
    const d = euclideanDistanceKm(50.8503, 4.3517, 51.2194, 4.4025);
    expect(d).toBeGreaterThan(35);
    expect(d).toBeLessThan(55);
  });

  it("is symmetric", () => {
    const d1 = euclideanDistanceKm(50.85, 4.35, 50.83, 4.37);
    const d2 = euclideanDistanceKm(50.83, 4.37, 50.85, 4.35);
    expect(d1).toBeCloseTo(d2, 10);
  });
});

// ── computeCubicDistances ──────────────────────────────────────────────────────

describe("computeCubicDistances", () => {
  const points: CohousePoint[] = [
    { id: "A", latitude: 50.85, longitude: 4.35 },
    { id: "B", latitude: 50.83, longitude: 4.37 },
    { id: "C", latitude: 50.82, longitude: 4.40 },
  ];

  it("computes N*(N-1)/2 entries for N points", () => {
    const dCubic = computeCubicDistances(points);
    expect(dCubic.size).toBe(3); // 3 choose 2
  });

  it("stores distances with sorted key format i,j where i < j", () => {
    const dCubic = computeCubicDistances(points);
    expect(dCubic.has("0,1")).toBe(true);
    expect(dCubic.has("0,2")).toBe(true);
    expect(dCubic.has("1,2")).toBe(true);
    expect(dCubic.has("1,0")).toBe(false); // Not stored reverse
  });

  it("values are the cube of euclidean distance", () => {
    const dCubic = computeCubicDistances(points);
    const d01 = euclideanDistanceKm(50.85, 4.35, 50.83, 4.37);
    expect(dCubic.get("0,1")).toBeCloseTo(d01 * d01 * d01, 5);
  });
});

// ── getCubicDist ───────────────────────────────────────────────────────────────

describe("getCubicDist", () => {
  it("returns the distance regardless of argument order", () => {
    const m = new Map<string, number>();
    m.set("2,5", 42);
    expect(getCubicDist(m, 2, 5)).toBe(42);
    expect(getCubicDist(m, 5, 2)).toBe(42);
  });

  it("returns Infinity for missing pairs", () => {
    const m = new Map<string, number>();
    expect(getCubicDist(m, 0, 1)).toBe(Infinity);
  });
});

// ── greedyMinWeightMatching ────────────────────────────────────────────────────

describe("greedyMinWeightMatching", () => {
  it("matches 4 nodes into 2 pairs", () => {
    const edges = [
      { u: 0, v: 1, weight: 1 },
      { u: 0, v: 2, weight: 10 },
      { u: 0, v: 3, weight: 10 },
      { u: 1, v: 2, weight: 10 },
      { u: 1, v: 3, weight: 10 },
      { u: 2, v: 3, weight: 2 },
    ];
    const pairs = greedyMinWeightMatching(4, edges);
    expect(pairs).toHaveLength(2);

    // Should pick (0,1) with weight 1 first, then (2,3) with weight 2
    const flat = pairs.flat();
    expect(flat.sort()).toEqual([0, 1, 2, 3]);
  });

  it("matches 2 nodes into 1 pair", () => {
    const edges = [{ u: 0, v: 1, weight: 5 }];
    const pairs = greedyMinWeightMatching(2, edges);
    expect(pairs).toHaveLength(1);
    expect(pairs[0]).toEqual([0, 1]);
  });

  it("returns empty for 0 nodes", () => {
    const pairs = greedyMinWeightMatching(0, []);
    expect(pairs).toHaveLength(0);
  });

  it("each node appears in exactly one pair", () => {
    // 6 nodes: all edges weight = index distance
    const edges = [];
    for (let i = 0; i < 6; i++) {
      for (let j = i + 1; j < 6; j++) {
        edges.push({ u: i, v: j, weight: j - i });
      }
    }
    const pairs = greedyMinWeightMatching(6, edges);
    expect(pairs).toHaveLength(3);

    const flat = pairs.flat();
    expect(new Set(flat).size).toBe(6); // All unique
  });

  it("prefers lighter edges", () => {
    const edges = [
      { u: 0, v: 1, weight: 100 },
      { u: 0, v: 2, weight: 1 },
      { u: 1, v: 2, weight: 50 },
      { u: 3, v: 0, weight: 200 },
      { u: 3, v: 1, weight: 2 },
      { u: 3, v: 2, weight: 200 },
    ];
    const pairs = greedyMinWeightMatching(4, edges);
    // Should pick (0,2) weight=1 first, then (1,3) weight=2
    const flat = pairs.flat().sort();
    expect(flat).toEqual([0, 1, 2, 3]);
    expect(pairs).toContainEqual([0, 2]);
    // Edge (3,1) has u=3,v=1 so the pair keeps that order
    const hasSecondPair = pairs.some(
      ([a, b]) => (a === 1 && b === 3) || (a === 3 && b === 1)
    );
    expect(hasSecondPair).toBe(true);
  });
});

// ── doubleMatchingHeuristic ────────────────────────────────────────────────────

describe("doubleMatchingHeuristic", () => {
  it("creates 1 group from 4 points", () => {
    const points: CohousePoint[] = [
      { id: "A", latitude: 50.850, longitude: 4.350 },
      { id: "B", latitude: 50.851, longitude: 4.351 },
      { id: "C", latitude: 50.852, longitude: 4.352 },
      { id: "D", latitude: 50.853, longitude: 4.353 },
    ];
    const dCubic = computeCubicDistances(points);
    const groups = doubleMatchingHeuristic(points, dCubic);

    expect(groups).toHaveLength(1);
    expect(groups[0].sort()).toEqual(["A", "B", "C", "D"]);
  });

  it("creates 2 groups from 8 points", () => {
    const points: CohousePoint[] = [
      // Cluster 1: Ixelles (very close together)
      { id: "A1", latitude: 50.8270, longitude: 4.3720 },
      { id: "A2", latitude: 50.8275, longitude: 4.3725 },
      { id: "A3", latitude: 50.8280, longitude: 4.3730 },
      { id: "A4", latitude: 50.8285, longitude: 4.3735 },
      // Cluster 2: Schaerbeek (very close together, ~3.5 km from cluster 1)
      { id: "B1", latitude: 50.8580, longitude: 4.3680 },
      { id: "B2", latitude: 50.8585, longitude: 4.3685 },
      { id: "B3", latitude: 50.8590, longitude: 4.3690 },
      { id: "B4", latitude: 50.8595, longitude: 4.3695 },
    ];
    const dCubic = computeCubicDistances(points);
    const groups = doubleMatchingHeuristic(points, dCubic);

    expect(groups).toHaveLength(2);

    // Each group should have 4 members
    for (const group of groups) {
      expect(group).toHaveLength(4);
    }

    // All 8 IDs should appear exactly once
    const allIds = groups.flat().sort();
    expect(allIds).toEqual(["A1", "A2", "A3", "A4", "B1", "B2", "B3", "B4"]);

    // The algorithm should group same-cluster points together
    // (cubic distance heavily penalises far points)
    const group1Ids = groups[0].sort();
    const group2Ids = groups[1].sort();

    const clusterA = ["A1", "A2", "A3", "A4"];
    const clusterB = ["B1", "B2", "B3", "B4"];

    const isCorrectGrouping =
      (JSON.stringify(group1Ids) === JSON.stringify(clusterA) &&
       JSON.stringify(group2Ids) === JSON.stringify(clusterB)) ||
      (JSON.stringify(group1Ids) === JSON.stringify(clusterB) &&
       JSON.stringify(group2Ids) === JSON.stringify(clusterA));

    expect(isCorrectGrouping).toBe(true);
  });

  it("creates N/4 groups from N points", () => {
    // Generate 20 random-ish points around Brussels
    const points: CohousePoint[] = [];
    for (let i = 0; i < 20; i++) {
      points.push({
        id: `P${i}`,
        latitude: 50.82 + (i % 5) * 0.01,
        longitude: 4.33 + Math.floor(i / 5) * 0.02,
      });
    }
    const dCubic = computeCubicDistances(points);
    const groups = doubleMatchingHeuristic(points, dCubic);

    expect(groups).toHaveLength(5); // 20 / 4

    // All IDs present exactly once
    const allIds = groups.flat().sort();
    const expectedIds = Array.from({ length: 20 }, (_, i) => `P${i}`).sort();
    expect(allIds).toEqual(expectedIds);

    // Each group has exactly 4 members
    for (const group of groups) {
      expect(group).toHaveLength(4);
    }
  });

  it("groups nearby points together (quality check)", () => {
    // 4 tight clusters of 4 points each, well separated
    const points: CohousePoint[] = [
      // Cluster NW (Jette)
      { id: "NW1", latitude: 50.875, longitude: 4.325 },
      { id: "NW2", latitude: 50.876, longitude: 4.326 },
      { id: "NW3", latitude: 50.877, longitude: 4.327 },
      { id: "NW4", latitude: 50.878, longitude: 4.328 },
      // Cluster NE (Woluwe)
      { id: "NE1", latitude: 50.843, longitude: 4.420 },
      { id: "NE2", latitude: 50.844, longitude: 4.421 },
      { id: "NE3", latitude: 50.845, longitude: 4.422 },
      { id: "NE4", latitude: 50.846, longitude: 4.423 },
      // Cluster SW (Uccle)
      { id: "SW1", latitude: 50.803, longitude: 4.330 },
      { id: "SW2", latitude: 50.804, longitude: 4.331 },
      { id: "SW3", latitude: 50.805, longitude: 4.332 },
      { id: "SW4", latitude: 50.806, longitude: 4.333 },
      // Cluster SE (Auderghem)
      { id: "SE1", latitude: 50.820, longitude: 4.410 },
      { id: "SE2", latitude: 50.821, longitude: 4.411 },
      { id: "SE3", latitude: 50.822, longitude: 4.412 },
      { id: "SE4", latitude: 50.823, longitude: 4.413 },
    ];

    const dCubic = computeCubicDistances(points);
    const groups = doubleMatchingHeuristic(points, dCubic);

    expect(groups).toHaveLength(4);

    // Each group should contain points from the same cluster
    for (const group of groups) {
      const prefixes = group.map((id) => id.replace(/\d$/, ""));
      // All 4 members should have the same prefix (NW, NE, SW, SE)
      expect(new Set(prefixes).size).toBe(1);
    }
  });

  it("handles the minimum case of exactly 4 points", () => {
    const points: CohousePoint[] = [
      { id: "X", latitude: 0, longitude: 0 },
      { id: "Y", latitude: 0.001, longitude: 0 },
      { id: "Z", latitude: 0, longitude: 0.001 },
      { id: "W", latitude: 0.001, longitude: 0.001 },
    ];
    const dCubic = computeCubicDistances(points);
    const groups = doubleMatchingHeuristic(points, dCubic);

    expect(groups).toHaveLength(1);
    expect(groups[0].sort()).toEqual(["W", "X", "Y", "Z"]);
  });
});
