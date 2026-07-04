<#
.SYNOPSIS
    Aplica los rulesets de dizoco (rulesets/*.json) a uno o más repositorios.
    Idempotente: si el ruleset ya existe (mismo nombre) lo actualiza; si no, lo crea.

.EXAMPLE
    ./apply-rulesets.ps1 -Repos dizoco-pos-api
    ./apply-rulesets.ps1 -Repos dizoco-pos-api,dizoco-pos-web,NotificationService,PdfGeneratorService
#>
param(
    [string]$Owner = 'dizoco',
    [Parameter(Mandatory)][string[]]$Repos
)

$ErrorActionPreference = 'Stop'
$rulesetDir = Join-Path $PSScriptRoot '..\rulesets'

foreach ($repo in $Repos) {
    $existing = gh api "repos/$Owner/$repo/rulesets" | ConvertFrom-Json

    foreach ($file in Get-ChildItem $rulesetDir -Filter *.json) {
        $name = (Get-Content $file.FullName -Raw | ConvertFrom-Json).name
        $match = $existing | Where-Object { $_.name -eq $name }

        if ($match) {
            gh api "repos/$Owner/$repo/rulesets/$($match.id)" -X PUT --input $file.FullName | Out-Null
            Write-Host "[$repo] actualizado: $name"
        }
        else {
            gh api "repos/$Owner/$repo/rulesets" -X POST --input $file.FullName | Out-Null
            Write-Host "[$repo] creado: $name"
        }
    }
}
