/// Les textes en espagnol.
///
/// Genere par `tools/langues.py` : corriger la table plutot que ce
/// fichier, sans quoi la correction sera perdue au prochain passage.
library;

import 'textes.dart';

class TextesEs extends Textes {
  const TextesEs();

  // ------------------------------------------------------------ commun
  @override
  String get marque => 'DTracker';

  @override
  String get pause => 'Pausa';

  @override
  String get reprendre => 'Reanudar';

  @override
  String get reset => 'Reiniciar';

  @override
  String get resetInfobulle => 'Cerrar esta sesión y abrir una nueva';

  @override
  String get quitter => 'Salir';

  @override
  String get sessions => 'Sesiones';

  @override
  String get reglages => 'Ajustes';

  @override
  String get vueCompacte => 'Cambiar a vista compacta';

  @override
  String get vueComplete => 'Volver a la vista completa';

  @override
  String get renommerSession => 'Haz clic para renombrar la sesión';

  @override
  String get fenetreBloquee => 'Ventana bloqueada — haz clic para poder moverla';

  @override
  String get fenetreLibre => 'Ventana libre — agárrala en cualquier punto para moverla';

  @override
  String get enPause => 'en pausa';

  @override
  String get enCours => 'en curso';

  @override
  String sessionNumero(int numero) => 'Sesión $numero';

  // ---------------------------------------------------------- colonnes
  @override
  String get colPersonnage => 'PERSONAJE';

  @override
  String get colNiveau => 'NIVEL';

  @override
  String get colExperience => 'EXPERIENCIA';

  @override
  String get colButin => 'BOTÍN';

  @override
  String get colObjets => 'OBJETOS';

  @override
  String get colCombats => 'COMBATES';

  @override
  String get colChallenges => 'DESAFÍOS';

  @override
  String get colDuree => 'DURACIÓN';

  @override
  String get colFinDuCombat => 'FIN DEL COMBATE';

  @override
  String get colTotal => 'TOTAL';

  @override
  String get colXp => 'XP';

  @override
  String get colPrix => 'PRECIO MEDIO';

  @override
  String get colQuantite => 'CANTIDAD';

  @override
  String get colPoids => 'PESO';

  @override
  String get colType => 'TIPO';

  // -------------------------------------------------------- navigation
  @override
  String get suivi => 'Resumen';

  @override
  String get suiviSousTitre => 'Resumen de la sesión en curso';

  @override
  String get mesCombats => 'Mis combates';

  @override
  String get mesCombatsSousTitre => 'Los combates de la sesión, del más reciente al más antiguo';

  @override
  String get monInventaire => 'Mi inventario';

  @override
  String get monInventaireSousTitre => 'Todo lo que el grupo ha recogido';

  @override
  String get sessionsSousTitre => 'Lista de las sesiones guardadas';

  @override
  String get reglagesSousTitre => 'Lo que la herramienta sigue, y cómo se muestra';

  @override
  String butinDe(String personnage) => 'Botín de $personnage';

  @override
  String get finDuCombat => 'Fin del combate';

  @override
  String get retour => 'Volver';

  // ------------------------------------------------------------- suivi
  @override
  String get horsCombat => 'Fuera de combate';

  @override
  String enCombatDepuis(String duree) => 'En combate  ·  $duree';

  @override
  String tour(int numero) => 'turno $numero';

  @override
  String get cadenceXp => 'xp/h';

  @override
  String get cadenceKamas => 'kamas/h';

  @override
  String get aucunPersonnageSuivi => 'Ningún personaje seguido';

  @override
  String get aucunPersonnageDetail => 'Añade alguno en los ajustes para ver sus ganancias aquí.';

  @override
  String get ouvrirLesReglages => 'Abrir los ajustes';

  @override
  String get enAttenteDuJeu => 'Esperando el juego';

  @override
  String aucunNaJoue(int suivis) => 'Ninguno de los $suivis personajes seguidos ha jugado todavía.';

  @override
  String get progressionInconnue => 'Progreso desconocido — no se ha recibido estado de este personaje';

  @override
  String progression(String dans, String du, String pourcent, String niveau, String gagne) => '$dans / $du XP\n$pourcent % del nivel $niveau\nde los cuales $gagne en esta sesión';

  @override
  String get cliquerPourCombats => 'Haz clic para ver sus combates';

  @override
  String get classeInconnue => 'Clase desconocida — aparecerá al pasar por el próximo mapa';

  @override
  String get ecarte => 'descartado';

  @override
  String get impose => 'impuesto';

  // ----------------------------------------------------------- combats
  @override
  String get aucunCombat => 'Ningún combate en esta sesión';

  @override
  String get aucunCombatDetail => 'La lista se completa al final de cada combate.';

  @override
  String get gagnants => 'GANADORES';

  @override
  String get perdants => 'PERDEDORES';

  @override
  String get adversaireInconnu => 'Adversario desconocido';

  @override
  String get personneNaGagne => 'Nadie ganó este combate';

  @override
  String nbCombats(int n) => '$n combates';

