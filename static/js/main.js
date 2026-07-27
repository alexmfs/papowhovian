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
  // Carousels
  document.querySelectorAll('.carousel').forEach(function (carousel) {
    var slides  = carousel.querySelectorAll('.carousel-slide');
    var dots    = carousel.querySelectorAll('.carousel-dot');
    var btnPrev = carousel.querySelector('.carousel-arrow--prev');
    var btnNext = carousel.querySelector('.carousel-arrow--next');
    var current = 0;

    if (!slides.length) return;

    function goTo(index) {
      slides[current].classList.remove('is-active');
      slides[current].setAttribute('aria-hidden', 'true');
      dots[current].classList.remove('is-active');
      current = (index + slides.length) % slides.length;
      slides[current].classList.add('is-active');
      slides[current].setAttribute('aria-hidden', 'false');
      dots[current].classList.add('is-active');
    }

    dots.forEach(function (dot, i) {
      dot.addEventListener('click', function () { goTo(i); });
    });

    if (btnPrev) btnPrev.addEventListener('click', function () { goTo(current - 1); });
    if (btnNext) btnNext.addEventListener('click', function () { goTo(current + 1); });
  });

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
