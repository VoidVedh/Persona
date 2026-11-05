(function () {
  "use strict";

  var canvas = document.getElementById("np-eq-canvas");
  if (!canvas || !window.persona) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var BAR_COUNT = 28;
  var BAR_W = 7;
  var BAR_GAP = 3;
  var heights = new Array(BAR_COUNT);
  var phases1 = new Array(BAR_COUNT);
  var phases2 = new Array(BAR_COUNT);
  var phases3 = new Array(BAR_COUNT);

  var rng = window.persona.random;
  for (var i = 0; i < BAR_COUNT; i++) {
    heights[i] = 0.25;
    phases1[i] = rng() * Math.PI * 2;
    phases2[i] = rng() * Math.PI * 2;
    phases3[i] = rng() * Math.PI * 2;
  }

  var playState = "playing";
  var isDarkHour = false;

  function setPlayState(st, dark) {
    playState = st || "playing";
    isDarkHour = Boolean(dark);
  }

  function stepAndDraw(timeSec) {
    if (!ctx) return;
    var w = canvas.width;
    var h = canvas.height;
    var mainH = Math.floor(h * 0.76);
    var reflH = h - mainH - 2;

    ctx.clearRect(0, 0, w, h);

    var cyanHex = isDarkHour ? "#5dffcf" : "#00d8ff";
    var royalHex = isDarkHour ? "#1ca682" : "#0051ff";

    for (var i = 0; i < BAR_COUNT; i++) {
      var env = 1.0 - 0.52 * (i / (BAR_COUNT - 1));
      var n =
        0.5 +
        0.28 * Math.sin(timeSec * 4.3 + phases1[i] + i * 0.35) +
        0.18 * Math.sin(timeSec * 7.1 + phases2[i] - i * 0.22) +
        0.12 * Math.cos(timeSec * 11.4 + phases3[i]);
      if (n < 0.08) n = 0.08;
      if (n > 1.0) n = 1.0;

      var target;
      if (playState === "playing") {
        target = Math.max(0.12, env * n);
      } else if (playState === "paused") {
        target = 0.08;
      } else {
        target = 0.14 + 0.08 * Math.sin(timeSec * 1.8 + i * 0.3);
      }

      var cur = heights[i];
      if (target > cur) {
        cur = cur + (target - cur) * 0.5;
      } else {
        cur = cur + (target - cur) * 0.18;
      }
      heights[i] = cur;

      var barPx = Math.max(6, Math.round(cur * mainH));
      var x = i * (BAR_W + BAR_GAP) * 2;
      var bw = BAR_W * 2;
      var y = mainH - barPx;

      var grad = ctx.createLinearGradient(0, y, 0, mainH);
      grad.addColorStop(0, "#ffffff");
      grad.addColorStop(0.28, cyanHex);
      grad.addColorStop(1, royalHex);

      ctx.fillStyle = grad;
      ctx.fillRect(x, y, bw, barPx);

      // 25% mirrored reflection below baseline
      var rPx = Math.max(2, Math.round(barPx * 0.25));
      ctx.globalAlpha = 0.28;
      ctx.fillStyle = cyanHex;
      ctx.fillRect(x, mainH + 3, bw, Math.min(reflH, rPx));
      ctx.globalAlpha = 1.0;
    }
  }

  window.personaEQ = {
    setPlayState: setPlayState,
    drawAt: stepAndDraw
  };

  window.persona.registerFrame(function (tSec) {
    stepAndDraw(tSec);
  });
})();