  // -------------------------------------------------------- inventaire
  @override
  String get aucunItem => 'Ningún objeto en el inventario de la sesión';

  @override
  String get triAucun => 'Sin orden';

  @override
  String get triNom => 'Ordenar por nombre';

  @override
  String get triPoids => 'Ordenar por peso';

  @override
  String get triPoidsLot => 'Ordenar por peso del lote';

  @override
  String get triQuantite => 'Ordenar por cantidad';

  @override
  String get triPrix => 'Ordenar por precio medio';

  @override
  String get triPrixLot => 'Ordenar por precio medio del lote';

  @override
  String get prixNonDisponible => 'Precio no disponible';

  @override
  String get lot => 'Lote';

  @override
  String get unitaire => 'Unidad';

  @override
  String get valeurEstimee => 'Valor estimado de los recursos';

  @override
  String get kamasEnPiece => 'Kamas en monedas';

  // ---------------------------------------------------------- sessions
  @override
  String get aucuneSession => 'Ninguna sesión guardada';

  @override
  String get aucuneSessionDetail => 'La sesión en curso aparecerá con su primera ganancia.';

  @override
  String dureeEcoute(String duree) => '$duree de escucha';

  @override
  String dureeEcouteReprises(String duree, int reprises) => '$duree de escucha, en $reprises tramos\nLas noches y las pausas no se cuentan.';

  @override
  String nbReprises(int n) => '$n tramos';

  @override
  String get reprendreSession => 'Reanudar esta sesión: vuelve a ser la sesión en curso';

  @override
  String get supprimerSession => 'Eliminar esta sesión';

  @override
  String get supprimerConfirme => 'Esta sesión se borrará definitivamente.';

  @override
  String get annuler => 'Cancelar';

  @override
  String get supprimer => 'Eliminar';

  // ---------------------------------------------------------- reglages
  @override
  String get ongletPersonnages => 'Personajes';

  @override
  String ongletPersonnagesAvecNombre(int n) => 'Personajes ($n)';

  @override
  String get ongletComptage => 'Recuento';

  @override
  String get ongletCapture => 'Captura';

  @override
  String get ongletFenetre => 'Ventana';

  @override
  String get ongletLangue => 'Idioma';

  @override
  String get nomDuPersonnage => 'Nombre del personaje';

  @override
  String get ajouter => 'Añadir';

  @override
  String get retirer => 'Quitar — sus contadores se borran';

  @override
  String get compterLesSucces => 'Contar los logros';

  @override
  String get compterLesSuccesDetail => 'La experiencia, los kamas y los recursos de los logros se\ncontarán en la sesión.';

  @override
  String get interfaceEcoute => 'INTERFAZ DE ESCUCHA DE RED';

  @override
  String get toutesLesInterfaces => 'Todas las interfaces';

  @override
  String get toutesLesInterfacesRecommande => 'Todas las interfaces (recomendado)';

  @override
  String introuvable(String valeur) => '$valeur (no encontrada)';

  @override
  String get toujoursDevant => 'Siempre delante';

  @override
  String get transparence => 'TRANSPARENCIA DE LA VISTA COMPACTA';

  @override
  String get transparenceDetail => 'El fondo no puede ser más opaco que el texto.';

  @override
  String get fond => 'Fondo';

  @override
  String get texte => 'Texto';

  @override
  String get apercu => 'VISTA PREVIA';

  @override
  String get langue => 'IDIOMA';

  @override
  String get langueDetail => 'El cambio surte efecto de inmediato.';

  // -------------------------------------------------------------- flux
  @override
  String get fluxConnecte => 'Conectado';

  @override
  String get fluxEnAttente => 'Esperando el juego';

  @override
  String get fluxInjoignable => 'Captura inalcanzable';

  @override
  String get fluxIndisponible => 'Captura no disponible';

  @override
  String get fluxDeconnecte => 'Desconectado';

  @override
  String diagEcouteSur(String carte) => 'Los eventos del juego están llegando.\nEscuchando en $carte.';

  @override
  String diagRienEntendu(String carte) => 'La captura funciona y responde, pero aún no ha oído nada.\nEscuchando en $carte.\n\nNormal si ningún personaje está conectado. Si el juego funciona,\nla tarjeta escuchada no lleva su tráfico: ponla en\n«Todas las interfaces», en Ajustes.';

  @override
  String get diagNeRepondPas => 'La difusión aún no responde.\n\nEstá arrancando — unos segundos — o se ha detenido por el camino.\nEl enlace se restablece solo en cuanto responda.';

  @override
  String get diagNaPasDemarre => 'La captura no ha podido arrancar.\nFalta el controlador npcap.';

  @override
  String get diagAucuneCapture => 'Ninguna captura en curso.';

  @override
  String get carteToutesPhysiques => 'todas las interfaces físicas';

  @override
  String carteNommee(String nom) => 'la interfaz $nom';

  // ------------------------------------------------------------- reste
  @override
  String get xp => 'XP';

  @override
  String get aucunPersonnageCompacte => 'Ningún personaje seguido — pasa a la vista completa para añadir';

