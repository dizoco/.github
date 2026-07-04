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

El análisis estático de .NET corre dentro del build (analizadores Roslyn habilitados vía
`Directory.Build.props` en cada repo, con warnings como errores). En Node lo hace ESLint.

## Onboarding de un repositorio nuevo

1. Crear las ramas `main` y `develop`.
2. Copiar los 3 workflows delgados de cualquier repo existente (`ci.yml`, `branch-flow.yml`,
   `claude-review.yml`) ajustando el reusable (.NET o Node) y sus inputs.
3. Repos .NET: copiar `Directory.Build.props` (analizadores) y `dependabot.yml`.
4. Aplicar las reglas de protección:
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
