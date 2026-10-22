// Azu app progressive enhancement. Every page works without this file; it adds the colour
// theme toggle and copy buttons for command snippets. Loaded with `defer` from the same
// origin, so it runs under a strict Content-Security-Policy (script-src 'self').
(function () {
  "use strict";

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $all(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }
  function store(op, key, value) {
    try { return op === "get" ? localStorage.getItem(key) : op === "set" ? localStorage.setItem(key, value) : localStorage.removeItem(key); } catch (e) { return null; }
  }

  /* ---- Theme toggle: system -> light -> dark (same storage key as the Azu example app) ---- */
  var toggle = $("[data-theme-toggle]");
  if (toggle) {
    var root = document.documentElement;
    var order = ["system", "light", "dark"];
    var current = function () { return root.getAttribute("data-theme") || "system"; };
    var paint = function () {
      var mode = current();
      toggle.setAttribute("data-mode", mode);
      var label = $("[data-theme-label]", toggle);
      var visible = mode === "system" ? "Auto" : mode === "light" ? "Light" : "Dark";
      if (label) label.textContent = visible;
      // The accessible name starts with the visible text (WCAG 2.5.3, label in name).
      toggle.setAttribute("aria-label", visible + " colour theme. Activate to change.");
    };
    toggle.hidden = false;
    toggle.addEventListener("click", function () {
      var next = order[(order.indexOf(current()) + 1) % order.length];
      if (next === "system") { root.removeAttribute("data-theme"); store("remove", "azu-theme"); }
      else { root.setAttribute("data-theme", next); store("set", "azu-theme", next); }
      paint();
    });
    paint();
  }

  /* ---- Copy buttons: <button data-copy="text" hidden> next to a command ---- */
  var status = $("[data-copy-status]");
  function announce(message) {
    if (!status) return;
    status.textContent = "";
    setTimeout(function () { status.textContent = message; }, 30);
  }
  function fallbackCopy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.className = "sr-only";
    document.body.appendChild(area);
    area.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(area);
    return ok;
  }
  $all("[data-copy]").forEach(function (button) {
    button.hidden = false;
    var label = $("[data-copy-label]", button);
    var idle = label ? label.textContent : "";
    var reset;
    button.addEventListener("click", function () {
      var text = button.getAttribute("data-copy");
      var done = function (ok) {
        if (label) label.textContent = ok ? "Copied" : "Press Ctrl+C";
        announce(ok ? "Copied: " + text : "Copy failed. Select the command and press Ctrl+C.");
        clearTimeout(reset);
        reset = setTimeout(function () { if (label) label.textContent = idle; }, 2000);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(fallbackCopy(text)); });
      } else {
        done(fallbackCopy(text));
      }
    });
  });
})();
