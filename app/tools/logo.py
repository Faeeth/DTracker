# -*- coding: utf-8 -*-
"""Taille le logo pour ses trois usages.

Le logo fourni est large — le mot « DTracker » sur trois cent quatre-vingts
pixels de haut. Trois choses en sortent :

  app_icon.ico    l'icone de l'executable, de la barre des taches et de la
                  liste des programmes. Carree, en six tailles : Windows pioche
                  la sienne selon l'endroit, et une icone unique redimensionnee
                  a la volee bave a seize pixels.

  logo.png        le logo entier, pour le rail — il porte deja le nom, et
                  remplace donc l'icone **et** le texte.

  marque.png      la partie haute, carree : ce qui reste lisible quand la
                  place manque.
"""
import os

from PIL import Image

SOURCE = ('C:/Users/orfre/.claude/image-cache/'
          'ef29350c-b3d9-447b-90fe-c4b08a3c4247/2.png')
APP = 'D:/claude/dtracker/app'

src = Image.open(SOURCE).convert('RGBA')
print('source :', src.size)

# Le logo est entoure de transparent : on le recadre sur ce qui est peint,
# sans quoi l'icone serait un timbre perdu au milieu d'un carre vide.
boite = src.getbbox()
logo = src.crop(boite)
print('recadre :', logo.size)

os.makedirs(f'{APP}/assets/marque', exist_ok=True)

# ------------------------------------------------------------ le logo entier
large = logo.copy()
large.thumbnail((512, 512), Image.LANCZOS)
large.save(f'{APP}/assets/marque/logo.png')
print('logo.png :', large.size)

# ------------------------------------------------------------- l'icone carree
# Le logo entier, centre dans un carre, plutot qu'un morceau decoupe : c'est
# un bloc horizontal dont les elements se chevauchent, et toute decoupe
# tranchait le mot ou la pousse. Une marge l'empeche de toucher les bords, ou
# Windows arrondit et rogne selon l'endroit.
l, h = logo.size
cote = int(max(l, h) * 1.06)
carre = Image.new('RGBA', (cote, cote), (0, 0, 0, 0))
carre.paste(logo, ((cote - l) // 2, (cote - h) // 2), logo)

carre.resize((256, 256), Image.LANCZOS).save(f'{APP}/assets/marque/marque.png')
print('marque.png : 256x256')

# Windows choisit la taille qui l'arrange : les lui donner toutes evite un
# redimensionnement a la volee, qui bave a seize pixels.
tailles = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128),
           (256, 256)]
carre.save(f'{APP}/windows/runner/resources/app_icon.ico', sizes=tailles)
print('app_icon.ico :', ', '.join(f'{t[0]}' for t in tailles))
