{{flutter_js}}
{{flutter_build_config}}

function showStartupFailure() {
  document.querySelector('.rad-startup-bird')?.remove();
  const message = document.getElementById('rad-startup-message');
  if (message) message.textContent = window.radStartupFa
    ? 'بارگذاری انجام نشد. دوباره تلاش کنید.'
    : 'RAD could not load. Please try again.';
  const retry = document.getElementById('rad-startup-retry');
  if (retry) retry.hidden = false;
}

document.getElementById('rad-startup-retry')?.addEventListener('click', () => window.location.reload());
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('rad-startup')?.remove();
    } catch (_) {
      showStartupFailure();
    }
  }
}).catch(showStartupFailure);
