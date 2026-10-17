const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function fixture() {
  const handlers = {};
  vm.runInNewContext(fs.readFileSync('web/rad_pointer_alignment.js', 'utf8'), {
    document: { addEventListener: (name, listener) => { handlers[name] = listener; } },
    getComputedStyle: node => node.style,
  });
  const node = {
    getAttribute: () => 'rad-navigation-visa',
    getBoundingClientRect: () => ({ left: 80, right: 145, top: 771, bottom: 836 }),
  };
  function click(detail = 1, target = node) {
    const result = { prevented: false, stopped: false };
    handlers.click({ detail, composedPath: () => [target],
      preventDefault: () => { result.prevented = true; },
      stopImmediatePropagation: () => { result.stopped = true; },
    });
    return result;
  }
  function pointer(x, y, type = 'touch') {
    handlers.pointerdown({ pointerType: type, clientX: x, clientY: y });
  }
  return { handlers, node, click, pointer };
}

test('outside touch retargeted into a navigation DOM click is suppressed', () => {
  for (const [x, y] of [[105, 840], [105, 762], [79, 800], [145, 800]]) {
    const f = fixture(); f.pointer(x, y);
    assert.deepEqual(f.click(), { prevented: true, stopped: true });
  }
});
test('real center, icon and label touches retain navigation and Flutter ink', () => {
  const f = fixture();
  for (const y of [803, 797, 819]) {
    f.pointer(112, y);
    assert.deepEqual(f.click(), { prevented: false, stopped: false });
  }
});
test('keyboard and assistive semantic activation are preserved', () => {
  const f = fixture(); f.pointer(105, 840);
  assert.equal(f.click(0).prevented, false);
  assert.equal(f.click().prevented, false);
});
test('mouse, cancelled touches and unrelated controls are unchanged', () => {
  const f = fixture(); f.pointer(105, 840, 'mouse');
  assert.equal(f.click().prevented, false);
  f.pointer(105, 840); f.handlers.pointercancel();
  assert.equal(f.click().prevented, false);
  f.pointer(105, 840);
  assert.equal(f.click(1, { getAttribute: () => null }).prevented, false);
});
test('bounds come from live layout after orientation or zoom, never offsets', () => {
  const f = fixture();
  f.node.getBoundingClientRect = () => ({ left: 400, right: 480, top: 300, bottom: 364 });
  f.pointer(440, 330); assert.equal(f.click().prevented, false);
  f.pointer(440, 370); assert.equal(f.click().prevented, true);
});
test('clipped scroll content cannot steal touches from navigation headroom', () => {
  const f = fixture();
  const content = {
    getAttribute: () => null, hasAttribute: name => name === 'flt-tappable',
    getBoundingClientRect: () => ({ left: 180, right: 300, top: 270, bottom: 340 }),
    parentElement: {
      style: { overflowX: 'hidden', overflowY: 'hidden' },
      getBoundingClientRect: () => ({ left: 0, right: 844, top: 0, bottom: 306 }),
    },
  };
  f.pointer(228, 308); assert.equal(f.click(1, content).prevented, true);
  f.pointer(228, 290); assert.equal(f.click(1, content).prevented, false);
});
