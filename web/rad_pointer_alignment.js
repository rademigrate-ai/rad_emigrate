// Flutter's canvas already hit-tests actual pointer coordinates. Mobile Chrome
// can additionally retarget a touch just OUTSIDE a semantics button into a DOM
// click inside it. Suppress only this extra navigation click, using the actual
// laid-out DOM bounds. No offsets, enlarged targets or changes to Flutter ink.
(() => {
  let lastTouch = null;
  document.addEventListener('pointerdown', event => {
    lastTouch = event.pointerType === 'touch'
      ? { x: event.clientX, y: event.clientY }
      : null;
  }, true);
  document.addEventListener('pointercancel', () => { lastTouch = null; }, true);
  document.addEventListener('click', event => {
    const touch = lastTouch;
    lastTouch = null;
    // Keyboard, screen-reader activation and synthetic semantics actions may
    // carry no pointer, and must retain their normal accessibility behavior.
    if (!touch || event.detail === 0) return;
    const target = event.composedPath().find(element =>
      element.getAttribute?.('flt-semantics-identifier')?.startsWith('rad-navigation-') ||
      element.hasAttribute?.('flt-tappable')
    );
    if (!target) return;
    const navigation = target.getAttribute('flt-semantics-identifier')?.startsWith('rad-navigation-');
    const bounds = target.getBoundingClientRect();
    let outside = navigation && (touch.x < bounds.left || touch.x >= bounds.right ||
      touch.y < bounds.top || touch.y >= bounds.bottom);
    // At short/landscape heights, native touch adjustment can also choose a
    // scrolled body control whose semantics rectangle extends beyond its
    // painted scroll viewport into the navigation headroom. Honor actual CSS
    // clipping ancestors too; do not alter ordinary content target adjustment.
    for (let parent = target.parentElement; parent; parent = parent.parentElement) {
      const style = getComputedStyle(parent);
      const clip = parent.getBoundingClientRect();
      if (/hidden|clip|auto|scroll/.test(style.overflowX) &&
          (touch.x < clip.left || touch.x >= clip.right)) outside = true;
      if (/hidden|clip|auto|scroll/.test(style.overflowY) &&
          (touch.y < clip.top || touch.y >= clip.bottom)) outside = true;
    }
    if (outside) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }, true);
})();
