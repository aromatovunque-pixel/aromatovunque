/* Aromat Ovunque* — piccole animazioni comuni */
(function () {
  'use strict';

  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Spruzzo di granelli di sale nel punto (x, y) dello schermo
  function saltBurst(x, y, n) {
    if (reduced || !document.body || !Element.prototype.animate) return;
    n = n || 16;
    for (var i = 0; i < n; i++) {
      var s = document.createElement('span');
      s.className = 'salt';
      s.style.left = (x - 3) + 'px';
      s.style.top = (y - 3) + 'px';
      var a = Math.random() * Math.PI * 2;
      var d = 40 + Math.random() * 70;
      var dx = Math.cos(a) * d, dy = Math.sin(a) * d - 30;
      var size = 0.6 + Math.random() * 0.8;
      document.body.appendChild(s);
      s.animate([
        { transform: 'translate(0,0) scale(' + size + ') rotate(0deg)', opacity: 1 },
        { transform: 'translate(' + dx + 'px,' + (dy + 90) + 'px) scale(' + size + ') rotate(' + (Math.random() * 360) + 'deg)', opacity: 0 }
      ], { duration: 650 + Math.random() * 350, easing: 'cubic-bezier(.2,.7,.4,1)' }).onfinish = (function (el) {
        return function () { el.remove(); };
      })(s);
    }
  }

  // Piccola vibrazione (solo telefoni che la supportano)
  function buzz(ms) {
    try { if (navigator.vibrate) navigator.vibrate(ms || 12); } catch (e) {}
  }

  window.aromat = { saltBurst: saltBurst, buzz: buzz };
})();
