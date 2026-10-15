{{flutter_js}}
{{flutter_build_config}}

// No service worker: Pages serves fresh files on reload, and a cached app
// would outlive the data format it was built for.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('loading')?.remove();
  },
});
