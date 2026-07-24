{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const hostElement = document.querySelector('#flutter-host');
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: hostElement,
    });
    await appRunner.runApp();
  },
});
