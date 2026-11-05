(function () {
  "use strict";

  var shellEl = document.getElementById("topbar-shell");
  var wsStripEl = document.getElementById("ws-strip");
  var focusAppEl = document.getElementById("focus-app");
  var focusTitleEl = document.getElementById("focus-title");
  var tickerTextA = document.getElementById("ticker-text-a");
  var tickerTextB = document.getElementById("ticker-text-b");
  var dryRunChip = document.getElementById("dryrun-chip");
  var clockTimeEl = document.getElementById("clock-time");
  var clockDowEl = document.getElementById("clock-dow");
  var clockDomEl = document.getElementById("clock-dom");
  var exitBtn = document.getElementById("exit-btn");

  var pillCpu = document.getElementById("hw-cpu");
  var valCpu = document.getElementById("val-cpu");
  var fillCpu = document.getElementById("fill-cpu");

  var pillMem = document.getElementById("hw-mem");
  var valMem = document.getElementById("val-mem");
  var fillMem = document.getElementById("fill-mem");

  var pillBat = document.getElementById("hw-bat");
  var valBat = document.getElementById("val-bat");
  var fillBat = document.getElementById("fill-bat");

  var pillWifi = document.getElementById("hw-wifi");
  var valWifi = document.getElementById("val-wifi");
  var fillWifi = document.getElementById("fill-wifi");

  var pillVol = document.getElementById("hw-vol");
  var valVol = document.getElementById("val-vol");
  var fillVol = document.getElementById("fill-vol");

  var wsPills = [];

  function buildWorkspacePills() {
    while (wsStripEl.firstChild) {
      wsStripEl.removeChild(wsStripEl.firstChild);
    }
    wsPills = [];
    for (var i = 1; i <= 5; i++) {
      (function (idx) {
        var wrapper = document.createElement("div");
        wrapper.className = "plate ws-pill";
        wrapper.setAttribute("data-index", String(idx));

        var back = document.createElement("i");
        back.className = "plate__back s-para";
        back.style.setProperty("--sk", "7px");

        var mid = document.createElement("i");
        mid.className = "plate__mid s-para";
        mid.style.setProperty("--sk", "7px");

        var face = document.createElement("span");
        face.className = "plate__face s-para";
        face.style.setProperty("--sk", "7px");

        var slash = document.createElement("span");
        slash.className = "ws-pill__slash";

        var label = document.createElement("span");
        label.textContent = idx < 10 ? "0" + idx : String(idx);

        var dot = document.createElement("span");
        dot.className = "ws-pill__dot";

        face.appendChild(slash);
        face.appendChild(label);
        face.appendChild(dot);

        wrapper.appendChild(back);
        wrapper.appendChild(mid);
        wrapper.appendChild(face);

        wrapper.addEventListener("click", function () {
          window.persona.post("switchSpace", { n: idx });
        });

        wsStripEl.appendChild(wrapper);
        wsPills.push({ root: wrapper, dot: dot });
      })(i);
    }
  }

  function clamp01(v) {
    if (isNaN(v) || v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  function renderState(st) {
    if (!st) return;

    // Notch geometry
    var notchW = st.screen && st.screen.notch && st.screen.notch.w ? Number(st.screen.notch.w) : 0;
    if (notchW > 0) {
      shellEl.setAttribute("data-notched", "1");
      shellEl.style.setProperty("--center-col", notchW + "px");
    } else {
      shellEl.removeAttribute("data-notched");
      shellEl.style.setProperty("--center-col", "auto");
    }

    // Workspaces
    var spaces = Array.isArray(st.spaces) ? st.spaces : [];
    for (var i = 0; i < wsPills.length; i++) {
      var info = spaces[i] || { index: i + 1, active: i === 0, occupied: i === 0 };
      var p = wsPills[i];
      if (info.active) {
        p.root.setAttribute("data-active", "1");
      } else {
        p.root.removeAttribute("data-active");
      }
      if (!info.occupied && !info.active) {
        p.root.setAttribute("data-empty", "1");
        p.dot.style.display = "none";
      } else {
        p.root.removeAttribute("data-empty");
        p.dot.style.display = "block";
      }
    }

    // Focused app & title
    focusAppEl.textContent = st.focusedApp || "DESKTOP";
    focusTitleEl.textContent = st.focusedTitle || "Persona 3 Reload";

    // Center ticker
    var np = st.nowPlaying;
    var tickerStr;
    if (np && np.state === "playing" && np.title) {
      tickerStr = "♪ " + np.title + " — " + (np.artist || "ATLUS SOUND TEAM") + "   ◈   " + (st.slot || "AFTER SCHOOL") + "   ◈   ";
    } else {
      tickerStr = "◈ " + (st.slot || "AFTER SCHOOL") + "   ◈   DARK HOUR · MEMENTO MORI   ◈   S.E.E.S. TACTICAL LINK   ◈   ";
    }
    tickerTextA.textContent = tickerStr;
    tickerTextB.textContent = tickerStr;

    // Telemetry
    var tel = st.telemetry || {};
    var cpu = typeof tel.cpu === "number" ? tel.cpu : 0;
    valCpu.textContent = cpu + "%";
    fillCpu.style.setProperty("--v", String(clamp01(cpu / 100)));
    pillCpu.setAttribute("data-level", cpu >= 85 ? "warn" : "normal");

    var mem = typeof tel.mem === "number" ? tel.mem : 0;
    valMem.textContent = mem + "%";
    fillMem.style.setProperty("--v", String(clamp01(mem / 100)));
    pillMem.setAttribute("data-level", mem >= 85 ? "warn" : "normal");

    if (tel.battery === null || typeof tel.battery === "undefined") {
      pillBat.style.display = "none";
    } else {
      pillBat.style.display = "";
      var bat = Number(tel.battery);
      valBat.textContent = (tel.charging ? "⚡" : "") + bat + "%";
      fillBat.style.setProperty("--v", String(clamp01(bat / 100)));
      pillBat.setAttribute("data-level", (!tel.charging && bat <= 20) ? "alert" : "normal");
    }

    var wifiBars = typeof tel.wifiBars === "number" ? tel.wifiBars : 4;
    valWifi.textContent = wifiBars > 0 ? wifiBars + "/4" : "OFF";
    fillWifi.style.setProperty("--v", String(clamp01(wifiBars / 4)));

    var vol = typeof tel.volume === "number" ? tel.volume : 50;
    var muted = Boolean(tel.muted);
    valVol.textContent = muted ? "MUTE" : vol + "%";
    fillVol.style.setProperty("--v", String(muted ? 0 : clamp01(vol / 100)));

    // Dry run chip
    if (st.runMode === "dryRun") {
      dryRunChip.removeAttribute("hidden");
    } else {
      dryRunChip.setAttribute("hidden", "hidden");
    }

    // Clock
    var cTime = st.clockTime || "16:42";
    clockTimeEl.textContent = cTime;
    clockTimeEl.setAttribute("data-text", cTime);

    var cDay = (st.clockDay || "THU 05").split(" ");
    clockDowEl.textContent = cDay[0] || "THU";
    clockDomEl.textContent = cDay[1] || "05";
  }

  buildWorkspacePills();

  if (exitBtn) {
    exitBtn.addEventListener("click", function () {
      window.persona.post("exit", {});
    });
  }

  window.persona.onState(renderState);
})();

