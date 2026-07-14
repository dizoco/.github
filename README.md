# dizoco/.github — Estándares de la organización

Repositorio central con los workflows reusables de CI, las reglas de protección de ramas
(rulesets) y la documentación del flujo de trabajo de Dizoco.

## Flujo de ramas

```
feature/x ──PR──▶ develop ──PR──▶ main ──▶ deploy
bugfix/y  ──PR──▶ develop
hotfix/z  ────────PR────────▶ main   (urgencias de producción; luego sincronizar develop)
```

- **Nombres de rama permitidos**: `main`, `develop`, `feature/*`, `bugfix/*`, `hotfix/*`, `release/*`
  (más `dependabot/*` y `claude/*` para automatizaciones). Cualquier otro nombre es rechazado al hacer push.
- **main y develop** no aceptan pushes directos: todo entra por PR.
- **PRs a develop** (desde `feature/*`, `bugfix/*`, `hotfix/*`) requieren en verde:
  `branch-flow / check`, `ci / build-test`, `ci / dependencies`.
- **PRs a main** solo desde `develop` o `hotfix/*`; requieren `branch-flow / check`
  (las validaciones completas ya corrieron al entrar a develop).
- **Claude** revisa cada PR a develop y comenta; es informativo, no bloquea el merge.
- Después de mergear un `hotfix/*` a main, abre también un PR `hotfix/* → develop`
  (o mergea main en develop) para no perder el arreglo.

## Workflows reusables (`.github/workflows/`)

| Workflow | Uso | Jobs (checks) |
|---|---|---|
| `branch-flow.yml` | Valida rama origen del PR | `check` |
| `ci-dotnet.yml` | Build+test+deps .NET (inputs: `dotnet-version`, `working-directory`) | `build-test`, `dependencies` |
| `ci-node.yml` | Lint+build+test+audit Node (inputs: `node-version`, `working-directory`) | `build-test`, `dependencies` |
| `claude-review.yml` | Code review de Claude en PRs (secreto `CLAUDE_CODE_OAUTH_TOKEN`) | `review` |
| `cd-appservice-dotnet.yml` | Deploy .NET a Azure App Service vía zip deploy (inputs: `dotnet-version`, `working-directory`, `project-path`, `app-name`; secreto `publish-profile`) | `build-and-deploy` |
| `cd-appservice-node.yml` | Deploy Node/SPA a Azure App Service vía zip deploy (inputs: `node-version`, `working-directory`, `build-command`, `artifact-path`, `app-name`; secreto `publish-profile`) | `build-and-deploy` |

El análisis estático de .NET corre dentro del build (analizadores Roslyn habilitados vía
`Directory.Build.props` en cada repo, con warnings como errores). En Node lo hace ESLint.

## Despliegue (CD)

Dos patrones válidos, según si el servicio necesita dependencias de sistema:

- **Zip deploy nativo** (`cd-appservice-dotnet.yml` / `cd-appservice-node.yml`): build en el runner
  (`dotnet publish` / `npm run build`) y despliegue directo vía `azure/webapps-deploy`, autenticado
  con el publish profile del App Service (secreto `AZURE_WEBAPP_PUBLISH_PROFILE` por repo, sin
  Service Principal). Es el patrón por defecto para servicios .NET o Node/SPA simples — usado por
  `dizoco-pos-api` y `dizoco-pos-web`.
- **Docker + ACR** (ver `PdfGeneratorService/.github/workflows/ci-cd.yml` como referencia): build de
  imagen, push a `dyzocolabsacr.azurecr.io` y despliegue del contenedor vía `azure/webapps-deploy`
  con `azure/login` (secretos `ACR_USERNAME`, `ACR_PASSWORD`, `AZURE_CREDENTIALS`). Reservado para
  servicios que necesitan dependencias de sistema que Oryx/zip deploy no provee (ej. Playwright/Chromium).

En ambos casos el trigger es `push` a `main` y el destino es un App Service Linux en el plan Free
compartido `rg-dyzoco-common` / `asp-dyzoco-linux` (mientras dure la etapa de prueba, para evitar cobros).

Ejemplo de workflow delgado llamando al reusable (.NET):

```yaml
name: CD → Azure App Service
on:
  push:
    branches: [main]
jobs:
  deploy:
    uses: dizoco/.github/.github/workflows/cd-appservice-dotnet.yml@main
    with:
      project-path: src/MiServicio.Api/MiServicio.Api.csproj
      app-name: dizoco-miservicio
    secrets:
      publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
```

## Onboarding de un repositorio nuevo

1. Crear las ramas `main` y `develop`.
2. Copiar los 3 workflows delgados de cualquier repo existente (`ci.yml`, `branch-flow.yml`,
   `claude-review.yml`) ajustando el reusable (.NET o Node) y sus inputs.
3. Repos .NET: copiar `Directory.Build.props` (analizadores) y `dependabot.yml`.
4. Si el repo se despliega a Azure App Service, agregar `cd.yml` llamando al reusable correspondiente
   (`cd-appservice-dotnet.yml` o `cd-appservice-node.yml`), crear el App Service y configurar el
   secreto `AZURE_WEBAPP_PUBLISH_PROFILE` en el repo (ver sección *Despliegue (CD)* arriba).
5. Aplicar las reglas de protección:
   ```powershell
   ./scripts/apply-rulesets.ps1 -Repos <nombre-del-repo>
   ```
5. Activar en Settings: *Automatically delete head branches* y Dependabot alerts/security updates.

> Los rulesets se aplican por repositorio porque los rulesets a nivel de organización
> requieren plan Enterprise. Los JSON de `rulesets/` son la fuente de verdad: cualquier
> cambio de reglas se edita ahí y se re-aplica con el script.

## Cuando crezca el equipo

- Subir `required_approving_review_count` de `0` a `1` en `rulesets/protect-main.json` y
  `rulesets/protect-develop.json`, y re-aplicar con el script.
- Activar el umbral de cobertura descomentando el bloque *Coverage* en `ci-dotnet.yml` / `ci-node.yml`.
- Considerar ramas `release/*` (ya permitidas por nomenclatura) si se necesita estabilizar
  versiones mientras develop sigue avanzando.
