(function () {
  'use strict';

  const domain = document.documentElement.dataset.plausibleDomain;
  const hasConfiguredDomain = Boolean(domain && domain.trim());

  // The page remains analytics-free until the deployment supplies a Plausible
  // domain. This keeps local previews and forks privacy-preserving by default.
  if (!hasConfiguredDomain) return;

  window.plausible = window.plausible || function () {
    (window.plausible.q = window.plausible.q || []).push(arguments);
  };

  const script = document.createElement('script');
  script.defer = true;
  script.src = 'https://plausible.io/js/script.js';
  script.dataset.domain = domain;
  document.head.appendChild(script);

  document.querySelectorAll('[data-analytics-notice]').forEach(function (notice) {
    notice.hidden = false;
  });

  function track(eventName, properties) {
    if (!hasConfiguredDomain || typeof window.plausible !== 'function') return;
    window.plausible(eventName, { props: properties || {} });
  }

  document.querySelectorAll('[data-plausible-event]').forEach(function (element) {
    element.addEventListener('click', function () {
      const properties = {};
      if (element.dataset.plausibleTarget) {
        properties.target = element.dataset.plausibleTarget;
      }
      track(element.dataset.plausibleEvent, properties);
    });
  });

  const locale = document.documentElement.lang || 'en';
  track('locale_selected', { locale: locale });
})();
