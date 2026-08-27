// ProgresSVG JavaScript for reveal.js integration

(function() {
  console.log('[ProgresSVG JS] Initializing...');

  function fixViewBox() {
    var svgs = document.querySelectorAll('svg[viewbox]');
    svgs.forEach(function(svg) {
      var viewbox = svg.getAttribute('viewbox');
      if (viewbox) {
        svg.removeAttribute('viewbox');
        svg.setAttribute('viewBox', viewbox);
      }
    });
  }

  // Check if a trigger element is visible (not inside a hidden fragment)
  function isTriggerVisible(trigger) {
    var el = trigger.parentElement;
    while (el) {
      if (el.classList.contains('fragment') && !el.classList.contains('visible')) {
        return false;
      }
      // Stop at slide boundary
      if (el.classList.contains('slide') || el.tagName === 'SECTION') {
        break;
      }
      el = el.parentElement;
    }
    return true;
  }

  // Scan all triggers on the current slide and show/hide SVG elements accordingly.
  // Non-visible triggers (inside hidden fragments) have NO effect.
  // The last visible trigger for each element determines its state.
  function updateVisibility() {
    var slide = Reveal.getCurrentSlide();
    if (!slide) return;

    var triggers = slide.querySelectorAll('.progressvg-trigger');

    // First pass: collect all elements and compute desired state
    // by replaying only visible triggers in DOM order
    var allElements = {};  // key -> { svgFile, elementId }
    var desiredState = {}; // key -> 'show' or 'hide'

    triggers.forEach(function(trigger) {
      var svgFile = trigger.getAttribute('data-svg-file');
      var elementId = trigger.getAttribute('data-element');
      var action = trigger.getAttribute('data-action');
      if (!svgFile || !elementId) return;

      var key = svgFile + '::' + elementId;
      allElements[key] = { svgFile: svgFile, elementId: elementId };

      // Only visible triggers affect state
      if (isTriggerVisible(trigger)) {
        desiredState[key] = action;
      }
    });

    // Second pass: apply states
    // Elements with no visible trigger stay hidden (their SVG default)
    for (var key in allElements) {
      var info = allElements[key];
      if (desiredState[key] === 'show') {
        showElement(slide, info.svgFile, info.elementId);
      } else {
        hideElement(slide, info.svgFile, info.elementId);
      }
    }
  }

  function showElement(slide, svgFile, elementId) {
    var element = findElement(slide, svgFile, elementId);
    if (element) {
      element.style.opacity = '1';
    }
  }

  function hideElement(slide, svgFile, elementId) {
    var element = findElement(slide, svgFile, elementId);
    if (element) {
      element.style.opacity = '0';
    }
  }

  function findElement(slide, svgFile, elementId) {
    var container = slide.querySelector('.progressvg-container[data-svg-file="' + svgFile + '"]');
    if (!container) return null;

    var svg = container.querySelector('svg');
    if (!svg) return null;

    return svg.querySelector('#' + CSS.escape(elementId));
  }

  var initialized = false;

  function initializeProgresSVG() {
    if (initialized) return;
    initialized = true;

    fixViewBox();

    // Read reveal.js transition config and set CSS speed accordingly
    var config = Reveal.getConfig();
    var speed = '0.4s'; // default
    if (config.transitionSpeed === 'fast') speed = '0.2s';
    else if (config.transitionSpeed === 'slow') speed = '0.8s';
    if (config.transition === 'none') speed = '0s';
    document.documentElement.style.setProperty('--progressvg-speed', speed);

    // Update on every state change
    Reveal.on('slidechanged', updateVisibility);
    Reveal.on('fragmentshown', updateVisibility);
    Reveal.on('fragmenthidden', updateVisibility);

    // Initial update for the first slide
    updateVisibility();
  }

  function initializeWhenReady() {
    if (typeof Reveal === 'undefined') {
      setTimeout(initializeWhenReady, 100);
      return;
    }

    Reveal.on('ready', function() {
      initializeProgresSVG();
    });

    if (Reveal.isReady && Reveal.isReady()) {
      initializeProgresSVG();
    }
  }

  initializeWhenReady();
})();
