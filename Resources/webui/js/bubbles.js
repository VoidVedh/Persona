(function () {
  "use strict";

  var canvas = document.getElementById("wp-bubbles-canvas");
  if (!canvas || !window.persona) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var MAX_PARTICLES = 48;
  var activeCount = 28;
  var bubbles = [];
  var rng = window.persona.random;

  function initBubbles() {
    bubbles = [];
    for (var i = 0; i < MAX_PARTICLES; i++) {
      bubbles.push({
        xFrac: rng(),
        yFrac: rng(),
        r: 3 + rng() * 11,
        speed: 10 + rng() * 18,
        omega: 0.8 + rng() * 1.4,
        phase: rng() * Math.PI * 2,
        alpha: 0.1 + rng() * 0.2
      });
    }
  }

  function resizeIfNeeded() {
    var w = window.innerWidth || 1512;
    var h = window.innerHeight || 982;
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
  }

  function setParticleCount(n) {
    var c = parseInt(n, 10);
    if (isNaN(c)) c = 28;
    activeCount = Math.max(0, Math.min(MAX_PARTICLES, c));
  }

  function stepBubbles(tSec) {
    if (!ctx) return;
    resizeIfNeeded();
    var w = canvas.width;
    var h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    var isDark = document.documentElement.getAttribute("data-phase") === "darkHour";
    var strokeBase = isDark ? "93, 255, 207" : "0, 216, 255";

    for (var i = 0; i < activeCount; i++) {
      var b = bubbles[i];
      var baseY = ((b.yFrac * h - tSec * b.speed) % (h + 40) + (h + 40)) % (h + 40) - 20;
      var baseX = b.xFrac * w + Math.sin(tSec * b.omega + b.phase) * 14;

      ctx.beginPath();
      ctx.arc(baseX, baseY, b.r, 0, Math.PI * 2);
      ctx.strokeStyle = "rgba(" + strokeBase + ", " + b.alpha.toFixed(2) + ")";
      ctx.lineWidth = 1.4;
      ctx.stroke();

      // White specular highlight arc
      ctx.beginPath();
      ctx.arc(baseX, baseY, Math.max(1.5, b.r * 0.72), -Math.PI * 0.75, -Math.PI * 0.25);
      ctx.strokeStyle = "rgba(255, 255, 255, " + Math.min(0.45, b.alpha * 1.4).toFixed(2) + ")";
      ctx.lineWidth = 1.6;
      ctx.stroke();
    }
  }

  initBubbles();
  window.personaBubbles = {
    setCount: setParticleCount,
    drawAt: stepBubbles
  };

  window.persona.registerFrame(function (tSec) {
    stepBubbles(tSec);
  });
})();
