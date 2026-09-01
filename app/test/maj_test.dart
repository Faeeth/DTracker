/// Verrous sur la recherche de mise a jour.
///
/// Deux choses valent d'etre tenues : la comparaison des numeros, ou une
/// erreur se voit mal — proposer une mise a jour vers une version plus
/// ancienne, ou n'en proposer aucune — et le silence, qui est le
/// comportement attendu partout ailleurs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dofus_tracker/source/maj.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un serveur qui repond ce qu'on lui dit, sur la boucle locale.
Future<HttpServer> serveurQuiRepond(int code, String corps) async {
  final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  serveur.listen((requete) async {
    requete.response.statusCode = code;
    requete.response.write(corps);
    await requete.response.close();
  });
  return serveur;
}

void main() {
  group('comparaison des numeros', () {
    test('nombre a nombre, pas lettre a lettre', () {
      // Le piege classique : « 1.0.10 » vient apres « 1.0.9 », ce qu'une
      // comparaison de chaines dit exactement a l'envers.
      expect(plusRecente('1.0.10', '1.0.9'), isTrue);
      expect(plusRecente('1.0.9', '1.0.10'), isFalse);
      expect(plusRecente('2.0.0', '1.9.9'), isTrue);
      expect(plusRecente('1.1.0', '1.0.99'), isTrue);
    });

    test('une version identique n\'est pas plus recente', () {
      expect(plusRecente('1.0.0', '1.0.0'), isFalse);
      expect(plusRecente('1.0', '1.0.0'), isFalse);
    });

    test('un suffixe ne compte pas', () {
      // « beta » ne se compare a rien : le suffixe nomme, il ne classe pas.
      expect(plusRecente('1.1.0-beta', '1.0.0'), isTrue);
      expect(plusRecente('1.0.0-rc1', '1.0.0'), isFalse);
    });

    test('un numero incomplet ou abime vaut zero', () {
      expect(plusRecente('1', '0.9.9'), isTrue);
      expect(plusRecente('bidon', '1.0.0'), isFalse);
    });
  });

  group('interrogation', () {
    test('une version de developpement ne demande rien', () async {
      // Elle n'est en retard sur rien, et se le faire dire a chaque
      // lancement serait penible.
      expect(await cherche(courante: 'dev'), isNull);
      expect(await cherche(courante: ''), isNull);
    });

    test('un depot injoignable ne dit rien', () async {
      // Le cas courant tant que le depot est prive : GitHub repond 404 sans
      // jeton. On se tait, exactement comme sans reseau.
      final serveur = await serveurQuiRepond(404, 'Not Found');
      addTearDown(() => serveur.close(force: true));
      expect(
          await cherche(
              courante: '1.0.0',
              adresse: 'http://127.0.0.1:${serveur.port}/'),
          isNull);
    });
    test('une reponse illisible ne dit rien', () async {
      final serveur = await serveurQuiRepond(200, 'pas du JSON');
      addTearDown(() => serveur.close(force: true));
      expect(
          await cherche(
              courante: '1.0.0',
              adresse: 'http://127.0.0.1:${serveur.port}/'),
          isNull);
    });

    test('une version plus recente est proposee', () async {
      final serveur = await serveurQuiRepond(
          200,
          jsonEncode({
            'tag_name': 'v9.1.0',
            'html_url': 'https://exemple/releases/v9.1.0',
          }));
      addTearDown(() => serveur.close(force: true));
      final neuve = await cherche(
          courante: '1.0.0', adresse: 'http://127.0.0.1:${serveur.port}/');
      expect(neuve, isNotNull);
      // Le « v » du tag ne s'affiche pas : on ecrit « 9.1.0 ».
      expect(neuve!.version, '9.1.0');
      expect(neuve.adresse, 'https://exemple/releases/v9.1.0');
    });

    test('une version plus ancienne, ou la meme, ne dit rien', () async {
      final serveur = await serveurQuiRepond(
          200, jsonEncode({'tag_name': 'v1.0.0', 'html_url': 'x'}));
      addTearDown(() => serveur.close(force: true));
      final adresse = 'http://127.0.0.1:${serveur.port}/';
      expect(await cherche(courante: '1.0.0', adresse: adresse), isNull);
      expect(await cherche(courante: '2.0.0', adresse: adresse), isNull);
    });

    test('un brouillon et une avant-premiere sont ignores', () async {
      // Le workflow ouvre justement les releases en brouillon : les proposer
      // enverrait tout le monde vers une version pas encore relue.
      for (final marque in ['draft', 'prerelease']) {
        final serveur = await serveurQuiRepond(
            200,
            jsonEncode({'tag_name': 'v9.9.9', marque: true, 'html_url': 'x'}));
        expect(
            await cherche(
                courante: '1.0.0',
                adresse: 'http://127.0.0.1:${serveur.port}/'),
            isNull,
            reason: marque);
        await serveur.close(force: true);
      }
    });
  });
}
