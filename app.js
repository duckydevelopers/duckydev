'use strict';

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

// Native scrolling, with a single reveal as each block approaches the viewport.
const revealTargets = document.querySelectorAll('.section-intro, .fix-row, .guide-intro, .steps > li, .questions > div, .last-word');
let revealObserver;
if ('IntersectionObserver' in window && !reducedMotion.matches) {
  revealObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        revealObserver.unobserve(entry.target);
      }
    }
  }, { threshold: 0, rootMargin: '0px 0px -32px 0px' });
  revealTargets.forEach((target) => {
    if (target.getBoundingClientRect().top > window.innerHeight) {
      target.classList.add('reveal-pending');
      revealObserver.observe(target);
    }
  });
}

// Measure the stable wrapper so the card doesn't chase its own rotated bounds.
const stage = document.querySelector('[data-tilt]');
let tiltFrame = 0;
function resetTilt() {
  cancelAnimationFrame(tiltFrame);
  tiltFrame = 0;
  if (!stage) return;
  stage.classList.remove('is-tilting');
  stage.style.removeProperty('--tilt-x');
  stage.style.removeProperty('--tilt-y');
}
if (stage) {
  stage.addEventListener('pointermove', (event) => {
    if (reducedMotion.matches || !finePointer.matches || event.pointerType === 'touch') return;
    const bounds = stage.getBoundingClientRect();
    const x = Math.max(-.5, Math.min(.5, (event.clientX - bounds.left) / bounds.width - .5));
    const y = Math.max(-.5, Math.min(.5, (event.clientY - bounds.top) / bounds.height - .5));
    cancelAnimationFrame(tiltFrame);
    tiltFrame = requestAnimationFrame(() => {
      stage.classList.add('is-tilting');
      stage.style.setProperty('--tilt-x', `${(-y * 12).toFixed(2)}deg`);
      stage.style.setProperty('--tilt-y', `${(x * 14).toFixed(2)}deg`);
    });
  });
  stage.addEventListener('pointerleave', resetTilt);
  stage.addEventListener('pointercancel', resetTilt);
  window.addEventListener('blur', resetTilt);
}
reducedMotion.addEventListener('change', () => {
  resetTilt();
  if (reducedMotion.matches) {
    revealObserver?.disconnect();
    revealTargets.forEach(target => target.classList.add('is-visible'));
  }
});
finePointer.addEventListener('change', resetTilt);

document.querySelectorAll('[data-copy]').forEach((button) => {
  const originalLabel = button.innerHTML;
  let timer;
  button.addEventListener('click', async () => {
    const target = document.getElementById(button.dataset.copy);
    const status = document.getElementById('copy-status');
    const command = target.textContent.trim();
    clearTimeout(timer);
    try {
      await navigator.clipboard.writeText(command);
      button.textContent = 'Copied!';
      status.textContent = 'Command copied. Paste it into administrator PowerShell.';
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(target);
      selection.removeAllRanges();
      selection.addRange(range);
      button.textContent = 'Select & copy';
      status.textContent = 'Clipboard unavailable. The command is selected; press Ctrl+C or copy it manually.';
    }
    timer = setTimeout(() => { button.innerHTML = originalLabel; }, 3000);
  });
});
