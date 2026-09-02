"""Releve les chaines affichees a l'ecran, fichier par fichier.

    python tools/textes.py      # ecrit TEXTES.md a la racine du projet

Exhaustif plutot que fin : mieux vaut relire trois libelles techniques de trop
que d'en manquer un vrai. Les concatenations sur plusieurs lignes sont
recollees, sans quoi les descriptions — justement ce qu'on vient relire —
paraissaient en morceaux.
"""
import io
import os
import re

import os.path
PROJET = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RACINE = os.path.join(PROJET, 'lib')
SORTIE = os.path.join(PROJET, 'TEXTES.md')

CHAINE = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")

ACCENTS = 'éèêëàâçùûüôöîïœæÉÈÊÀÇÔÎ«»…—·'


def affichable(brut: str) -> bool:
    """Le texte a-t-il l'air destine a un lecteur ?"""
    if len(brut) < 3:
        return False
    if '_' in brut or brut.startswith('#'):
        return False           # clef de donnees, code couleur
    if re.fullmatch(r"[\w./\-]+\.(json|png|jpg|jpeg|ttf|otf|dart|exe|py)", brut):
        return False           # chemin de fichier
    if re.fullmatch(r"[a-z0-9/.\-]+", brut):
        return False           # identifiant, code, clef
    if re.fullmatch(r"[\s\W]+", brut):
        return False           # separateurs seuls
    return (' ' in brut or any(c.isupper() for c in brut)
            or any(c in brut for c in ACCENTS))


def releve(chemin: str) -> list[tuple[int, str]]:
    lignes = io.open(chemin, encoding='utf-8').read().splitlines()
    trouve: list[tuple[int, str]] = []
    precedente = -2
    for n, ligne in enumerate(lignes, 1):
        nu = ligne.strip()
        if nu.startswith('//') or nu.startswith('import ')  \
                or nu.startswith('export ') or nu.startswith('library'):
            continue
        # Une chaine comparee ou aiguillee est un code du protocole, pas un
        # libelle : « FightEnd », « ItemGained » ne s'affichent nulle part.
        if re.search(r"==|!=|\bcase\b|\bswitch\b|\['|contains\(", nu):
            continue
        for m in CHAINE.finditer(ligne):
            brut = m.group(1) if m.group(1) is not None else m.group(2)
            if not affichable(brut):
                continue
            # Une description coupee en plusieurs litteraux : on recolle.
            if trouve and n - precedente <= 1 and nu.startswith(("'", '"')):
                debut, avant = trouve[-1]
                trouve[-1] = (debut, avant + brut)
            else:
                trouve.append((n, brut))
            precedente = n
    return trouve


ECRANS = [
    ('main.dart', 'Demarrage'),
    ('config.dart', 'Reglages (valeurs)'),
    ('vue/fenetre.dart', 'Fenetre'),
    ('vue/barre.dart', 'Barre de titre'),
    ('vue/compacte.dart', 'Vue compacte'),
    ('vue/ligne.dart', 'Vue compacte / ligne de personnage'),
    ('vue/standard/coquille.dart', 'Vue standard / coquille'),
    ('vue/standard/rail.dart', 'Vue standard / rail lateral'),
    ('vue/standard/navigation.dart', 'Vue standard / navigation'),
    ('vue/standard/briques.dart', 'Briques communes'),
    ('vue/standard/pages/suivi.dart', 'Page Suivi'),
    ('vue/standard/pages/combats.dart', 'Page Mes combats'),
    ('vue/standard/pages/objets.dart', 'Page Mon inventaire'),
    ('vue/standard/pages/inventaire.dart', 'Inventaire (composant)'),
    ('vue/standard/pages/butin.dart', 'Butin d\'un personnage'),
    ('vue/standard/pages/sessions.dart', 'Page Sessions'),
    ('vue/standard/pages/reglages.dart', 'Page Reglages'),
    ('source/flux.dart', 'Etat de la capture'),
    ('source/ressources.dart', 'Ressources'),
    ('source/archives.dart', 'Archives'),
    ('modele/session.dart', 'Modele'),
    ('theme.dart', 'Theme'),
]

vus = {rel for rel, _ in ECRANS}
for dossier, _, fichiers in os.walk(RACINE):
    for f in sorted(fichiers):
        if not f.endswith('.dart'):
            continue
        rel = os.path.relpath(os.path.join(dossier, f), RACINE).replace('\\', '/')
        if rel.startswith('i18n/'):
            continue          # les traductions elles-memes, pas des libelles
        if rel not in vus:
            ECRANS.append((rel, f'Ailleurs / {rel}'))

sortie = []
total = 0
for rel, titre in ECRANS:
    chemin = os.path.join(RACINE, rel)
    if not os.path.exists(chemin):
        continue
    lignes = releve(chemin)
    if not lignes:
        continue
    total += len(lignes)
    sortie.append(f'\n## {titre}\n\n`lib/{rel}`\n')
    for n, brut in lignes:
        sortie.append(f'- `L{n}` · {brut}')

entete = f"""# Les textes de DTracker — ce qui reste en dur

**Les libelles traduits ne sont pas ici** : ils vivent dans
`tools/langues.py`, la table des quatre langues. Ce releve ne sert qu'a
reperer ce qui n'y a pas encore ete verse.
""" + f"""

Tout ce qui s'affiche a l'ecran, ecran par ecran — {total} entrees. Chacune
porte sa ligne : annoter ici, la correction se reporte ensuite d'un geste.

Les `$quelquechose` sont des valeurs inserees a l'execution : garder le nom
tel quel, seul ce qu'il y a autour se recrit. Quelques entrees ou le texte
enjambe une condition sont recollees de travers — le fichier et la ligne
restent justes, c'est ce qui compte pour aller corriger.

Ce releve est **produit**, pas tenu a la main : il vieillit des la premiere
retouche. Il sert a relire, pas a stocker. Voir la fin du fichier pour la
suite — un vrai fichier de textes, si l'on va vers la traduction.

    python tools/textes.py      # pour le refaire
"""

pied = """

---

## Et pour la traduction ?

Il n'y a pas aujourd'hui de fichier des textes : chaque libelle est ecrit a
l'endroit ou il s'affiche. Deux facons d'en sortir, selon l'ambition.

**Un fichier `lib/textes.dart`.** Une classe de constantes, `Textes.pause`,
`Textes.aucunPersonnage`. Ca rassemble la relecture en un seul endroit et ne
demande aucune dependance. Ca ne traduit rien tout seul : il faudra encore
choisir la langue quelque part et dupliquer la classe.

**`flutter_localizations` et des fichiers ARB.** La voie prevue par Flutter :
un `.arb` par langue, du code genere, la langue du systeme prise en compte
d'office, et le pluriel et les nombres formates selon la locale. Plus de
ceremonie, mais c'est ce qui tient quand une deuxieme langue arrive vraiment.
"""

io.open(SORTIE, 'w', encoding='utf-8', newline='\n').write(
    entete + '\n'.join(sortie) + pied)
print(f'{total} chaines relevees')
