/// Les textes en portugais.
///
/// Genere par `tools/langues.py` : corriger la table plutot que ce
/// fichier, sans quoi la correction sera perdue au prochain passage.
library;

import 'textes.dart';

class TextesPt extends Textes {
  const TextesPt();

  // ------------------------------------------------------------ commun
  @override
  String get marque => 'DTracker';

  @override
  String get pause => 'Pausa';

  @override
  String get reprendre => 'Retomar';

  @override
  String get reset => 'Reiniciar';

  @override
  String get resetInfobulle => 'Encerrar esta sessão e abrir uma nova';

  @override
  String get quitter => 'Sair';

  @override
  String get sessions => 'Sessões';

  @override
  String get reglages => 'Configurações';

  @override
  String get vueCompacte => 'Mudar para a vista compacta';

  @override
  String get vueComplete => 'Voltar à vista completa';

  @override
  String get renommerSession => 'Clique para renomear a sessão';

  @override
  String get fenetreBloquee => 'Janela bloqueada — clique para poder movê-la';

  @override
  String get fenetreLibre => 'Janela livre — segure-a em qualquer ponto para movê-la';

  @override
  String get enPause => 'em pausa';

  @override
  String get enCours => 'em curso';

  @override
  String sessionNumero(int numero) => 'Sessão $numero';

  // ---------------------------------------------------------- colonnes
  @override
  String get colPersonnage => 'PERSONAGEM';

  @override
  String get colNiveau => 'NÍVEL';

  @override
  String get colExperience => 'EXPERIÊNCIA';

  @override
  String get colButin => 'ESPÓLIO';

  @override
  String get colObjets => 'ITENS';

  @override
  String get colCombats => 'COMBATES';

  @override
  String get colChallenges => 'DESAFIOS';

  @override
  String get colDuree => 'DURAÇÃO';

  @override
  String get colFinDuCombat => 'FIM DO COMBATE';

  @override
  String get colTotal => 'TOTAL';

  @override
  String get colXp => 'XP';

  @override
  String get colPrix => 'PREÇO MÉDIO';

  @override
  String get colQuantite => 'QUANTIDADE';

  @override
  String get colPoids => 'PESO';

  @override
  String get colType => 'TIPO';

  // -------------------------------------------------------- navigation
  @override
  String get suivi => 'Resumo';

  @override
  String get suiviSousTitre => 'Resumo da sessão em curso';

  @override
  String get mesCombats => 'Os meus combates';

  @override
  String get mesCombatsSousTitre => 'Os combates da sessão, do mais recente ao mais antigo';

  @override
  String get monInventaire => 'O meu inventário';

  @override
  String get monInventaireSousTitre => 'Tudo o que o grupo apanhou';

  @override
  String get sessionsSousTitre => 'Lista das sessões guardadas';

  @override
  String get reglagesSousTitre => 'O que a ferramenta segue, e como se apresenta';

  @override
  String butinDe(String personnage) => 'Espólio de $personnage';

  @override
  String get finDuCombat => 'Fim do combate';

  @override
  String get retour => 'Voltar';

  // ------------------------------------------------------------- suivi
  @override
  String get horsCombat => 'Fora de combate';

  @override
  String enCombatDepuis(String duree) => 'Em combate  ·  $duree';

  @override
  String tour(int numero) => 'turno $numero';

  @override
  String get cadenceXp => 'xp/h';

  @override
  String get cadenceKamas => 'kamas/h';

  @override
  String get aucunPersonnageSuivi => 'Nenhum personagem seguido';

  @override
  String get aucunPersonnageDetail => 'Adicione alguns nas configurações para ver os ganhos aqui.';

  @override
  String get ouvrirLesReglages => 'Abrir as configurações';

  @override
  String get enAttenteDuJeu => 'À espera do jogo';

  @override
  String aucunNaJoue(int suivis) => 'Nenhum dos $suivis personagens seguidos jogou ainda.';

  @override
  String get progressionInconnue => 'Progresso desconhecido — nenhum estado recebido deste personagem';

  @override
  String progression(String dans, String du, String pourcent, String niveau, String gagne) => '$dans / $du XP\n$pourcent % do nível $niveau\ndos quais $gagne nesta sessão';

  @override
  String get cliquerPourCombats => 'Clique para ver os seus combates';

  @override
  String get classeInconnue => 'Classe desconhecida — aparecerá na próxima mudança de mapa';

  @override
  String get ecarte => 'descartado';

  @override
  String get impose => 'imposto';

