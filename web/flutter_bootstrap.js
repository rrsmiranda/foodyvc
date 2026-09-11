// Template do bootstrap do Flutter web (`flutter build web` substitui os
// placeholders abaixo pelo JS do engine e pela config de build).
//
// ATENCAO: nao repita a sintaxe exata dos placeholders em comentarios —
// `flutter build web` faz replace de string ingenuo (nao JS-aware), entao
// qualquer ocorrencia literal do token, mesmo dentro de um comentario, e
// substituida tambem. Isso ja corrompeu este arquivo uma vez (o texto
// explicativo antigo citava os tokens por nome e acabava virando alvo do
// replace, quebrando o parsing e deixando a tela preta).
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
