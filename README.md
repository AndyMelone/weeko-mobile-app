# weeko

App Flutter du répétiteur (planning, pointage, rattrapages, élèves).
Les données viennent de l'API [`../weeko-api`](../weeko-api).

## Lancer

1. Démarrer l'API (voir `../weeko-api/README.md`) :
   `npm run db:up && npm run prisma:migrate && npm run db:seed && npm run start:dev`
2. Configurer l'app :
   ```bash
   cp .env.example.json .env.json
   ```
   - `API_KEY` : même valeur que `API_KEY` dans `../weeko-api/.env`.
   - `API_URL` : `http://localhost:3000/api` (iOS, macOS, web) ;
     `http://10.0.2.2:3000/api` (émulateur Android) ;
     `http://<IP du Mac>:3000/api` (téléphone réel, même Wi-Fi).
3. Lancer :
   ```bash
   flutter run --dart-define-from-file=.env.json
   ```
   Les configurations VS Code (`.vscode/launch.json`) et Android Studio passent déjà ce fichier.

`.env.json` n'est pas versionné. La clé est embarquée dans l'app : elle protège l'API
des appels anonymes, mais n'est pas un secret face à quelqu'un qui décompile l'app.

## Tests

`flutter test` : la fausse API (`test/support/fake_api.dart`) sert `test/fixtures/state.json`,
réponse de `GET /state` capturée après le seed. À régénérer si le format de `/state` change.
