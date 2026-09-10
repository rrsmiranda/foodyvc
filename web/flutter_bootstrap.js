// Template do bootstrap do Flutter web. Os tokens {{flutter_js}} e
// {{flutter_build_config}} sao substituidos por `flutter build web`.
//
// Diferenca do padrao: monta a app dentro de #phone (a moldura de celular
// definida no index.html) em vez de ocupar a pagina inteira — assim o
// MediaQuery ve tamanho de celular.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    hostElement: document.querySelector("#phone"),
  },
});