  // ----------------------------------------------------------- combats
  @override
  String get aucunCombat => 'Nenhum combate nesta sessão';

  @override
  String get aucunCombatDetail => 'A lista enche-se ao fim de cada combate.';

  @override
  String get gagnants => 'VENCEDORES';

  @override
  String get perdants => 'PERDEDORES';

  @override
  String get adversaireInconnu => 'Adversário desconhecido';

  @override
  String get personneNaGagne => 'Ninguém ganhou este combate';

  @override
  String nbCombats(int n) => '$n combates';

  // -------------------------------------------------------- inventaire
  @override
  String get aucunItem => 'Nenhum item no inventário da sessão';

  @override
  String get triAucun => 'Sem ordenação';

  @override
  String get triNom => 'Ordenar por nome';

  @override
  String get triPoids => 'Ordenar por peso';

  @override
  String get triPoidsLot => 'Ordenar por peso do lote';

  @override
  String get triQuantite => 'Ordenar por quantidade';

  @override
  String get triPrix => 'Ordenar por preço médio';

  @override
  String get triPrixLot => 'Ordenar por preço médio do lote';

  @override
  String get prixNonDisponible => 'Preço indisponível';

  @override
  String get lot => 'Lote';

  @override
  String get unitaire => 'Unidade';

  @override
  String get valeurEstimee => 'Valor estimado dos recursos';

  @override
  String get kamasEnPiece => 'Kamas em moedas';

  // ---------------------------------------------------------- sessions
  @override
  String get aucuneSession => 'Nenhuma sessão guardada';

  @override
  String get aucuneSessionDetail => 'A sessão em curso aparecerá no seu primeiro ganho.';

  @override
  String dureeEcoute(String duree) => '$duree de escuta';

  @override
  String dureeEcouteReprises(String duree, int reprises) => '$duree de escuta, em $reprises retomas\nAs noites e as pausas não são contadas.';

  @override
  String nbReprises(int n) => '$n retomas';

  @override
  String get reprendreSession => 'Retomar esta sessão: volta a ser a sessão em curso';

  @override
  String get supprimerSession => 'Eliminar esta sessão';

  @override
  String get supprimerConfirme => 'Esta sessão será apagada definitivamente.';

  @override
  String get annuler => 'Cancelar';

  @override
  String get supprimer => 'Eliminar';

  // ---------------------------------------------------------- reglages
  @override
  String get ongletPersonnages => 'Personagens';

  @override
  String ongletPersonnagesAvecNombre(int n) => 'Personagens ($n)';

  @override
  String get ongletComptage => 'Contagem';

  @override
  String get ongletCapture => 'Captura';

  @override
  String get ongletFenetre => 'Janela';

  @override
  String get ongletLangue => 'Idioma';

  @override
  String get nomDuPersonnage => 'Nome do personagem';

  @override
  String get ajouter => 'Adicionar';

  @override
  String get retirer => 'Remover — os seus contadores são apagados';

  @override
  String get compterLesSucces => 'Contar as conquistas';

  @override
  String get compterLesSuccesDetail => 'A experiência, os kamas e os recursos das conquistas serão\ncontados na sessão.';

  @override
  String get interfaceEcoute => 'INTERFACE DE ESCUTA DE REDE';

  @override
  String get toutesLesInterfaces => 'Todas as interfaces';

  @override
  String get toutesLesInterfacesRecommande => 'Todas as interfaces (recomendado)';

  @override
  String introuvable(String valeur) => '$valeur (não encontrada)';

  @override
  String get toujoursDevant => 'Sempre à frente';

  @override
  String get transparence => 'TRANSPARÊNCIA DA VISTA COMPACTA';

  @override
  String get transparenceDetail => 'O fundo não pode ser mais opaco que o texto.';

  @override
  String get fond => 'Fundo';

  @override
  String get texte => 'Texto';

  @override
  String get apercu => 'PRÉ-VISUALIZAÇÃO';

  @override
  String get langue => 'IDIOMA';

  @override
  String get langueDetail => 'A alteração tem efeito imediato.';

  // -------------------------------------------------------------- flux
  @override
  String get fluxConnecte => 'Ligado';

  @override
  String get fluxEnAttente => 'À espera do jogo';

  @override
  String get fluxInjoignable => 'Captura inacessível';

  @override
  String get fluxIndisponible => 'Captura indisponível';

  @override
  String get fluxDeconnecte => 'Desligado';

  @override
  String diagEcouteSur(String carte) => 'Os eventos do jogo estão a chegar.\nA escutar em $carte.';

