(function () {
  'use strict';

  // Mobile menu toggle
  var toggle   = document.querySelector('.mobile-toggle');
  var mobileNav = document.querySelector('.mobile-nav');

  if (toggle && mobileNav) {
    toggle.addEventListener('click', function () {
      var isOpen = mobileNav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      mobileNav.setAttribute('aria-hidden', isOpen ? 'false' : 'true');
    });

    // Fecha ao clicar fora
    document.addEventListener('click', function (e) {
      if (!toggle.contains(e.target) && !mobileNav.contains(e.target)) {
        mobileNav.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
        mobileNav.setAttribute('aria-hidden', 'true');
      }
    });
  }
  // Sidebar tabs
  document.querySelectorAll('[data-tabs]').forEach(function (tabs) {
    var btns   = tabs.querySelectorAll('.tab-btn');
    var panels = tabs.querySelectorAll('.tab-panel');

    btns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var target = btn.dataset.tab;
        btns.forEach(function (b) { b.classList.remove('is-active'); b.setAttribute('aria-selected', 'false'); });
        panels.forEach(function (p) { p.hidden = true; p.classList.remove('is-active'); });
        btn.classList.add('is-active');
        btn.setAttribute('aria-selected', 'true');
        var panel = tabs.querySelector('#tab-' + target);
        if (panel) { panel.hidden = false; panel.classList.add('is-active'); }
      });
    });
  });
})();
