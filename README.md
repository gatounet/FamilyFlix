# FamilyFlix

FamilyFlix est une application de vidéothèque privée pensée pour une famille. Elle permet de savoir quels films et séries sont disponibles à la maison, sur quel support ils se trouvent et à qui ils appartiennent, tout en donnant aux membres un espace commun pour proposer et noter des contenus.

Le projet poursuit une contrainte simple : rester utilisable sans abonnement ni infrastructure payante obligatoire.

## Le concept

Une famille crée son espace FamilyFlix, puis invite ses membres par e-mail ou avec un numéro de famille protégé par mot de passe. Chacun peut consulter la collection commune, enregistrer ses propres exemplaires et participer au choix du prochain film.

Les informations cinématographiques sont récupérées depuis TMDB. Les informations privées — propriétaires, supports, souhaits et avis — restent enregistrées dans la base Supabase de la famille.

## Fonctionnalités

### Comptes et familles

- création de compte et connexion sécurisée avec Supabase Auth ;
- création ou participation à une famille ;
- invitation par e-mail ;
- accès par numéro de famille et mot de passe ;
- rôles de créateur, administrateur et membre ;
- promotion, rétrogradation et exclusion des membres par le créateur ;
- avatar familial évoluant avec la taille de la collection.

### Vidéothèque

- recherche combinée de films et de séries sur TMDB ;
- ajout d’un exemplaire physique ou numérique ;
- possession d’une série complète, d’une saison particulière ou d’une sélection de saisons ;
- gestion des supports communs : DVD, Blu-ray, Blu-ray 4K, NAS, box, disque dur, étagère, etc. ;
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
