(function () {
  'use strict';

  const meta = document.querySelector('meta[name="plausible-domain"]');
  const domain = meta ? meta.content.trim() : '';
  if (!domain) return;

  window.plausible = window.plausible || function () {
    (window.plausible.q = window.plausible.q || []).push(arguments);
  };
  const script = document.createElement('script');
  script.defer = true;
  script.src = 'https://plausible.io/js/script.js';
  script.dataset.domain = domain;
  document.head.appendChild(script);
})();
