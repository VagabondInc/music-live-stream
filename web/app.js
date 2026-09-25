/* ASCII Broadcast — page preview renderer.
 *
 * A small, honest imitation of the Folded City scene family: a drawn corridor
 * whose density and accents follow a synthetic musical envelope. The shipping
 * app renders the same grammar from real audio analysis at 1080p30.
 */

(function () {
  "use strict";

  var RAMP = " .:-=+*#%@";
  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function Field(el, cols, rows) {
    this.el = el;
    this.cols = cols;
    this.rows = rows;
  }

  // Deterministic value noise so the preview is stable frame to frame.
  function hash(x, y, seed) {
    var h = (x * 374761393 + y * 668265263 + seed * 2654435761) >>> 0;
    h = (h ^ (h >>> 13)) >>> 0;
    h = (h * 1274126177) >>> 0;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
  }

  function envelope(t) {
    // Four-bar phrase at 122 BPM with a beat pulse on top.
    var bar = (t / (4 * 60 / 122)) % 4;
    var phrase = 0.45 + 0.35 * Math.sin((bar / 4) * Math.PI * 2 - Math.PI / 2);
    var beat = Math.pow(1 - ((t * (122 / 60)) % 1), 2.2);
    return Math.min(1, phrase + beat * 0.35);
  }

  function render(field, time) {
    var cols = field.cols;
    var rows = field.rows;
    var energy = envelope(time);
    var drift = time * 0.42;
    var out = "";
    var cx = cols / 2;
    var cy = rows * 0.46;

    for (var y = 0; y < rows; y++) {
      var line = "";
      for (var x = 0; x < cols; x++) {
        var dx = (x - cx) / cx;
        var dy = (y - cy) / cy;
        var radius = Math.sqrt(dx * dx + dy * dy * 1.9) + 0.0001;

        // Perspective corridor: rings receding toward the vanishing point.
        var depth = 1 / radius;
        var ring = (depth * 1.25 - drift) % 1;
        var onRing = ring < 0.055 ? 1 : 0;

        // Radial structure ribs.
        var angle = Math.atan2(dy, dx);
        var rib = Math.abs(Math.sin(angle * 8)) > 0.985 && radius > 0.16 ? 1 : 0;

        // Platform floor and ceiling bands.
        var band = (Math.abs(dy) > 0.62 && Math.abs(dy) < 0.72) ? 0.55 : 0;

        var haze = hash(x, y, 7) * 0.22;
        var value = onRing * (0.55 + energy * 0.45) + rib * 0.6 + band + haze;

        // Vanishing point glow, pulsed by the envelope.
        if (radius < 0.12) value += (0.12 - radius) * 6 * (0.5 + energy);

        value = Math.max(0, Math.min(0.999, value * (0.55 + energy * 0.7)));
        line += RAMP[Math.floor(value * RAMP.length)];
      }
      out += line + "\n";
    }
    field.el.textContent = out;
  }

  function fit(el, charW, charH) {
    var rect = el.getBoundingClientRect();
    return {
      cols: Math.max(40, Math.floor(rect.width / charW)),
      rows: Math.max(14, Math.floor(rect.height / charH))
    };
  }

  var fields = [];
  var big = document.getElementById("ascii");
  var small = document.getElementById("asciiSmall");

  function layout() {
    fields = [];
    if (big) {
      var a = fit(big, 5.42, 9.2);
      fields.push(new Field(big, a.cols, a.rows));
    }
    if (small) {
      var b = fit(small, 3.92, 6.65);
      fields.push(new Field(small, b.cols, b.rows));
    }
  }

  // Queue list, matching the demo programme shipped in the app.
  var TRACKS = [
    ["01", "GLASS CITIES", "04:06", true],
    ["02", "PAPER SATELLITES", "05:21", false],
    ["03", "NEON FIELDS", "04:38", false],
    ["04", "RAIN ARCHIVE", "03:52", false],
    ["05", "FOLDED MAPS", "06:14", false],
    ["06", "LOSSLESS DAYS", "04:27", false],
    ["07", "SIGNAL DRIFT", "05:03", false]
  ];

  var queueList = document.getElementById("queueList");
  if (queueList) {
    TRACKS.forEach(function (row) {
      var li = document.createElement("li");
      if (row[3]) li.className = "is-current";
      li.innerHTML =
        '<em>' + row[0] + "</em>" +
        '<i class="dot ' + (row[3] ? "dot--amber" : "dot--green") + '"></i>' +
        "<span>" + row[1] + "</span><b>" + row[2] + "</b>";
      queueList.appendChild(li);
    });
  }

  function timecode(seconds) {
    var h = Math.floor(seconds / 3600);
    var m = Math.floor((seconds % 3600) / 60);
    var s = Math.floor(seconds % 60);
    var f = Math.floor((seconds % 1) * 30);
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    return pad(h) + ":" + pad(m) + ":" + pad(s) + ":" + pad(f);
  }

  var hudTC = document.getElementById("hudTC");
  var deckTC = document.getElementById("deckTC");
  var playhead = document.getElementById("playhead");
  var start = 102.6;
  var last = 0;

  function frame(now) {
    var time = now / 1000;
    // Hold the preview to ~20 fps: this is a marketing page, not the encoder.
    if (time - last > 0.05) {
      last = time;
      for (var i = 0; i < fields.length; i++) render(fields[i], time);
      var programTime = start + time;
      if (hudTC) hudTC.textContent = timecode(programTime);
      if (deckTC) deckTC.textContent = timecode(programTime);
      if (playhead) playhead.style.left = (36 + ((programTime / 360) % 1) * 24).toFixed(2) + "%";
    }
    requestAnimationFrame(frame);
  }

  layout();
  window.addEventListener("resize", layout);

  if (reduceMotion) {
    for (var i = 0; i < fields.length; i++) render(fields[i], 8);
    if (hudTC) hudTC.textContent = timecode(start);
  } else {
    requestAnimationFrame(frame);
  }
})();
