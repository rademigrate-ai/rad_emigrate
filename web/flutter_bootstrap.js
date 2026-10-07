{{flutter_js}}
{{flutter_build_config}}

function showStartupFailure() {
  document.getElementById('rad-startup-spinner')?.remove();
  const fa = document.getElementById('rad-startup-fa');
  const en = document.getElementById('rad-startup-en');
  if (fa) fa.textContent = 'بارگذاری انجام نشد. دوباره تلاش کنید.';
  if (en) en.textContent = 'RAD could not load. Please try again.';
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