  @override
  String enAttenteCompacte(int suivis) => 'Esperando: ninguno de los $suivis personajes seguidos ha jugado';

  @override
  String get suiviOnglet => 'La tabla de los personajes';

  @override
  String get mesCombatsOnglet => 'Todos los combates de la sesión';

  @override
  String get monInventaireOnglet => 'El botín del grupo, personaje por personaje';

  @override
  String get sonButin => 'Su botín en esta sesión';

  @override
  String get termineLe => 'TERMINADO EL';

  @override
  String get combatDejaCommence => 'El combate había empezado antes de que la herramienta escuchara.\nEl resumen no nombra a los adversarios.';

  @override
  String get reussi => 'logrado';

  @override
  String get echoue => 'fallado';

  @override
  String nbObjets(int n) => '$n objetos';

  @override
  String surTotal(int retenus, int total) => '$retenus de $total';

  @override
  String get inventaire => 'INVENTARIO';

  @override
  String get gainsComptesDetail => 'Las ganancias solo se cuentan para los personajes listados aquí — los tuyos,\ny los de tus amigos si quieres seguir al grupo.';

  @override
  String portraitIntrouvable(String classe) => '$classe — retrato no encontrado, ¿se han extraído las imágenes?';

  @override
  String classeNumero(int classe) => 'Clase $classe';

  // ------------------------------------------------- sessions et butin
  @override
  String get colSession => 'SESIÓN';

  @override
  String get enregistrees => 'GUARDADAS';

  @override
  String get valeur => 'VALOR';

  @override
  String get enPiece => 'EN MONEDAS';

  @override
  String get valeurRessources => 'VALOR ESTIMADO DE LOS RECURSOS';

  @override
  String get butinComplet => 'Botín completo';

  @override
  String get butinSession => 'El botín de la sesión, personajes a elegir';

  @override
  String get supprimerCetteSession => '¿Eliminar esta sesión?';

  @override
  String resumeSession(String combats, String xp, String kamas) => '$combats combates  ·  $xp xp  ·  $kamas kamas';

  @override
  String get aucuneSessionNaitDetail => 'Una sesión nace en su primer combate. Abrir la herramienta y cerrarla\nno deja ninguna huella.';

  @override
  String get reprendreDetail => 'Reanudar esta sesión: vuelve a ser la sesión actual\ny arranca de inmediato.';

  @override
  String get aucunPersonnageSession => 'Ningún personaje en esta sesión';

  @override
  String rapport(int reussis, int total) => '$reussis/$total';

  @override
  String invitePasCompte(String nom) => '$nom no está entre los personajes seguidos.\nSu experiencia y su botín no cuentan en la sesión.';

  @override
  String get reduire => 'Minimizar la ventana';

  @override
  String get fluxSansPilote => 'falta npcap';

  @override
  String get fluxSansCarte => 'Ninguna tarjeta que escuchar';

  @override
  String get diagSansPilote => 'El controlador npcap no está instalado.\n\nLeer el tráfico de red ocurre en el núcleo de Windows: hace falta un controlador,\ny ningún programa puede prescindir de él. npcap es gratuito y pesa un\nmegabyte; solo se instala una vez.\n\n→ npcap.com';

  @override
  String diagSansCarte(String carte) => 'El controlador está, pero ninguna tarjeta de red es escuchable.\nAjuste actual: $carte.\n\nElige «Todas las interfaces» en Ajustes → Captura.';

  @override
  String majTitre(String version) => 'DTracker $version está disponible';

  @override
  String majDetail(String courante) => 'Tienes la versión $courante.\n\nLa página de descarga se abrirá en tu navegador. Tus ajustes, tu historial\ny tus sesiones se conservan.';

  @override
  String get majOuvrir => 'Descargar';

  @override
  String get majPlusTard => 'Más tarde';

  @override
  String get premiereFoisTitre => 'Faltan los nombres y las imágenes';

  @override
  String get premiereFoisDetail => 'Los nombres de objetos, retratos e iconos pertenecen a Ankama: no pueden\nvenir con DTracker. Se toman de tu propio cliente.\n\nSin ellos la herramienta cuenta bien — experiencia, kamas y ritmos son exactos —\npero un objeto aparece como «Objeto 1731».';

  @override
  String get premiereFoisLancer => 'Extraer ahora';

  @override
  String get premiereFoisReessayer => 'Reintentar';

  @override
  String get premiereFoisPlusTard => 'Más tarde';

  @override
  String get premiereFoisDuree => 'Unos dos minutos y 265 MB. El juego puede estar cerrado.';

  @override
  String get premiereFoisRecherche => 'Buscando el cliente de Dofus…';

  @override
  String get premiereFoisFaite => 'Listo. Los nombres y las imágenes están en su sitio.';

  @override
  String get premiereFoisSansClient => 'No se ha encontrado la carpeta Dofus_Data. ¿Está el juego instalado en esta máquina?';

  @override
  String premiereFoisEchec(String detail) => 'La extracción se ha detenido: $detail';

}
