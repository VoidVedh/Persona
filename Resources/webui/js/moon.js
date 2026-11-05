(function () {
  "use strict";

  /**
   * Computes an SVG path string for the illuminated portion of a moon disc at (cx, cy, r)
   * using the terminator ellipse algorithm of §7.2:
   * - p in [0, 1): 0 = new moon, 0.25 = first quarter, 0.5 = full moon, 0.75 = last quarter.
   */
  function computeMoonLitPath(p, cx, cy, r) {
    var norm = ((Number(p) || 0) % 1 + 1) % 1;
    // Near new moon
    if (norm < 0.015 || norm > 0.985) {
      return "";
    }
    // Near full moon
    if (Math.abs(norm - 0.5) < 0.015) {
      return (
        "M " + cx + " " + (cy - r) +
        " A " + r + " " + r + " 0 1 1 " + cx + " " + (cy + r) +
        " A " + r + " " + r + " 0 1 1 " + cx + " " + (cy - r) + " Z"
      );
    }

    var waxing = norm < 0.5;
    var k = Math.cos(2 * Math.PI * norm); // +1 at new, 0 at quarter, -1 at full
    var rx = Math.max(0.1, Math.abs(k) * r);

    // Outer limb arc from top (cx, cy-r) to bottom (cx, cy+r)
    // waxing -> right half lit (sweep = 1); waning -> left half lit (sweep = 0)
    var limbSweep = waxing ? 1 : 0;

    // Terminator arc from bottom (cx, cy+r) back to top (cx, cy-r)
    // Crescent (k > 0) vs Gibbous (k < 0) flips the terminator sweep
    var termSweep;
    if (waxing) {
      termSweep = k > 0 ? 0 : 1;
    } else {
      termSweep = k > 0 ? 1 : 0;
    }

    return (
      "M " + cx + " " + (cy - r) +
      " A " + r + " " + r + " 0 0 " + limbSweep + " " + cx + " " + (cy + r) +
      " A " + rx.toFixed(2) + " " + r + " 0 0 " + termSweep + " " + cx + " " + (cy - r) +
      " Z"
    );
  }

  window.personaMoon = {
    computeLitPath: computeMoonLitPath
  };
})();
