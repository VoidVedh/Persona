(function () {
  "use strict";

  function mulberry32(seed) {
    var a = seed >>> 0;
    return function () {
      var t = (a += 0x6d2b79f5);
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  var params = new URLSearchParams(window.location.search || "");
  var freezeParam = params.has("freeze") ? parseInt(params.get("freeze"), 10) : null;
  var seedParam = params.has("seed") ? parseInt(params.get("seed"), 10) : 7;
  var fixtureParam = params.get("fixture");
  var phaseParam = params.get("phase");
  var queryParam = params.get("q");

  var prng = mulberry32(isNaN(seedParam) ? 7 : seedParam);
  var listeners = [];
  var state = {};

  function applyRootAttributes(st) {
    var docEl = document.documentElement;
    var ph = phaseParam || st.phase || "daytime";
    docEl.setAttribute("data-phase", ph);
    if (st.calm) {
      docEl.setAttribute("data-calm", "1");
    } else {
      docEl.removeAttribute("data-calm");
    }
  }

  function notifyListeners() {
    applyRootAttributes(state);
    for (var i = 0; i < listeners.length; i++) {
      try {
        listeners[i](state);
      } catch (err) {
        console.error("persona listener error:", err);
      }
    }
  }

  function dispatch(envelopeOrPatch) {
    if (!envelopeOrPatch || typeof envelopeOrPatch !== "object") {
      return;
    }
    var patch = envelopeOrPatch.patch && typeof envelopeOrPatch.patch === "object"
      ? envelopeOrPatch.patch
      : envelopeOrPatch;

    var keys = Object.keys(patch);
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      state[k] = patch[k];
    }
    notifyListeners();
  }

  function post(type, payload) {
    var msg = {
      v: 1,
      type: String(type),
      payload: payload || {}
    };
    if (
      window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.persona &&
      typeof window.webkit.messageHandlers.persona.postMessage === "function"
    ) {
      window.webkit.messageHandlers.persona.postMessage(msg);
    } else if (window.parent && window.parent !== window) {
      window.parent.postMessage({ personaIntent: msg }, "*");
    }
  }

  function freezeAnimations(ms) {
    var targetTime = typeof ms === "number" && !isNaN(ms) ? ms : 0;
    if (typeof document.getAnimations === "function") {
      var anims = document.getAnimations({ subtree: true });
      for (var i = 0; i < anims.length; i++) {
        try {
          anims[i].pause();
          anims[i].currentTime = targetTime;
        } catch (_) {}
      }
    }
  }

  function applyFixture(name) {
    if (!name || !window.PERSONA_FIXTURES) {
      return false;
    }
    var fix = window.PERSONA_FIXTURES[name];
    if (!fix) {
      return false;
    }
    var copy = JSON.parse(JSON.stringify(fix));
    if (queryParam !== null && typeof copy.query === "string") {
      copy.query = queryParam;
    }
    dispatch(copy);
    return true;
  }

  // Single governed rAF loop per surface (§5.3 rule 4)
  var governorCallbacks = [];
  var governorRunning = false;
  var governorFps = 24;
  var lastFrameTime = 0;

  function setGovernorFps(fps) {
    var clamped = Math.max(12, Math.min(30, parseInt(fps, 10) || 24));
    governorFps = clamped;
  }

  function registerFrameCallback(fn) {
    if (typeof fn === "function") {
      governorCallbacks.push(fn);
      startGovernorIfNeeded();
    }
  }

  function stepGovernor(timestamp) {
    if (!governorRunning) {
      return;
    }
    if (document.documentElement.getAttribute("data-calm") === "1") {
      governorRunning = false;
      return;
    }
    var interval = 1000 / governorFps;
    if (timestamp - lastFrameTime >= interval) {
      var dt = lastFrameTime ? (timestamp - lastFrameTime) / 1000 : 1 / governorFps;
      lastFrameTime = timestamp;
      for (var i = 0; i < governorCallbacks.length; i++) {
        try {
          governorCallbacks[i](timestamp / 1000, Math.min(dt, 0.1));
        } catch (_) {}
      }
    }
    if (freezeParam !== null) {
      governorRunning = false;
      return;
    }
    window.requestAnimationFrame(stepGovernor);
  }

  function startGovernorIfNeeded() {
    if (governorRunning || governorCallbacks.length === 0) {
      return;
    }
    if (document.documentElement.getAttribute("data-calm") === "1") {
      return;
    }
    governorRunning = true;
    if (freezeParam !== null) {
      var frozenSec = (freezeParam || 0) / 1000;
      for (var i = 0; i < governorCallbacks.length; i++) {
        try {
          governorCallbacks[i](frozenSec, 1 / 24);
        } catch (_) {}
      }
      governorRunning = false;
      return;
    }
    window.requestAnimationFrame(stepGovernor);
  }

  function waitForFonts() {
    if (!document.fonts || typeof document.fonts.load !== "function") {
      return Promise.resolve();
    }
    var fontPromises = [
      document.fonts.load('400 32px "Bebas Neue"'),
      document.fonts.load('600 16px "Rajdhani"'),
      document.fonts.load('700 16px "Rajdhani"')
    ];
    var timeout = new Promise(function (resolve) {
      setTimeout(resolve, 600);
    });
    return Promise.race([Promise.all(fontPromises), timeout]).catch(function () {});
  }

  function bootSurface(surfaceName, defaultFixtureName) {
    if (document.documentElement.getAttribute("data-ready") === "1") {
      return;
    }
    var chosenFixture = fixtureParam || defaultFixtureName;
    if (chosenFixture) {
      applyFixture(chosenFixture);
    }
    if (phaseParam) {
      document.documentElement.setAttribute("data-phase", phaseParam);
    }

    waitForFonts().then(function () {
      var done = false;
      function completeBoot() {
        if (done) {
          return;
        }
        done = true;
        if (freezeParam !== null) {
          var frozenSec = (freezeParam || 0) / 1000;
          for (var i = 0; i < governorCallbacks.length; i++) {
            try {
              governorCallbacks[i](frozenSec, 1 / 24);
            } catch (_) {}
          }
          freezeAnimations(freezeParam);
        } else {
          startGovernorIfNeeded();
        }
        post("ready", { surface: surfaceName });
        document.documentElement.setAttribute("data-ready", "1");
      }
      if (typeof window.requestAnimationFrame === "function") {
        window.requestAnimationFrame(completeBoot);
      }
      setTimeout(completeBoot, 32);
    });
  }

  function wireDevHarnessIfPresent() {
    var sel = document.getElementById("fixture-select");
    var btnPhase = document.getElementById("btn-phase");
    var btnCalm = document.getElementById("btn-calm");
    if (!sel || !btnPhase || !btnCalm) {
      return;
    }
    var dark = false;
    var calm = false;
    sel.addEventListener("change", function () {
      var val = sel.value;
      if (val.indexOf("bar.") === 0) {
        document.getElementById("frame-topbar").src = "topbar.html?fixture=" + val;
      } else if (val.indexOf("hud.") === 0) {
        document.getElementById("frame-hud").src = "hud.html?fixture=" + val;
      } else if (val.indexOf("launcher.") === 0) {
        document.getElementById("frame-launcher").src = "launcher.html?fixture=" + val;
      }
    });
    btnPhase.addEventListener("click", function () {
      dark = !dark;
      var ph = dark ? "darkHour" : "daytime";
      ["frame-topbar", "frame-launcher", "frame-hud"].forEach(function (id) {
        var w = document.getElementById(id).contentWindow;
        if (w && w.persona) { w.persona.dispatch({ phase: ph }); }
      });
    });
    btnCalm.addEventListener("click", function () {
      calm = !calm;
      ["frame-topbar", "frame-launcher", "frame-hud"].forEach(function (id) {
        var w = document.getElementById(id).contentWindow;
        if (w && w.persona) { w.persona.dispatch({ calm: calm }); }
      });
    });
  }

  function autoBootFromDOM() {
    wireDevHarnessIfPresent();
    if (document.body && document.body.dataset && document.body.dataset.autoboot === "1") {
      var surf = document.body.dataset.surface || "topbar";
      var fix = document.body.dataset.fixture || null;
      bootSurface(surf, fix);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", autoBootFromDOM);
  } else {
    setTimeout(autoBootFromDOM, 0);
  }

  window.persona = {
    get state() {
      return state;
    },
    onState: function (fn) {
      if (typeof fn === "function") {
        listeners.push(fn);
        if (Object.keys(state).length > 0) {
          fn(state);
        }
      }
    },
    dispatch: dispatch,
    post: post,
    freeze: freezeAnimations,
    fixture: applyFixture,
    mulberry32: mulberry32,
    random: prng,
    registerFrame: registerFrameCallback,
    setFps: setGovernorFps,
    boot: bootSurface,
    params: params
  };
})();

