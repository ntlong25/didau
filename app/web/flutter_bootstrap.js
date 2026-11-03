{{flutter_js}}
{{flutter_build_config}}
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => {
      // Development builds do not contain the generated offline cache manifest.
    });
  });
}
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
