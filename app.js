'use strict';

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
