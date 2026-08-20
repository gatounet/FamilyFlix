# FamilyFlix

FamilyFlix est une vidéothèque familiale privée conçue pour fonctionner sans abonnement.

## Plateformes

- Android
- Web

Le même code Flutter alimente les deux versions.

## Lancer l’application

Le projet est déjà relié à l’instance Supabase **FamilyFlix** avec sa clé
publiable. Cette clé identifie l’application, mais n’accorde aucun accès secret :
les données restent protégées par l’authentification et les politiques RLS.

Lancer l’application :

```sh
flutter run -d chrome
```

La configuration peut être remplacée localement si nécessaire :

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=votre-cle-publiable
```

Ne placez jamais une clé `service_role` ou une clé secrète dans l’application.

## Fonctionnalités disponibles

- création d’un compte par e-mail et mot de passe ;
- confirmation de l’adresse par e-mail selon la configuration Supabase ;
- connexion et persistance sécurisée de la session ;
- déconnexion ;
- écran d’accueil responsive Android/Web.

## Vérifications

```sh
flutter analyze
flutter test
flutter build web
```
