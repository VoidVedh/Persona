(function () {
  "use strict";

  var wpStageEl = document.getElementById("wp-stage");
  var monthEl = document.getElementById("date-month");
  var dayEl = document.getElementById("date-day");
  var dowEl = document.getElementById("dow-label");
  var slotEl = document.getElementById("slot-label");
  var moonLitPathEl = document.getElementById("moon-lit-path");
  var moonCountdownEl = document.getElementById("moon-countdown");

  var npWidgetEl = document.getElementById("hud-nowplaying");
  var npTitleEl = document.getElementById("np-title");
  var npArtistEl = document.getElementById("np-artist");

  function setOutlineText(el, val) {
    if (!el) return;
    el.textContent = val;
    el.setAttribute("data-text", val);
  }

  function renderHud(st) {
    if (!st) return;

    if (wpStageEl) {
      wpStageEl.setAttribute("data-mode", st.wallpaperMode || "overlay");
    }

    setOutlineText(monthEl, st.month || "11");
    setOutlineText(dayEl, st.day || "05");

    if (dowEl) {
      dowEl.textContent = st.dow || "THU";
    }
    if (slotEl) {
      slotEl.textContent = st.slot || "AFTER SCHOOL";
    }

    var isDark = (st.phase === "darkHour") || (document.documentElement.getAttribute("data-phase") === "darkHour");
    var moon = st.moon || { p: 0.25, daysToFull: 8, hoursToFull: 12 };
    var pVal = isDark ? 0.5 : (typeof moon.p === "number" ? moon.p : 0.25);

    if (moonLitPathEl && window.personaMoon) {
      var d = window.personaMoon.computeLitPath(pVal, 100, 100, 32);
      moonLitPathEl.setAttribute("d", d);
      moonLitPathEl.setAttribute("fill", isDark ? "#5dffcf" : "#e8f6ff");
    }

    if (moonCountdownEl) {
      if (isDark) {
        moonCountdownEl.textContent = "FULL MOON";
      } else if (moon.countdown) {
        moonCountdownEl.textContent = moon.countdown;
      } else {
        var totalDays = typeof moon.toFullDays === "number" ? moon.toFullDays : (moon.daysToFull || 5.58);
        var dd = String(Math.floor(totalDays)).padStart(2, "0");
        var hh = String(Math.floor((totalDays - Math.floor(totalDays)) * 24)).padStart(2, "0");
        moonCountdownEl.textContent = "T-" + dd + "D " + hh + "H";
      }
    }

    // Now Playing
    var np = st.nowPlaying || { state: "playing", title: "COLOR YOUR NIGHT", artist: "ATLUS SOUND TEAM" };
    if (npWidgetEl) {
      npWidgetEl.setAttribute("data-state", np.state || "playing");
    }
    if (npTitleEl) {
      npTitleEl.textContent = np.state === "none" ? "NOTHING PLAYING" : (np.title || "COLOR YOUR NIGHT");
    }
    if (npArtistEl) {
      npArtistEl.textContent = np.state === "none" ? "S.E.E.S. AUDIO UNIT" : (np.artist || "ATLUS SOUND TEAM");
    }

    if (window.personaEQ) {
      window.personaEQ.setPlayState(np.state || "playing", isDark);
      window.personaEQ.drawAt(1.5);
    }

    if (window.personaBubbles) {
      if (typeof st.particles === "number") {
        window.personaBubbles.setCount(st.particles);
      }
      window.personaBubbles.drawAt(1.5);
    }

    if (typeof st.fps === "number" && window.persona.setFps) {
      window.persona.setFps(st.fps);
    }
  }

  window.persona.onState(renderHud);
})();
