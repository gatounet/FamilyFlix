# FamilyFlix

> **Toute la vidéothèque de la famille, au même endroit.**
>
> Savoir ce que l’on possède, choisir quoi regarder et le faire ensemble.

[![Flutter](https://img.shields.io/badge/Flutter-Web%20%26%20Android-02569B?logo=flutter)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Données%20privées-3FCF8E?logo=supabase)](https://supabase.com/)
[![TMDB](https://img.shields.io/badge/TMDB-Films%20%26%20séries-01B4E4)](https://www.themoviedb.org/)
[![Coût](https://img.shields.io/badge/Objectif-0%20€-E84E2C)](#une-contrainte-fondatrice--0-€)

FamilyFlix est une vidéothèque privée conçue pour une famille. Elle rassemble les films et séries disponibles à la maison, indique où ils se trouvent et à qui ils appartiennent, puis aide tout le monde à choisir le prochain programme.

## Le concept

| 01 — Rassembler | 02 — Partager | 03 — Choisir |
|---|---|---|
| Réunir DVD, Blu-ray, NAS, box et supports numériques dans une collection commune. | Permettre à chaque membre d’ajouter ses exemplaires, ses souhaits, ses avis et ses recommandations. | Utiliser les informations TMDB et les filtres FamilyFlix pour trouver rapidement le bon film ou la bonne série. |

```text
Un membre ajoute un film ou une série
                    ↓
       TMDB complète automatiquement la fiche
                    ↓
 FamilyFlix enregistre le propriétaire et le support
                    ↓
 Toute la famille peut chercher, proposer et choisir
```

Une famille crée son espace privé, puis invite ses membres par e-mail ou avec un numéro de famille protégé par mot de passe. Chacun consulte la collection commune tout en conservant l’identité de ses propres exemplaires.

Les informations cinématographiques sont récupérées depuis TMDB. Les informations privées — propriétaires, supports, souhaits et avis — restent enregistrées dans la base Supabase de la famille.

## Documentation

Le [guide d’utilisation de FamilyFlix](docs/GUIDE_UTILISATEUR.md) explique pas à pas la création d’un compte, l’accès à une famille, l’ajout de contenus, la gestion des supports, les transferts groupés sans duplication, les souhaits, les avis et les exports.

## Une contrainte fondatrice : 0 €

FamilyFlix est né comme un projet familial sans budget. Il privilégie donc les technologies gratuites et ouvertes, sans abonnement pour les membres et sans publicité dans l’application.

| Engagement | Ce que cela signifie |
|---|---|
| **Sans abonnement** | Aucun paiement demandé aux membres de la famille. |
| **Sans publicité** | L’interface reste centrée sur la collection et les échanges familiaux. |
| **Données privées** | Les données personnelles et familiales sont protégées par les règles d’accès Supabase. |
| **Projet ouvert** | Le code et l’évolution du concept sont visibles dans ce dépôt GitHub. |

## Fonctionnalités

### Comptes et familles

- création de compte et connexion sécurisée avec Supabase Auth ;
- création ou participation à une famille ;
- invitation par e-mail ;
- accès par numéro de famille et mot de passe ;
- rôles de créateur, administrateur et membre ;
- gestion des rôles et des membres par les responsables autorisés de la famille ;
- avatar familial évoluant avec la taille de la collection.

### Vidéothèque

- recherche combinée de films et de séries sur TMDB ;
- ajout d’un exemplaire physique ou numérique ;
- ajout successif de plusieurs contenus sans quitter la page de recherche ;
- choix mémorisé d’un support proposé par défaut lors des nouveaux ajouts ;
- possession d’une série complète, d’une saison particulière ou d’une sélection de saisons ;
- regroupement des exemplaires d’une même œuvre sous une seule fiche, avec le détail des propriétaires et supports ;
- gestion des supports communs : DVD, Blu-ray, Blu-ray 4K, NAS, box, disque dur, étagère, etc. ;
- transfert groupé d’exemplaires d’un support vers un autre, sans duplication ;
- indication du propriétaire et de l’emplacement ;
- suppression d’un exemplaire sans supprimer les autres données du film ;
- filtres par support, genre et âge conseillé ;
- filtre par année dans la recherche TMDB et la collection ;
- classement par ajout récent, titre, année ou classification d’âge ;
- catalogue complet sous forme de tableau avec export CSV et PDF imprimable ;
- thème clair, sombre ou synchronisé avec le système de l’utilisateur.

### Découverte et participation

- liste de souhaits pour proposer un film qui n’est pas encore possédé ;
- notes, commentaires et coups de cœur ;
- fiche détaillée avec synopsis, affiche, durée, genres et classification ;
- distribution et fiches des acteurs ;
- bandes-annonces, teasers et vidéos disponibles sur YouTube ou Vimeo.

## Confidentialité et coût

FamilyFlix ne nécessite pas de serveur applicatif dédié. Le projet peut fonctionner dans les limites des offres gratuites de Supabase et TMDB, sous réserve de leurs conditions et quotas respectifs. Les politiques RLS empêchent un utilisateur authentifié de consulter une autre famille.

Le jeton TMDB est uniquement utilisé par les Edge Functions et n’est jamais envoyé à l’application Flutter.

## Attribution TMDB

Ce produit utilise l’API TMDB mais n’est ni approuvé ni certifié par TMDB.

Les affiches, biographies, synopsis et autres métadonnées restent la propriété de leurs ayants droit respectifs.

## État du projet

FamilyFlix est un projet familial en développement actif. Les prochaines étapes pourront notamment concerner les notifications, l’amélioration du mode hors ligne, les sauvegardes et la publication simplifiée des applications Android et Web.

## Licence

Consultez le fichier [LICENSE](LICENSE) du dépôt.
