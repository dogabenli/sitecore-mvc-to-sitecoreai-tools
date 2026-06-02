param(
    [string]$ConfigurationItemPath = "/sitecore/system/Settings/Migration/Migration Configuration",
    [string]$Database = "master"
)

$pageTemplateId = "{AB86861A-6030-46C5-B394-E8F99E8B87DB}"

function Resolve-ItemFromConfigValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()
    $trimmed = $trimmed -replace '^(?i)master:\s*', ''

    [Sitecore.Data.ID]$id = [Sitecore.Data.ID]::Null
    if ([Sitecore.Data.ID]::TryParse($trimmed, [ref]$id)) {
        return Get-Item -Path "${Database}:" -ID $id
    }

    if ($trimmed.StartsWith("/")) {
        return Get-Item -Path $trimmed
    }

    $trimmedNoSlash = $trimmed.TrimStart('/')
    $trimmedNoTemplatesPrefix = $trimmedNoSlash -replace '^(?i)templates/', ''

    $candidates = @(
        $trimmed,
        "/sitecore/$trimmedNoSlash",
        "/sitecore/templates/$trimmedNoTemplatesPrefix"
    )

    $seen = @{}
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate) -or $seen.ContainsKey($candidate)) {
            continue
        }

        $seen[$candidate] = $true
        $item = Get-Item -Path $candidate
        if ($item) {
            return $item
        }
    }

    return $null
}

function Resolve-ItemsFromConfigMultivalue {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) {
        return @()
    }

    $resolved = @()
    foreach ($token in ($Raw -split '\|')) {
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }

        $item = Resolve-ItemFromConfigValue -Value $token
        if ($item) {
            $resolved += $item
        }
    }

    $byId = @{}
    foreach ($item in $resolved) {
        $byId[$item.ID.ToString()] = $item
    }

    return @($byId.Values)
}

function Remove-AncestorSelections {
    param([Item[]]$Items)

    if (-not $Items) {
        return @()
    }

    $filtered = @()
    foreach ($item in $Items) {
        $isAncestor = $false
        foreach ($other in $Items) {
            if ($item.ID -eq $other.ID) {
                continue
            }

            if ($other.Paths.FullPath.StartsWith($item.Paths.FullPath + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
                $isAncestor = $true
                break
            }
        }

        if (-not $isAncestor) {
            $filtered += $item
        }
    }

    return $filtered
}

function Get-MvcPageTypeTemplatesFromConfiguredItems {
    param([Item[]]$ConfiguredItems)

    $templates = [System.Collections.Generic.List[Item]]::new()
    $seen = @{}

    foreach ($configured in $ConfiguredItems) {
        if (-not $configured) {
            continue
        }

        if ($configured.TemplateID -eq $pageTemplateId) {
            $key = $configured.ID.ToString().ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $templates.Add($configured)
            }
            continue
        }

        $descendantTemplates = Get-ChildItem -Path "${Database}:" -ID $configured.ID -Recurse | Where-Object { $_.TemplateID -eq $pageTemplateId }
        foreach ($template in $descendantTemplates) {
            $key = $template.ID.ToString().ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $templates.Add($template)
            }
        }
    }

    return @($templates)
}

$configurationItem = Get-Item -Path $ConfigurationItemPath
if (-not $configurationItem) {
    throw "Migration Configuration item not found at $ConfigurationItemPath"
}

$mvcStartItem = Resolve-ItemFromConfigValue -Value $configurationItem["MVC Start Item"]
if (-not $mvcStartItem) {
    throw "Field 'MVC Start Item' is empty or could not be resolved on $ConfigurationItemPath"
}

$configuredTemplateItems = Resolve-ItemsFromConfigMultivalue -Raw $configurationItem["MVC Page Type Templates"]
$configuredTemplateItems = Remove-AncestorSelections -Items $configuredTemplateItems
if (-not $configuredTemplateItems -or $configuredTemplateItems.Count -eq 0) {
    throw "Field 'MVC Page Type Templates' is empty or could not be resolved on $ConfigurationItemPath"
}

$mvcPageTemplates = Get-MvcPageTypeTemplatesFromConfiguredItems -ConfiguredItems $configuredTemplateItems
if (-not $mvcPageTemplates -or $mvcPageTemplates.Count -eq 0) {
    throw "No MVC page templates were found from the configured 'MVC Page Type Templates' selection."
}

$descendantItems = @(Get-ChildItem -Path "${Database}:" -ID $mvcStartItem.ID -Recurse)
$candidatePages = @($mvcStartItem) + $descendantItems
$descendantItemCount = $descendantItems.Count
$totalItemCount = $candidatePages.Count
$templateIds = @{}
foreach ($template in $mvcPageTemplates) {
    $templateIds[$template.ID.ToString().ToLowerInvariant()] = $template
}

$pageMatches = foreach ($item in $candidatePages) {
    $itemTemplateKey = $item.TemplateID.ToString().ToLowerInvariant()
    if ($templateIds.ContainsKey($itemTemplateKey)) {
        [PSCustomObject]@{
            Item         = $item
            Template     = $templateIds[$itemTemplateKey]
            TemplateName = $templateIds[$itemTemplateKey].Name
            TemplatePath = $templateIds[$itemTemplateKey].Paths.FullPath
        }
    }
}

$pagesByTemplate = $pageMatches |
    Group-Object TemplatePath |
    Sort-Object Name |
    ForEach-Object {
        $first = $_.Group | Select-Object -First 1
        [PSCustomObject]@{
            TemplateName = $first.TemplateName
            TemplatePath = $first.TemplatePath
            Count        = $_.Count
        }
    }

$startItemCounted = $templateIds.ContainsKey($mvcStartItem.TemplateID.ToString().ToLowerInvariant())

$result = [PSCustomObject]@{
    ConfigurationItemPath = $configurationItem.Paths.FullPath
    StartItemPath         = $mvcStartItem.Paths.FullPath
    StartItemCounted      = $startItemCounted
    DescendantItemCount   = $descendantItemCount
    TotalItemCount        = $totalItemCount
    TotalPageCount        = @($pageMatches).Count
    TemplateCount         = @($mvcPageTemplates).Count
    PagesByTemplate       = @($pagesByTemplate)
}

$result

Write-Host ""
Write-Host "Site page count" -ForegroundColor Cyan
Write-Host ("Start item        : {0}" -f $result.StartItemPath)
Write-Host ("Descendant items  : {0}" -f $result.DescendantItemCount)
Write-Host ("Total items       : {0}" -f $result.TotalItemCount) -ForegroundColor Green
Write-Host ("Start item counted: {0}" -f $result.StartItemCounted)
Write-Host ("Page templates    : {0}" -f $result.TemplateCount)
Write-Host ("Total page count  : {0}" -f $result.TotalPageCount)

if ($pagesByTemplate.Count -gt 0) {
    Write-Host ""
    Write-Host "Breakdown by template" -ForegroundColor Cyan
    $pagesByTemplate | Format-Table Count, TemplateName, TemplatePath -AutoSize
}