  @override
  String diagRienEntendu(String carte) => 'A captura funciona e responde, mas ainda não ouviu nada.\nA escutar em $carte.\n\nNormal se nenhum personagem estiver ligado. Se o jogo corre,\na placa escutada não transporta o seu tráfego: defina-a para\n«Todas as interfaces», nas Configurações.';

  @override
  String get diagNeRepondPas => 'A difusão ainda não responde.\n\nEstá a arrancar — alguns segundos — ou parou pelo caminho.\nA ligação restabelece-se sozinha assim que responder.';

  @override
  String get diagNaPasDemarre => 'A captura não conseguiu arrancar.\nFalta o controlador npcap.';

  @override
  String get diagAucuneCapture => 'Nenhuma captura em curso.';

  @override
  String get carteToutesPhysiques => 'todas as interfaces físicas';

  @override
  String carteNommee(String nom) => 'a interface $nom';

  // ------------------------------------------------------------- reste
  @override
  String get xp => 'XP';

  @override
  String get aucunPersonnageCompacte => 'Nenhum personagem seguido — passe à vista completa para adicionar';

  @override
  String enAttenteCompacte(int suivis) => 'À espera: nenhum dos $suivis personagens seguidos jogou ainda';

  @override
  String get suiviOnglet => 'A tabela dos personagens';

  @override
  String get mesCombatsOnglet => 'Todos os combates da sessão';

  @override
  String get monInventaireOnglet => 'O espólio do grupo, personagem por personagem';

  @override
  String get sonButin => 'O seu espólio nesta sessão';

  @override
  String get termineLe => 'TERMINADO EM';

  @override
  String get combatDejaCommence => 'O combate começara antes de a ferramenta escutar.\nO resumo não nomeia os adversários.';

  @override
  String get reussi => 'conseguido';

  @override
  String get echoue => 'falhado';

  @override
  String nbObjets(int n) => '$n itens';

  @override
  String surTotal(int retenus, int total) => '$retenus de $total';

  @override
  String get inventaire => 'INVENTÁRIO';

  @override
  String get gainsComptesDetail => 'Os ganhos só são contados para os personagens listados aqui — os seus,\ne os dos seus amigos se quiser seguir o grupo.';

  @override
  String portraitIntrouvable(String classe) => '$classe — retrato não encontrado, as imagens foram extraídas?';

  @override
  String classeNumero(int classe) => 'Classe $classe';

  // ------------------------------------------------- sessions et butin
  @override
  String get colSession => 'SESSÃO';

  @override
  String get enregistrees => 'GUARDADAS';

  @override
  String get valeur => 'VALOR';

  @override
  String get enPiece => 'EM MOEDAS';

  @override
  String get valeurRessources => 'VALOR ESTIMADO DOS RECURSOS';

  @override
  String get butinComplet => 'Espólio completo';

  @override
  String get butinSession => 'O espólio da sessão, personagens à escolha';

  @override
  String get supprimerCetteSession => 'Eliminar esta sessão?';

  @override
  String resumeSession(String combats, String xp, String kamas) => '$combats combates  ·  $xp xp  ·  $kamas kamas';

  @override
  String get aucuneSessionNaitDetail => 'Uma sessão nasce no seu primeiro combate. Abrir a ferramenta e fechá-la\nnão deixa qualquer rasto.';

  @override
  String get reprendreDetail => 'Retomar esta sessão: volta a ser a sessão atual\ne recomeça de imediato.';

  @override
  String get aucunPersonnageSession => 'Nenhum personagem nesta sessão';

  @override
  String rapport(int reussis, int total) => '$reussis/$total';

  @override
  String invitePasCompte(String nom) => '$nom não faz parte dos personagens seguidos.\nA sua experiência e o seu espólio não contam na sessão.';

  @override
  String get reduire => 'Minimizar a janela';

  @override
  String get fluxSansPilote => 'npcap em falta';

  @override
  String get fluxSansCarte => 'Nenhuma placa para escutar';

  @override
  String get diagSansPilote => 'O controlador npcap não está instalado.\n\nLer o tráfego de rede acontece no núcleo do Windows: é preciso um controlador,\ne nenhum programa o dispensa. O npcap é gratuito e pesa um megabyte;\nsó se instala uma vez.\n\n→ npcap.com';

  @override
  String diagSansCarte(String carte) => 'O controlador está lá, mas nenhuma placa de rede é escutável.\nDefinição atual: $carte.\n\nEscolha «Todas as interfaces» em Configurações → Captura.';

}
