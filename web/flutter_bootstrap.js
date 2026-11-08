{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: function (engineInitializer) {
    engineInitializer.initializeEngine().then(function (appRunner) {
      appRunner.runApp();
    });
  },
});
