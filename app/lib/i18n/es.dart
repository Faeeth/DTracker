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
  String get victoire => 'Victoria';

  @override
  String get defaite => 'Derrota';

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
  String invitePasCompte(String nom) => '$nom no estaba entre los personajes seguidos en este combate.\nSu experiencia y su botín no cuentan en la sesión.';

  // ------------------------------------------ nouveautes de la version
  @override
  String notesTitre(String version) => 'DTracker $version';

  @override
  String get notesSousTitre => 'Esto es lo que ha cambiado.';

  @override
  String get notesNouveautes => 'Novedades';

  @override
  String get notesCorrectifs => 'Correcciones';

  @override
  String get notesAjustements => 'Ajustes';

  @override
  String get notesContinuer => 'Continuar';

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
  String get majOuvrir => 'Ver esta versión en GitHub';

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

  @override
  String get majInstaller => 'Actualizar';

  @override
  String get majReessayer => 'Reintentar';

  @override
  String majTelechargement(int pourcent) => 'Descargando… $pourcent %';

  @override
  String get majLancement => 'Iniciando el instalador. DTracker se cerrará.';

  @override
  String get majRate => 'La descarga no se ha completado. La página de la release sigue disponible.';

  @override
  String get valider => 'Aceptar';
  @override
  String get enregistrer => 'Guardar';
  @override
  String get nom => 'Nombre';

  // ------------------------------------------------------------- organizer
  @override
  String get organizer => 'Organizer';
  @override
  String get organizerOnglet => 'Tus equipos y sus atajos';
  @override
  String get organizerSousTitre =>
      'Una tecla por personaje, sea cual sea el equipo en juego';
  @override
  String get equipe => 'Equipo';
  @override
  String get nouvelleEquipe => 'Nuevo equipo';
  @override
  String get renommerEquipe => 'Renombrar el equipo';
  @override
  String get supprimerEquipe => 'Eliminar el equipo';
  @override
  String supprimerEquipeDetail(String equipe, int personnages) {
    final n = personnages == 1
        ? '$personnages personaje'
        : '$personnages personajes';
    return 'Se eliminarán «$equipe» y sus $n.';
  }

  @override
  String get equipeDesactivee => 'Equipo desactivado';
  @override
  String resumeEquipe(int actifs, int personnages) {
    final r = actifs == 1 ? '$actifs atajo activo' : '$actifs atajos activos';
    final p = personnages == 1
        ? '$personnages personaje'
        : '$personnages personajes';
    return '$r de $p';
  }

  @override
  String get isolerEquipe => 'Activar solo este equipo';
  @override
  String get replierEquipe => 'Plegar';
  @override
  String get deplierEquipe => 'Desplegar';
  @override
  String get ajouterPersonnage => 'Añadir un personaje';
  @override
  String get equipeVide => 'No hay personajes en este equipo.';
  @override
  String get aucuneEquipe => 'Ningún equipo';
  @override
  String get aucuneEquipeDetail =>
      'Crea un equipo y añade sus personajes. Varios equipos pueden compartir '
      'las mismas teclas: el atajo activa el personaje cuya ventana esté '
      'abierta.';
  @override
  String get creerEquipe => 'Crear un equipo';
  @override
  String get nouveauPersonnage => 'Nuevo personaje';
  @override
  String get modifierPersonnage => 'Editar el personaje';
  @override
  String get activerPersonnage => 'Activar el personaje';
  @override
  String get desactiverPersonnage => 'Desactivar el personaje';
  @override
  String get titreFenetre => 'Fragmento del título de la ventana';
  @override
  String get titreFenetreAide =>
      'Se busca en los títulos de las ventanas, sin distinguir mayúsculas.';
  @override
  String get tester => 'Probar';
  @override
  String get fenetreTrouvee => 'Ventana encontrada y activada.';
  @override
  String fenetreIntrouvable(String titre) =>
      'Ninguna ventana contiene «$titre».';
  @override
  String get classePersonnage => 'Clase';
  @override
  String get sansClasse => 'Sin clase';
  @override
  String get choisir => 'Elegir';
  @override
  String get changer => 'Cambiar';
  @override
  String get masculin => 'Masculino';
  @override
  String get feminin => 'Femenino';
  @override
  String get raccourci => 'Atajo';
  @override
  String get aucunRaccourci => 'Ninguno';
  @override
  String raccourciDe(String personnage) => 'Atajo de $personnage';
  @override
  String get raccourciInvite => 'Pulsa la combinación que quieras asignar.';
  @override
  String get raccourciAide =>
      'Esc para cancelar. Los atajos globales se suspenden durante la captura.';
  @override
  String get effacer => 'Borrar';
  @override
  String get raccourciImpossible =>
      'Windows no puede asociar esta tecla a un atajo.';
  @override
  String get modifierRaccourci => 'Modificar el atajo';
  @override
  String get raccourciRefuse =>
      'Rechazado por Windows: la tecla está reservada o ya la usa otra '
      'aplicación. Añade Ctrl, Alt o Mayús, o cambia de tecla.';
  @override
  String raccourcisActifs(int nombre) =>
      nombre == 1 ? '$nombre atajo activo' : '$nombre atajos activos';
  @override
  String raccourcisRefuses(int nombre) => nombre == 1
      ? '$nombre tecla ya ocupada por otra aplicación'
      : '$nombre teclas ya ocupadas por otra aplicación';
  @override
  String get captureEnCours => 'Capturando, atajos globales suspendidos';
  @override
  String aucuneFenetreTrouvee(String titres) =>
      'Ninguna ventana encontrada: $titres';
  @override
  String get reessayer => 'Reintentar';
  @override
  String get macros => 'Macros';
  @override
  String get macrosOnglet => 'Secuencias de gestos lanzadas por una tecla';
  @override
  String get macrosSousTitre => 'Acciones automatizadas';
  @override
  String get nouvelleMacro => 'Nueva macro';
  @override
  String get modifierMacro => 'Modificar la macro';
  @override
  String get renommerMacro => 'Renombrar la macro';
  @override
  String get supprimerMacro => 'Eliminar la macro';
  @override
  String supprimerMacroDetail(String macro, int actions) => actions == 1
      ? '«$macro» y su acción se borran. No hay vuelta atrás.'
      : '«$macro» y sus $actions acciones se borran. No hay vuelta atrás.';
  @override
  String get aucuneMacro => 'Ninguna macro';
  @override
  String get aucuneMacroDetail =>
      'Una macro escribe texto, pulsa teclas, hace clic y espera entre medias. '
      'Una tecla la lanza, estés donde estés.';
  @override
  String get creerMacro => 'Crear una macro';
  @override
  String get macroVide => 'Ninguna acción por ahora';
  @override
  String actions(int nombre) =>
      nombre == 1 ? '$nombre acción' : '$nombre acciones';
  @override
  String macrosActives(int nombre) =>
      nombre == 1 ? '$nombre macro activa' : '$nombre macros activas';
  @override
  String get macroDesactivee => 'Desactivada';
  @override
  String get activerMacro => 'Activar esta macro';
  @override
  String get desactiverMacro => 'Desactivar esta macro';
  @override
  String get jouerMacro => 'Ejecutar';
  @override
  String get arreterMacro => 'Detener';
  @override
  String macroEnCours(String macro) => '«$macro» en curso';
  @override
  String get actionsMacro => 'Acciones';
  @override
  String get personnageCible => 'Personaje objetivo';
  @override
  String get personnageCibleAide =>
      'Su ventana pasa al frente antes del primer gesto. En blanco, la macro '
      'se ejecuta en la ventana que ya esté delante.';
  @override
  String get fenetreAuPremierPlan => 'Ventana en primer plano';
  @override
  String get ajouterTexte => 'Texto';
  @override
  String get ajouterTouche => 'Tecla';
  @override
  String get ajouterPause => 'Pausa';
  @override
  String get texteAEcrire => 'Texto a escribir';
  @override
  String get dureeAttente => 'Espera en milisegundos';
  @override
  String get etapeTexte => 'Escribir';
  @override
  String get etapeTouche => 'Pulsar';
  @override
  String get etapePause => 'Esperar';
  @override
  String get monter => 'Subir';
  @override
  String get descendre => 'Bajar';
  @override
  String get toucheDejaPrise => 'Tecla ya ocupada por un personaje';
  @override
  String get arretMacros => 'Tecla de parada';
  @override
  String get arretMacrosAide =>
      'Detiene en seco la macro en curso. Es la única tecla que responde '
      'mientras una macro se ejecuta.';
  @override
  String get dupliquerMacro => 'Duplicar';
  @override
  String copieDe(String macro) => '$macro (copia)';
  @override
  String cadenceFrappe(int ms) => switch (ms) {
    <= 20 => 'Rápido',
    <= 30 => 'Normal',
    _ => 'Lento',
  };
  @override
  String get cadenceProfil =>
      'El ritmo de la escritura. Una ventana que pierde letras necesita uno '
      'más lento.';
  @override
  String get ajouterFenetre => 'Foco';
  @override
  String get etapeFenetre => 'Foco';
  @override
  String get fenetreAide =>
      'El nombre del personaje. Solo responden las ventanas del juego.';
  @override
  String horsDuJeu(String fenetre) => fenetre.isEmpty
      ? 'La macro se detiene: el juego no está en primer plano.'
      : 'La macro se detiene: «$fenetre» no es una ventana del juego.';
  @override
  String fenetrePasDevant(String cible, String obstacle) =>
      'Windows se negó a poner «$cible» delante: $obstacle tiene el teclado. '
      'No se escribió nada.';
  @override
  String get ajouterClic => 'Clic';
  @override
  String get ajouterBoucle => 'Bucle';
  @override
  String get etapeClic => 'Hacer clic';
  @override
  String get etapeBoucle => 'Repetir';
  @override
  String get viser => 'Apuntar';
  @override
  String get viserAide =>
      'Haz clic donde la macro deberá hacerlo. Esc para renunciar.';
  @override
  String get clicGauche => 'Clic izquierdo';
  @override
  String get clicDroit => 'Clic derecho';
  @override
  String get reglerBoucle => 'Ajustar el bucle';
  @override
  String get nombreDeTours => 'Número de vueltas';
  @override
  String repeterNFois(int tours) =>
      tours <= 1 ? '$tours vez' : '$tours veces';
  @override
  String pourChaque(String variable, int nombre) =>
      'para cada {$variable} (${valeurs(nombre)})';
  @override
  String get parcourirVariable => 'Recorrer una variable';
  @override
  String get variablesMacro => 'Variables';
  @override
  String get ajouterVariable => 'Añadir una variable';
  @override
  String get nomVariable => 'Nombre';
  @override
  String get valeursVariable => 'Valores, uno por línea';
  @override
  String get valeursAide =>
      'Un bucle recorre una variable; en sus textos, {nombre} es el valor de '
      'la vuelta. En otro sitio, {nombre} se escribe tal cual.';
  @override
  String get aucuneVariable => 'Ninguna variable';
  @override
  String valeurs(int nombre) =>
      nombre <= 1 ? '$nombre valor' : '$nombre valores';
}
