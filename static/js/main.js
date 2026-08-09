// Copy button, for every code block on the site.
//
// The button reads `data-copy-target` (the id of the element holding the text)
// when one is given, and otherwise the `code` inside the `.ax-codeblock` it
// sits in. Both forms exist because /code labels one snippet for analytics and
// the rest are anonymous.
//
// This is progressive enhancement. Every code block is readable and
// selectable without it.
document.addEventListener('DOMContentLoaded', function () {
  var track = function (name, props) {
    if (name && window.posthog && typeof window.posthog.capture === 'function') {
      window.posthog.capture(name, props || {});
    }
  };

  document.querySelectorAll('.js-copy').forEach(function (btn) {
    var source = function () {
      if (btn.dataset.copyTarget) {
        return document.getElementById(btn.dataset.copyTarget);
      }
      var block = btn.closest('.ax-codeblock');
      return block ? block.querySelector('code') : null;
    };

    btn.addEventListener('click', function () {
      var src = source();
      if (!src || !navigator.clipboard) { return; }

      navigator.clipboard.writeText(src.innerText.trim()).then(function () {
        var original = btn.textContent;
        btn.dataset.copied = 'true';
        btn.textContent = 'Copied';
        setTimeout(function () {
          btn.removeAttribute('data-copied');
          btn.textContent = original;
        }, 2000);
        track(btn.dataset.copyEvent, { snippet: btn.dataset.copySnippet || '' });
      });
    });
  });
});
