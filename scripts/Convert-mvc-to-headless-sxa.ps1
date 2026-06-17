$configurationItemPath = "/sitecore/system/Settings/Migration/Migration Configuration"

# Template IDs
$jsonRenderingTemplateId   = "{04646A89-996F-4EE7-878A-FFDBF1F0EF0D}"
$renderingFolderTemplateId = "{7EE0975B-0698-493E-B3A2-0B2EF33D0522}"

# Source rendering templates
$allowedSourceTemplateIds = @(
    "2a3e91a0-7987-44b5-ab34-35c2d9de83b9",
    "99f8905d-4a87-4eb8-9f8b-a9bebfb3add6"
)

# Maps
$renderingIdMap     = @{}
$datasourceIdMap    = @{}
$placeholderIdMap   = @{}
$pageTemplateIdMap  = @{}
$templateIdMap      = @{}
$mvcDatasourceConfigurationRoot = $null
$headlessPlaceholderPrefix = "headless"

$baseRenderingParametersTemplateId = "{4247AAD4-EBDE-4994-998F-E067A51B1FE4}"
$requiredPageTemplateBaseIds = @(
    "{47151711-26CA-434E-8132-D3E0B7D26683}",
    "{371D5FBB-5498-4D94-AB2B-E3B70EEBE78C}",
    "{4414A1F9-826A-4647-8DF4-ED6A95E64C43}",
    "{6650FB34-7EA1-4245-A919-5CC0F002A6D7}",
    "{F39A594A-7BC9-4DB0-BAA1-88543409C1F9}"
)

# Mapping item creation (Phase 7)
$renderingMappingRootPath = "/sitecore/system/Settings/Migration/Mappings/Rendering Mappings"
$renderingMappingTemplateId = "{627EE9FF-F63B-441C-93D6-0A69FB623BBB}"
$renderingSourceFieldId = "{AF375DB4-D362-4886-B551-111AE9DDFD2D}"
$renderingTargetFieldId = "{6E311F1C-87E1-41FE-A69A-C4A064B3F92F}"

$placeholderMappingRootPath = "/sitecore/system/Settings/Migration/Mappings/Placeholder Mappings"
$placeholderMappingTemplateId = "{13BFDC26-3A55-4E54-BBD4-C4813DA119D2}"
$placeholderSourceFieldId = "{CCB522D4-0862-4348-81BB-12CBBD293036}"
$placeholderTargetFieldId = "{B60C925B-9CF8-4A3A-8D86-82B90546D10B}"
$placeholderSourceFieldName = "Source"
$placeholderTargetFieldName = "Target"
$placeholderKeyMappingTemplateId = "{55281BC0-F06B-49E0-87D0-6B6594A261CA}"
$placeholderKeyMappingSourceFieldId = "{D53FA402-33E7-4219-9A24-2078FE173F62}"
$placeholderKeyMappingTargetFieldId = "{DC84EA35-942E-4BFC-8DF4-F79E90AAF7D0}"
$placeholderKeyMappingKeyFieldId = "{F0251DE5-611B-4D82-9E74-E75D9C63A138}"
$placeholderKeyMappingKeyFieldName = "Key"

$pageTemplateMappingRootPath = "/sitecore/system/Settings/Migration/Mappings/Page Template Mappings"
$pageTemplateMappingTemplateId = "{5C9897BB-FDAC-418F-8044-4BB1FCCC41FB}"
$pageTemplateSourceFieldId = "{C48EFCEE-F8DF-47EA-A5A3-4670B1E3356A}"
$pageTemplateTargetFieldId = "{2BF34BA0-B6FB-4DBF-A856-9F2C821896DA}"

# Phase 8: Dynamic placeholders
$renderingsFieldId = "{F1A1FE9E-A60C-4DDB-A3A0-BB5B29FE732E}"
$finalRenderingsFieldId = "{04BF00DB-F5FB-41F7-8AB7-22408372A981}"

# Phase 9: Standard Values Update — layout mapping constants
$layoutMappingRootPath    = "/sitecore/system/Settings/Migration/Mappings/Layout Mappings"
$layoutMappingTemplateId  = "{E75AB56F-5171-4064-98DC-2D856BF2668D}"
$layoutSourceFieldId      = "{8560BA59-6006-4C1C-8280-D4FEDBBD1C08}"
$layoutTargetFieldId      = "{226DC703-6995-4FDF-B69B-78AE689C19DA}"
$dynamicPlaceholderTemplateFallbackPaths = @(
    "/sitecore/templates/Foundation/Experience Accelerator/Dynamic Placeholders/Rendering Parameters/IDynamicPlaceholder"
)
$dynamicPlaceholderOtherPropertyFlag = "IsRenderingsWithDynamicPlaceholders"
$defaultDynamicPlaceholderSampleSize = 50

$phaseResults = [ordered]@{}

# ---------- per-phase created-item tracking ----------
$script:phase1Created = [System.Collections.Generic.List[hashtable]]::new()   # datasource
$script:phase2Created = [System.Collections.Generic.List[hashtable]]::new()   # renderings + templates
$script:phase3Created = [System.Collections.Generic.List[hashtable]]::new()   # placeholders
$script:phase4Created = [System.Collections.Generic.List[hashtable]]::new()   # page templates
$script:phase5Created = [System.Collections.Generic.List[hashtable]]::new()   # __Standard Values updated
$script:phase7Created = [System.Collections.Generic.List[hashtable]]::new()   # mapping items
$script:phase8Created = [System.Collections.Generic.List[hashtable]]::new()   # dynamic-placeholder updates
$script:phase9Created = [System.Collections.Generic.List[hashtable]]::new()   # standard values XML updates
$script:phase10Created = [System.Collections.Generic.List[hashtable]]::new()  # rendering manifest export (read-only, empty)
$script:phase8ManifestResult = $null  # set by Phase 8, consumed by Phase 10
$script:phaseTrackingLists = @($null, $script:phase1Created, $script:phase2Created,
    $script:phase3Created, $script:phase4Created, $script:phase5Created, $null, $script:phase7Created, $script:phase8Created, $script:phase9Created, $script:phase10Created)

# ---------- interactive helpers ----------

function Build-ProgressBar {
    param([int]$current, [int]$total)
    $filled  = [int][Math]::Round(($current / $total) * 20)
    $empty   = 20 - $filled
    $bar     = ([string][char]0x2588) * $filled + ([string][char]0x2591) * $empty
    return "[$bar] Phase $current of $total"
}

function Get-NextPhaseName {
    param([int]$current)
    $names = @{
        1 = "Phase 2: Renderings Migration"
        2 = "Phase 3: Placeholders Migration"
        3 = "Phase 4: Page Templates Migration"
        4 = "Phase 5: Insert Options Update"
        5 = "Phase 6: Save JSON Maps"
        6 = "Phase 7: Create Mapping Items"
        7 = "Phase 8: Dynamic Placeholders"
        8 = "Phase 9: Standard Values Update"
        9 = "Phase 10: Rendering Manifest Export"
    }
    if ($names.ContainsKey($current)) { return $names[$current] }
    return $null
}

function Invoke-PhaseRevert {
    param(
        [System.Collections.Generic.List[hashtable]]$createdItems,
        [string]$phaseName,
        [System.Collections.Generic.List[string]]$revertLogLines = $null
    )
    if (-not $createdItems -or $createdItems.Count -eq 0) {
        Write-Host "Nothing to revert for $phaseName."
        if ($revertLogLines) {
            $revertLogLines.Add(("[INFO] {0}: Nothing to revert." -f $phaseName))
        }
        return 0
    }
    $deleted = 0
    $candidates = @()
    foreach ($entry in $createdItems) {
        $targetId = $entry["TargetId"]
        if ([string]::IsNullOrWhiteSpace($targetId)) { continue }
        try {
            $item = Get-Item -Path "master:" -ID ([Sitecore.Data.ID]$targetId) -ErrorAction SilentlyContinue
            if ($item) {
                $depth = ($item.Paths.FullPath -split '/').Count
                $candidates += [PSCustomObject]@{
                    Item  = $item
                    Path  = $item.Paths.FullPath
                    Depth = $depth
                }
            }
        } catch {
            Write-Warning "Could not resolve item ID $targetId for revert: $_"
        }
    }

    $seenPaths = @{}
    $ordered = $candidates |
        Sort-Object -Property Depth -Descending |
        Where-Object {
            if ($seenPaths.ContainsKey($_.Path)) { return $false }
            $seenPaths[$_.Path] = $true
            return $true
        }

    foreach ($candidate in $ordered) {
        try {
            if (Test-Path -Path $candidate.Path) {
                Remove-Item -Path $candidate.Path -Recurse -Force -ErrorAction SilentlyContinue
                $deleted++
                Write-Host "Reverted: $($candidate.Path)"
                if ($revertLogLines) {
                    $revertLogLines.Add(("[DELETED] {0}" -f $candidate.Path))
                }
            }
        } catch {
            Write-Warning "Could not revert item at $($candidate.Path): $_"
            if ($revertLogLines) {
                $revertLogLines.Add(("[WARN] Could not revert item at {0}: {1}" -f $candidate.Path, $_.Exception.Message))
            }
        }
    }
    $createdItems.Clear()
    Write-Host "Reverted $deleted item(s) from $phaseName."
    if ($revertLogLines) {
        $revertLogLines.Add(("[INFO] {0}: Removed {1} item(s)." -f $phaseName, $deleted))
        $revertLogLines.Add("")
    }
    return $deleted
}

function Invoke-AllPhasesRevert {
    $allLists = @(
        @{ Name = "Phase 1: Datasource Migration";   List = $script:phase1Created },
        @{ Name = "Phase 2: Renderings Migration";    List = $script:phase2Created },
        @{ Name = "Phase 3: Placeholders Migration"; List = $script:phase3Created },
        @{ Name = "Phase 4: Page Templates Migration"; List = $script:phase4Created },
        @{ Name = "Phase 5: Insert Options Update";  List = $script:phase5Created },
        @{ Name = "Phase 7: Create Mapping Items";   List = $script:phase7Created }
    )
    $total = 0
    $logLines = [System.Collections.Generic.List[string]]::new()
    $logLines.Add("Everything is reverting back...")
    $logLines.Add("")
    $summaryItems = [System.Collections.Generic.List[string]]::new()

    $phaseIndex = 0
    $phaseCount = $allLists.Count
    foreach ($entry in $allLists) {
        $phaseIndex++
        $pct = [int](($phaseIndex / $phaseCount) * 100)
        Write-Progress -Activity "Reverting Migration Changes" -Status ("Everything is reverting back... ({0}/{1})" -f $phaseIndex, $phaseCount) -PercentComplete $pct

        $phaseDeleted = Invoke-PhaseRevert -createdItems $entry.List -phaseName $entry.Name -revertLogLines $logLines
        $total += $phaseDeleted
        $summaryItems.Add(("- {0}: {1} item(s) removed" -f $entry.Name, $phaseDeleted))
    }
    Write-Progress -Activity "Reverting Migration Changes" -Completed
    Write-Host "Full revert complete. $total item(s) removed across all phases."

    $summaryText = "Revert summary:`n`n" + ($summaryItems -join "`n`n") + "`n`nTotal removed: $total item(s)"
    $logLines.Add("Revert summary")
    $logLines.Add("--------------")
    foreach ($item in $summaryItems) {
        $logLines.Add("")
        $logLines.Add($item)
        $logLines.Add("")
    }
    $logLines.Add("")
    $logLines.Add(("Total removed: {0} item(s)" -f $total))

    $revertLogText = $logLines -join "`n"
    try {
        # SPE Show-Result expects text via pipeline when using -Text.
        $revertLogText | Show-Result -Text
    } catch {
        Write-Warning "Could not display revert log window: $($_.Exception.Message)"
        Write-Host $revertLogText
    }

    return $total
}

function Get-PhaseCreatedItemsSummary {
    param([System.Collections.Generic.List[hashtable]]$createdItems)

    if (-not $createdItems -or $createdItems.Count -eq 0) {
        return "No tracked items were created in this phase."
    }

    $paths = @($createdItems | ForEach-Object { $_["TargetPath"] } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (-not $paths -or $paths.Count -eq 0) {
        return "$($createdItems.Count) item(s) were tracked, but no target paths were available for summary."
    }

    $uniquePaths = @($paths | Sort-Object -Unique)
    $roots = @()
    foreach ($path in $uniquePaths) {
        $isChild = $false
        foreach ($other in $uniquePaths) {
            if ($other -ne $path -and $path.StartsWith("$other/", [System.StringComparison]::OrdinalIgnoreCase)) {
                $isChild = $true
                break
            }
        }
        if (-not $isChild) {
            $roots += $path
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("Created roots summary:")
    foreach ($root in ($roots | Sort-Object)) {
        $rootItem = $createdItems | Where-Object { $_["TargetPath"] -eq $root } | Select-Object -First 1
        $rootType = if ($rootItem -and $rootItem["Type"]) { $rootItem["Type"] } else { "Item" }
        $lines.Add("")
        $lines.Add(("- {0}: {1} and all descendent items." -f $rootType, $root))
        $lines.Add("")
    }

    return ($lines -join "`n")
}

function Show-PhaseResultDialog {
    param(
        [string]$phaseName,
        [int]$phaseNum,
        [int]$totalPhases,
        [bool]$success,
        [string]$summaryText,
        [System.Collections.Generic.List[hashtable]]$createdItems,
        [bool]$isFinal = $false
    )

    $progressBar   = Build-ProgressBar -current $phaseNum -total $totalPhases
    $nextPhaseName = Get-NextPhaseName -current $phaseNum
    $statusIcon    = if ($success) { "SUCCESS" } else { "SKIPPED / FAILED" }

    $descriptionNote = if ($isFinal) {
        "$progressBar`nAll phases complete."
    } elseif ($nextPhaseName) {
        "$progressBar`nStatus: $statusIcon`n`nNext: $nextPhaseName"
    } else {
        "$progressBar`nStatus: $statusIcon"
    }

    if ($isFinal) {
        $props = @{
            Parameters       = @( @{ Name = "info"; Title = "Summary"; Value = $summaryText; Editor = "info" } )
            Title            = $phaseName
            Description      = $descriptionNote
            Width            = 900; Height = 480
            OkButtonName     = "Finish"
            CancelButtonName = "Exit & Revert All"
        }
        $finalResult = Read-Variable @props
        if ($finalResult -ne "ok") {
            [void](Invoke-AllPhasesRevert)
            return "revert"
        }
        return "next"
    }

    # --- Step 1: Continuation dialog (summary + Next Phase / Exit & Revert All) ---
    $createdSummary = Get-PhaseCreatedItemsSummary -createdItems $createdItems
    $infoText = "$summaryText`n`n$createdSummary"

    $props = @{
        Parameters       = @( @{ Name = "info"; Title = "Phase Summary"; Value = $infoText; Editor = "info" } )
        Title            = "$phaseName — $statusIcon"
        Description      = $descriptionNote
        Width            = 900; Height = 500
        OkButtonName     = if ($nextPhaseName) { "Next Phase >" } else { "Continue" }
        CancelButtonName = "Exit & Revert All"
    }

    $result = Read-Variable @props
    # Read-Variable returns "ok" when OK is clicked; anything else ("cancel" or window close) = exit
    if ($result -ne "ok") {
        [void](Invoke-AllPhasesRevert)
        return "revert"
    }

    return "next"
}

function Set-PhaseResult {
    param(
        [string]$phase,
        [bool]$success,
        [string]$summary
    )

    $phaseResults[$phase] = [ordered]@{
        Success   = $success
        Summary   = $summary
        Timestamp = (Get-Date)
    }
}

function Get-MapCount {
    param([hashtable]$map)
    if (-not $map) { return 0 }
    return $map.Count
}

function Get-MappingFromField {
    param([string]$fieldValue)

    if ([string]::IsNullOrWhiteSpace($fieldValue)) {
        return @{}
    }

    try {
        $psObject = ConvertFrom-Json -InputObject $fieldValue -ErrorAction Stop
        $map = @{}
        foreach ($property in $psObject.PSObject.Properties) {
            $map[$property.Name] = $property.Value
        }
        return $map
    } catch {
        Write-Warning "Failed to parse mapping json: $_"
        return @{}
    }
}

function Create-MappingItem {
    param(
        [string]$name,
        [string]$parentPath,
        [string]$templateId,
        [string]$sourceId,
        [string]$targetId,
        [string]$sourceFieldId,
        [string]$targetFieldId,
        [string]$mappingType
    )

    $itemName = $name -replace "[^a-zA-Z0-9\-]", "-"
    $fullPath = "$parentPath/$itemName"

    if (Test-Path -Path $fullPath) {
        return $null
    }

    $mappingItem = Invoke-WithDeadlockRetry -Operation {
        if (Test-Path -Path $fullPath) {
            return $null
        }
        New-Item -Path $parentPath -Name $itemName -ItemType $templateId
    } -OperationName ("Create {0} mapping item '{1}'" -f $mappingType, $itemName)

    if (-not $mappingItem) {
        return $null
    }

    Invoke-ItemEditWithRetry -Item $mappingItem -Operation {
        $mappingItem.Fields[$sourceFieldId].Value = $sourceId
        $mappingItem.Fields[$targetFieldId].Value = $targetId
    } -OperationName ("Update mapping item '{0}'" -f $mappingItem.Paths.FullPath)

    $script:phase7Created.Add(@{
        Action     = "Created"
        Type       = "$mappingType Mapping"
        Name       = $mappingItem.Name
        SourcePath = $sourceId
        TargetPath = $mappingItem.Paths.FullPath
        TargetId   = $mappingItem.ID.ToString()
    })

    return $mappingItem
}

# ---------- helpers ----------
function Merge-JsonMapInto {
    param(
        [string]$json,
        [hashtable]$target
    )
    if ([string]::IsNullOrWhiteSpace($json)) { return }
    try { $obj = $json | ConvertFrom-Json } catch { return }
    if ($null -eq $obj) { return }
    foreach ($p in $obj.PSObject.Properties) {
        $k = ($p.Name | ForEach-Object { $_.ToString().ToLowerInvariant() })
        $v = $p.Value
        if ($k -and $v -and -not $target.ContainsKey($k)) {
            $target[$k] = $v.ToString()
        }
    }
}

function Resolve-ItemFromConfigValue {
    param([string]$value)

    if ([string]::IsNullOrWhiteSpace($value)) { return $null }

    $trimmed = $value.Trim()
    $trimmed = $trimmed -replace '^master:\s*', ''
    [Sitecore.Data.ID]$id = [Sitecore.Data.ID]::Null
    if ([Sitecore.Data.ID]::TryParse($trimmed, [ref]$id)) {
        return Get-Item -Path "master:" -ID $id
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
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ($seen.ContainsKey($candidate)) { continue }
        $seen[$candidate] = $true
        $item = Get-Item -Path $candidate
        if ($item) { return $item }
    }

    return $null
}

function Invoke-WithDeadlockRetry {
    param(
        [scriptblock]$Operation,
        [string]$OperationName = "Operation",
        [int]$MaxAttempts = 4,
        [int]$InitialDelayMs = 200
    )

    if (-not $Operation) {
        throw "Invoke-WithDeadlockRetry requires an operation script block."
    }

    $attempt = 0
    while ($attempt -lt $MaxAttempts) {
        $attempt++
        try {
            return (& $Operation)
        } catch {
            $message = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
            $isDeadlock = -not [string]::IsNullOrWhiteSpace($message) -and $message.ToLowerInvariant().Contains("deadlock")
            $isLastAttempt = ($attempt -ge $MaxAttempts)

            if (-not $isDeadlock -or $isLastAttempt) {
                throw
            }

            $delay = [Math]::Min(2000, $InitialDelayMs * [Math]::Pow(2, $attempt - 1))
            $jitter = Get-Random -Minimum 25 -Maximum 125
            $sleepMs = [int]($delay + $jitter)
            Write-Warning ("{0} hit SQL deadlock on attempt {1}/{2}. Retrying in {3} ms." -f $OperationName, $attempt, $MaxAttempts, $sleepMs)
            Start-Sleep -Milliseconds $sleepMs
        }
    }
}

function Invoke-ItemEditWithRetry {
    param(
        [Item]$Item,
        [Alias("Operation", "EditOperation")]
        [scriptblock]$EditScript,
        [string]$OperationName = "Edit item",
        [int]$MaxAttempts = 4,
        [int]$InitialDelayMs = 200
    )

    if (-not $Item) {
        throw "Invoke-ItemEditWithRetry requires an item."
    }
    if (-not $EditScript) {
        throw "Invoke-ItemEditWithRetry requires an edit operation script block."
    }

    Invoke-WithDeadlockRetry -Operation {
        try {
            [void]$Item.Editing.BeginEdit()
            & $EditScript
            [void]$Item.Editing.EndEdit()
        } catch {
            if ($Item.Editing.IsEditing) {
                try {
                    [void]$Item.Editing.CancelEdit()
                } catch {
                }
            }
            throw
        }
    } -OperationName $OperationName -MaxAttempts $MaxAttempts -InitialDelayMs $InitialDelayMs
}

function Get-OrCreateChildByName {
    param(
        [Item]$parent,
        [Item]$sourceItem
    )

    if (-not $parent -or -not $sourceItem) { return $null }

    $existing = $parent.Children | Where-Object { $_.Name -eq $sourceItem.Name } | Select-Object -First 1
    if ($existing) {
        return $existing
    }

    $copied = Invoke-WithDeadlockRetry `
        -Operation { $sourceItem.CopyTo($parent, $sourceItem.Name) } `
        -OperationName ("Copy child '{0}' to '{1}'" -f $sourceItem.Name, $parent.Paths.FullPath)
    return ($copied | Wrap-Item)
}

function Build-DatasourceMapFromRoots {
    param(
        [Item]$sourceRoot,
        [Item]$targetRoot,
        [hashtable]$map
    )

    if (-not $sourceRoot -or -not $targetRoot -or -not $map) { return }

    $sourceItems = @($sourceRoot) + @(Get-ChildItem -Path "master:" -ID $sourceRoot.ID -Recurse)
    foreach ($source in $sourceItems) {
        $relativePath = $source.Paths.FullPath.Substring($sourceRoot.Paths.FullPath.Length).TrimStart('/')
        $targetPath = if ([string]::IsNullOrWhiteSpace($relativePath)) {
            $targetRoot.Paths.FullPath
        } else {
            "$($targetRoot.Paths.FullPath)/$relativePath"
        }

        if (Test-Path -Path $targetPath) {
            $target = Get-Item -Path $targetPath
            if ($target) {
                $map[$source.ID.ToString().ToLowerInvariant()] = $target.ID.ToString()
            }
        }
    }
}

function Copy-DatasourceRoots-And-BuildMap {
    param(
        [Item[]]$mvcRoots,
        [Item]$headlessRoot,
        [hashtable]$map
    )

    if (-not $mvcRoots -or -not $headlessRoot -or -not $map) { return }

    foreach ($mvcRoot in $mvcRoots) {
        if (-not $mvcRoot) { continue }

        $mvcRootChildren = @($mvcRoot.Children)
        if (-not $mvcRootChildren -or $mvcRootChildren.Count -eq 0) {
            Write-Warning "MVC Datasource Root has no children to copy: $($mvcRoot.Paths.FullPath)"
            continue
        }

        foreach ($mvcChild in $mvcRootChildren) {
            $targetRoot = Get-OrCreateChildByName -parent $headlessRoot -sourceItem $mvcChild
            if (-not $targetRoot) {
                Write-Warning "Could not copy datasource child root: $($mvcChild.Paths.FullPath)"
                continue
            }

            $script:phase1Created.Add(@{
                Action     = "Mapped"
                Type       = "Datasource Root"
                Name       = $targetRoot.Name
                SourcePath = $mvcChild.Paths.FullPath
                TargetPath = $targetRoot.Paths.FullPath
                TargetId   = $targetRoot.ID.ToString()
            })

            Build-DatasourceMapFromRoots -sourceRoot $mvcChild -targetRoot $targetRoot -map $map
        }
    }
}

function Convert-DatasourceLocationUsingMap {
    param(
        [string]$location,
        [hashtable]$map
    )

    if ([string]::IsNullOrWhiteSpace($location) -or -not $map -or $map.Count -eq 0) {
        return $location
    }

    $parts = $location -split '\|'
    $updatedParts = [System.Collections.Generic.List[string]]::new()

    foreach ($part in $parts) {
        $trimmed = $part.Trim()
        $replaced = $part

        if ($trimmed.StartsWith("/sitecore/", [System.StringComparison]::OrdinalIgnoreCase)) {
            $srcItem = Get-Item -Path $trimmed -ErrorAction SilentlyContinue
            if ($srcItem) {
                $idKey = $srcItem.ID.ToString().ToLowerInvariant()
                if ($map.ContainsKey($idKey)) {
                    $tgtId = $map[$idKey]
                    $tgtItem = Get-Item -Path "master:" -ID ([Sitecore.Data.ID]$tgtId) -ErrorAction SilentlyContinue
                    if ($tgtItem) {
                        $replaced = $tgtItem.Paths.FullPath
                    }
                }
            }
        }

        $updatedParts.Add($replaced)
    }

    return ($updatedParts -join "|")
}

function Update-RenderingDatasourceLocations {
    param([hashtable]$map)

    if (-not $map -or $map.Count -eq 0) { return }

    $processed = @{}
    foreach ($targetId in $renderingIdMap.Values) {
        if ([string]::IsNullOrWhiteSpace($targetId)) { continue }
        if ($processed.ContainsKey($targetId)) { continue }
        $processed[$targetId] = $true

        $renderingItem = Resolve-ItemFromConfigValue -value $targetId
        if (-not $renderingItem) { continue }

        $original = $renderingItem["Datasource Location"]
        $remapped = Convert-DatasourceLocationUsingMap -location $original -map $map
        if ($original -ne $remapped) {
            Invoke-ItemEditWithRetry -Item $renderingItem -Operation {
                $renderingItem["Datasource Location"] = $remapped
            } -OperationName ("Update datasource location on '{0}'" -f $renderingItem.Paths.FullPath)
        }
    }
}

function Update-DatasourceItemTemplates {
    param(
        [hashtable]$datasourceMap,
        [hashtable]$templateMap
    )

    if (-not $datasourceMap -or $datasourceMap.Count -eq 0) { return }
    if (-not $templateMap -or $templateMap.Count -eq 0) { return }

    Write-Host "`nUpdating datasource item templates to headless versions..."

    $processed = @{}
    foreach ($tgtIdStr in $datasourceMap.Values) {
        if ([string]::IsNullOrWhiteSpace($tgtIdStr)) { continue }
        if ($processed.ContainsKey($tgtIdStr)) { continue }
        $processed[$tgtIdStr] = $true

        $tgtItem = Get-Item -Path "master:" -ID ([Sitecore.Data.ID]$tgtIdStr) -ErrorAction SilentlyContinue
        if (-not $tgtItem) { continue }

        $tplKey = $tgtItem.TemplateID.ToString().ToLowerInvariant()
        if (-not $templateMap.ContainsKey($tplKey)) { continue }

        $newTemplatePath = $templateMap[$tplKey]
        if ([string]::IsNullOrWhiteSpace($newTemplatePath)) { continue }

        $newTemplateItem = Get-Item -Path $newTemplatePath -ErrorAction SilentlyContinue
        if (-not $newTemplateItem) {
            Write-Warning "Could not resolve new template at: $newTemplatePath"
            continue
        }

        try {
            Set-ItemTemplate -Item $tgtItem -TemplateItem $newTemplateItem
            Write-Host "Template updated: $($tgtItem.Paths.FullPath)  ->  $newTemplatePath"
        } catch {
            Write-Warning "Failed to set template on $($tgtItem.Paths.FullPath): $_"
        }
    }

    Write-Host "Datasource item template update complete."
}

function Get-TemplateRelativePath {
    param([Item]$templateItem)

    if (-not $templateItem) { return $null }

    $fullPath = $templateItem.Paths.FullPath
    $m = [regex]::Match($fullPath, "^/sitecore/templates/(Feature|Foundation|Project)/(.+)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        return $m.Groups[2].Value
    }

    $m2 = [regex]::Match($fullPath, "^/sitecore/templates/(.+)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m2.Success) {
        return $m2.Groups[1].Value
    }

    return $templateItem.Name
}

function Initialize-TemplateFolderPath {
    param(
        [Item]$root,
        [string[]]$segments
    )

    $current = $root
    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        $existing = $current.Children | Where-Object { $_.Name -eq $segment } | Select-Object -First 1
        if ($existing) {
            $current = $existing
            continue
        }

        $current = New-Item -ItemType "System/Templates/Template Folder" -Parent $current -Name $segment | Wrap-Item
        if ($current) {
            $script:phase2Created.Add(@{
                Action     = "Created"
                Type       = "Template Folder"
                Name       = $current.Name
                SourcePath = "(generated path segment)"
                TargetPath = $current.Paths.FullPath
                TargetId   = $current.ID.ToString()
            })
        }
    }

    return $current
}

function Copy-TemplateToHeadlessRoot {
    param(
        [string]$sourceTemplateValue,
        [Item]$headlessTemplatesRoot
    )

    if ([string]::IsNullOrWhiteSpace($sourceTemplateValue) -or -not $headlessTemplatesRoot) {
        return $null
    }

    $sourceTemplateItem = Resolve-ItemFromConfigValue -value $sourceTemplateValue
    if (-not $sourceTemplateItem) {
        return $null
    }

    $mapKey = $sourceTemplateItem.ID.ToString().ToLowerInvariant()
    if ($templateIdMap.ContainsKey($mapKey)) {
        $mapped = Resolve-ItemFromConfigValue -value $templateIdMap[$mapKey]
        if ($mapped) { return $mapped }
    }

    $relativePath = Get-TemplateRelativePath -templateItem $sourceTemplateItem
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return $null
    }

    $segments = $relativePath -split '/' | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    if (-not $segments -or $segments.Count -eq 0) {
        return $null
    }

    $leafName = $segments[$segments.Count - 1]
    $folderSegments = @()
    if ($segments.Count -gt 1) {
        $folderSegments = $segments[0..($segments.Count - 2)]
    }

    $targetParent = Initialize-TemplateFolderPath -root $headlessTemplatesRoot -segments $folderSegments
    if (-not $targetParent) {
        return $null
    }

    $existing = $targetParent.Children | Where-Object { $_.Name -eq $leafName } | Select-Object -First 1
    if ($existing) {
        $templateIdMap[$mapKey] = $existing.Paths.FullPath
        return $existing
    }

    $copiedRaw = $null
    try {
        $copiedRaw = Invoke-WithDeadlockRetry `
            -Operation { $sourceTemplateItem.CopyTo($targetParent, $leafName) } `
            -OperationName ("Copy template '{0}' to '{1}'" -f $sourceTemplateItem.Paths.FullPath, $targetParent.Paths.FullPath)
    } catch {
        if ($_.Exception.Message -like "*already defined on this level*") {
            # Stale children cache: another template with the same leaf name was already
            # copied into this folder in an earlier iteration. Re-fetch and reuse it.
            $existing = $targetParent.Children | Where-Object { $_.Name -eq $leafName } | Select-Object -First 1
            if ($existing) {
                $templateIdMap[$mapKey] = $existing.Paths.FullPath
                return $existing
            }
        }
        throw
    }

    $copied = $copiedRaw | Wrap-Item
    if ($copied) {
        $templateIdMap[$mapKey] = $copied.Paths.FullPath
        $script:phase2Created.Add(@{
            Action     = "Created"
            Type       = "Template"
            Name       = $copied.Name
            SourcePath = $sourceTemplateItem.Paths.FullPath
            TargetPath = $copied.Paths.FullPath
            TargetId   = $copied.ID.ToString()
        })
    }

    return $copied
}

function Set-TemplateBaseInheritance {
    param(
        [Item]$templateItem,
        [string[]]$requiredBaseIds
    )

    if (-not $templateItem -or -not $requiredBaseIds -or $requiredBaseIds.Count -eq 0) { return }

    $baseField = $templateItem["__Base template"]
    $existingRaw = @()
    if (-not [string]::IsNullOrWhiteSpace($baseField)) {
        $existingRaw = $baseField -split '\|' | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    }

    $existingNorm = @{}
    foreach ($idValue in $existingRaw) {
        $normalized = ($idValue -replace '[\{\}]', '').Trim().ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $existingNorm[$normalized] = $true
        }
    }

    $updated = @($existingRaw)
    foreach ($requiredId in $requiredBaseIds) {
        $requiredNorm = ($requiredId -replace '[\{\}]', '').Trim().ToLowerInvariant()
        if (-not $existingNorm.ContainsKey($requiredNorm)) {
            $updated += $requiredId
            $existingNorm[$requiredNorm] = $true
        }
    }

    $newValue = ($updated -join "|")
    if ($newValue -ne $baseField) {
        Invoke-ItemEditWithRetry -Item $templateItem -Operation {
            $templateItem["__Base template"] = $newValue
        } -OperationName ("Update base templates on '{0}'" -f $templateItem.Paths.FullPath)
    }
}

function Get-ItemFieldFirstValue {
    param(
        [Item]$item,
        [string[]]$fieldNames
    )

    if (-not $item -or -not $fieldNames -or $fieldNames.Count -eq 0) {
        return $null
    }

    foreach ($fieldName in $fieldNames) {
        $value = $item[$fieldName]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

function Resolve-DatasourceConfigurationItem {
    param(
        [Item]$mvcRenderingItem,
        [Item]$datasourceConfigRoot
    )

    if (-not $datasourceConfigRoot) {
        return $mvcRenderingItem
    }

    $datasourceLocation = Get-ItemFieldFirstValue -item $mvcRenderingItem -fieldNames @("Datasource Location", "DatasourceLocation")
    if ([string]::IsNullOrWhiteSpace($datasourceLocation)) {
        return $mvcRenderingItem
    }

    $match = [regex]::Match($datasourceLocation, "site:([^|,]+)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return $mvcRenderingItem
    }

    $configItemName = $match.Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($configItemName)) {
        return $mvcRenderingItem
    }

    $configuredItem = $datasourceConfigRoot.Children | Where-Object { $_.Name -eq $configItemName } | Select-Object -First 1
    if ($configuredItem) {
        return $configuredItem
    }

    Write-Warning "Datasource config item '$configItemName' was not found under $($datasourceConfigRoot.Paths.FullPath). Using MVC rendering item values."
    return $mvcRenderingItem
}

function Get-ConfigIntOrDefault {
    param(
        [Item]$configItem,
        [string[]]$fieldNames,
        [int]$defaultValue
    )

    if (-not $configItem -or -not $fieldNames -or $fieldNames.Count -eq 0) {
        return $defaultValue
    }

    foreach ($fieldName in $fieldNames) {
        $raw = $configItem[$fieldName]
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }

        $parsed = 0
        if ([int]::TryParse($raw.Trim(), [ref]$parsed) -and $parsed -gt 0) {
            return $parsed
        }
    }

    return $defaultValue
}

function Resolve-PrimaryLanguageIsoCode {
    param([Item]$configItem)

    if (-not $configItem) { return $null }

    $primaryLanguageValue = $configItem["Primary Language"]
    if ([string]::IsNullOrWhiteSpace($primaryLanguageValue)) {
        return $null
    }

    $languageItem = Resolve-ItemFromConfigValue -value $primaryLanguageValue
    if (-not $languageItem) {
        Write-Warning "Phase 8: 'Primary Language' value could not be resolved to an item. Falling back to current language context."
        return $null
    }

    foreach ($fieldName in @("Regional Iso Code", "Regional ISO Code", "Region Iso Code", "Iso", "ISO")) {
        $iso = $languageItem[$fieldName]
        if (-not [string]::IsNullOrWhiteSpace($iso)) {
            return $iso.Trim()
        }
    }

    Write-Warning "Phase 8: 'Primary Language' item does not contain a Regional Iso Code value. Falling back to current language context."
    return $null
}

function Resolve-DynamicPlaceholderTemplateItem {
    param([Item]$configItem)

    if ($configItem) {
        foreach ($fieldName in @("IDynamicPlaceholder Template", "Dynamic Placeholder Template")) {
            $configured = $configItem[$fieldName]
            if ([string]::IsNullOrWhiteSpace($configured)) { continue }

            $item = Resolve-ItemFromConfigValue -value $configured
            if ($item) { return $item }
            Write-Warning "Could not resolve $fieldName value: $configured"
        }
    }

    foreach ($path in $dynamicPlaceholderTemplateFallbackPaths) {
        $fallback = Get-Item -Path $path -ErrorAction SilentlyContinue
        if ($fallback) { return $fallback }
    }

    return $null
}

function Ensure-RenderingOtherPropertyFlag {
    param(
        [Item]$renderingItem,
        [string]$flagValue
    )

    if (-not $renderingItem -or [string]::IsNullOrWhiteSpace($flagValue)) { return $false }

    $otherPropsField = $renderingItem.Fields["OtherProperties"]
    if (-not $otherPropsField) {
        $otherPropsField = $renderingItem.Fields["Other properties"]
    }
    if (-not $otherPropsField) {
        $otherPropsField = $renderingItem.Fields["Other Properties"]
    }
    if (-not $otherPropsField) { return $false }

    $current = $otherPropsField.Value

    $nvc = [System.Collections.Specialized.NameValueCollection]::new()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        if ($current.Contains("=") -or $current.Contains("&")) {
            $parsed = [System.Web.HttpUtility]::ParseQueryString($current)
            foreach ($k in $parsed.AllKeys) {
                if ([string]::IsNullOrWhiteSpace($k)) { continue }
                $nvc[$k] = $parsed[$k]
            }
        } else {
            $tokens = $current -split '[\|,;`r`n]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            foreach ($token in $tokens) {
                $trimmed = $token.Trim()
                if ($trimmed -match '^([^=]+)=(.*)$') {
                    $nvc[$matches[1].Trim()] = $matches[2].Trim()
                } else {
                    $nvc[$trimmed] = "true"
                }
            }
        }
    }

    if ($nvc[$flagValue] -eq "true") { return $false }
    $nvc[$flagValue] = "true"

    $pairs = [System.Collections.Generic.List[string]]::new()
    foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)) {
        $encodedKey = [System.Uri]::EscapeDataString($k)
        $encodedVal = [System.Uri]::EscapeDataString([string]$nvc[$k])
        $pairs.Add(("{0}={1}" -f $encodedKey, $encodedVal))
    }
    $newValue = ($pairs -join "&")

    if ($newValue -eq $current) { return $false }

    Invoke-ItemEditWithRetry -Item $renderingItem -Operation {
        $otherPropsField.Value = $newValue
    } -OperationName ("Update other properties on '{0}'" -f $renderingItem.Paths.FullPath)
    return $true
}

function Get-SitecoreDynamicPlaceholderOwnersFromXml {
    param([string]$XmlString)

    if ([string]::IsNullOrWhiteSpace($XmlString)) {
        return [PSCustomObject]@{
            resolvedOwnerComponents = @()
            externalOwnerComponents = @()
        }
    }

    [xml]$xml = $XmlString
    $nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsMgr.AddNamespace("s", "s")
    $nsMgr.AddNamespace("p", "p")

    function Get-RAttr([System.Xml.XmlElement]$node, [string]$localName) {
        $val = $node.GetAttribute($localName, "s")
        if ([string]::IsNullOrEmpty($val)) {
            $val = $node.GetAttribute($localName)
        }
        return $val
    }

    $jssSegPattern = [regex]'^(.*)-(\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\})-(\d+)$'

    $uidToSid = @{}
    foreach ($r in $xml.SelectNodes("//r", $nsMgr)) {
        $uid = (Get-RAttr $r "uid").ToUpperInvariant()
        $sid = (Get-RAttr $r "id").ToUpperInvariant()
        if ($uid -and $sid) {
            $uidToSid[$uid] = $sid
        }
    }

    $ownerSidToPhs = @{}
    $externalUidToPhs = @{}

    foreach ($r in $xml.SelectNodes("//r", $nsMgr)) {
        $ph = Get-RAttr $r "ph"
        if ([string]::IsNullOrEmpty($ph)) { continue }

        foreach ($segment in ($ph -split '/')) {
            if ([string]::IsNullOrEmpty($segment)) { continue }

            $m = $jssSegPattern.Match($segment)
            if (-not $m.Success) { continue }

            $baseName = $m.Groups[1].Value
            $ownerUid = $m.Groups[2].Value.ToUpperInvariant()
            $sxaPhKey = "$baseName-{*}"

            if ($uidToSid.ContainsKey($ownerUid)) {
                $ownerSid = $uidToSid[$ownerUid]
                if (-not $ownerSidToPhs.ContainsKey($ownerSid)) {
                    $ownerSidToPhs[$ownerSid] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                }
                [void]$ownerSidToPhs[$ownerSid].Add($sxaPhKey)
            } else {
                if (-not $externalUidToPhs.ContainsKey($ownerUid)) {
                    $externalUidToPhs[$ownerUid] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                }
                [void]$externalUidToPhs[$ownerUid].Add($sxaPhKey)
            }
        }
    }

    $resolvedComponents = @(
        $ownerSidToPhs.GetEnumerator() |
            Sort-Object Key |
            ForEach-Object {
                [PSCustomObject]@{
                    componentId = $_.Key
                    isRenderingsWithDynamicPlaceholders = $true
                    placeholderSettingKeys = @($_.Value | Sort-Object)
                }
            }
    )

    $externalComponents = @(
        $externalUidToPhs.GetEnumerator() |
            Sort-Object Key |
            ForEach-Object {
                [PSCustomObject]@{
                    ownerInstanceUid = $_.Key
                    componentId = $null
                    note = "Owner instance not found in this XML. Locate this rendering item separately to set IsRenderingsWithDynamicPlaceholders=true."
                    placeholderSettingKeys = @($_.Value | Sort-Object)
                }
            }
    )

    return [PSCustomObject]@{
        resolvedOwnerComponents = $resolvedComponents
        externalOwnerComponents = $externalComponents
    }
}

function Add-OwnerPlaceholderKeysToMap {
    param(
        [hashtable]$targetMap,
        [string]$ownerKey,
        [string[]]$placeholderKeys
    )

    if (-not $targetMap -or [string]::IsNullOrWhiteSpace($ownerKey)) { return }
    if (-not $targetMap.ContainsKey($ownerKey)) {
        $targetMap[$ownerKey] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    foreach ($k in $placeholderKeys) {
        if ([string]::IsNullOrWhiteSpace($k)) { continue }
        [void]$targetMap[$ownerKey].Add($k)
    }
}

function Get-MappedIdValue {
    param(
        [hashtable]$map,
        [string]$sourceId
    )

    if (-not $map -or [string]::IsNullOrWhiteSpace($sourceId)) { return $null }

    $raw = $sourceId.Trim().ToLowerInvariant()
    $normalized = ($raw -replace '[\{\}]', '')
    $withBraces = "{$normalized}"

    foreach ($key in @($raw, $normalized, $withBraces)) {
        if ($map.ContainsKey($key)) {
            return $map[$key]
        }
    }

    return $null
}

function Get-MvcPageTypeTemplatesFromConfiguredItems {
    param([Item[]]$configuredItems)

    $templates = [System.Collections.Generic.List[Item]]::new()
    $seen = @{}

    foreach ($configured in $configuredItems) {
        if (-not $configured) { continue }

        if ($configured.TemplateID -eq $pageTemplateId) {
            $key = $configured.ID.ToString().ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $templates.Add($configured)
            }
            continue
        }

        $descendantTemplates = Get-ChildItem -Path "master:" -ID $configured.ID -Recurse | Where-Object { $_.TemplateID -eq $pageTemplateId }
        foreach ($tpl in $descendantTemplates) {
            $key = $tpl.ID.ToString().ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $templates.Add($tpl)
            }
        }
    }

    return $templates
}

function Get-SampledPagesByTemplate {
    param(
        [Item]$mvcStartItem,
        [Item[]]$mvcPageTemplates,
        [int]$sampleSize,
        [string]$languageIsoCode
    )

    $result = [ordered]@{}
    $startItemForLanguage = $mvcStartItem
    if (-not [string]::IsNullOrWhiteSpace($languageIsoCode)) {
        $languageStartItem = Get-Item -Path "master:" -ID $mvcStartItem.ID -Language $languageIsoCode -ErrorAction SilentlyContinue
        if ($languageStartItem) {
            $startItemForLanguage = $languageStartItem
        }
    }

    $allDescendants = if ([string]::IsNullOrWhiteSpace($languageIsoCode)) {
        @($startItemForLanguage) + @(Get-ChildItem -Path "master:" -ID $mvcStartItem.ID -Recurse)
    } else {
        @($startItemForLanguage) + @(Get-ChildItem -Path "master:" -ID $mvcStartItem.ID -Recurse -Language $languageIsoCode)
    }

    foreach ($template in $mvcPageTemplates) {
        $templateMatches = @($allDescendants | Where-Object { $_.TemplateID -eq $template.ID } | Sort-Object { $_.Paths.FullPath })
        if ($templateMatches.Count -gt $sampleSize) {
            $templateMatches = @($templateMatches | Select-Object -First $sampleSize)
        }
        $result[$template.ID.ToString().ToLowerInvariant()] = [PSCustomObject]@{
            Template = $template
            Pages = $templateMatches
        }
    }

    return $result
}

function Build-PlaceholderLookupMaps {
    param([hashtable]$mapping)

    $lookupByTargetKey = @{}
    $lookupBySourceKey = @{}

    foreach ($sourceId in $mapping.Keys) {
        $targetId = $mapping[$sourceId]
        $sourceItem = Resolve-ItemFromConfigValue -value $sourceId
        $targetItem = Resolve-ItemFromConfigValue -value $targetId
        if (-not $sourceItem -or -not $targetItem) { continue }

        $sourceKey = $sourceItem["Placeholder Key"]
        $targetKey = $targetItem["Placeholder Key"]

        if (-not [string]::IsNullOrWhiteSpace($sourceKey)) {
            $sourceLower = $sourceKey.ToLowerInvariant()
            $lookupBySourceKey[$sourceLower] = $targetItem.ID.ToString()

            $sourceBase = ($sourceLower -replace '-\{\*\}$', '')
            $lookupBySourceKey[$sourceBase] = $targetItem.ID.ToString()
        }

        if (-not [string]::IsNullOrWhiteSpace($targetKey)) {
            $targetLower = $targetKey.ToLowerInvariant()
            $lookupByTargetKey[$targetLower] = $targetItem.ID.ToString()

            $targetBase = ($targetLower -replace '-\{\*\}$', '')
            $lookupByTargetKey[$targetBase] = $targetItem.ID.ToString()
        }
    }

    return [PSCustomObject]@{
        ByTargetKey = $lookupByTargetKey
        BySourceKey = $lookupBySourceKey
    }
}

function Test-ParametersTemplateUsedByNonDetectedRendering {
    param(
        [Item]$parametersTemplateItem,
        [Item]$currentRendering,
        [hashtable]$renderingMappings,
        [hashtable]$detectedRenderingIds
    )

    if (-not $parametersTemplateItem -or -not $currentRendering -or -not $renderingMappings) {
        return $false
    }

    foreach ($mappedRenderingId in ($renderingMappings.Values | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($mappedRenderingId)) { continue }

        $candidateRendering = Resolve-ItemFromConfigValue -value $mappedRenderingId
        if (-not $candidateRendering) { continue }
        if ($candidateRendering.ID -eq $currentRendering.ID) { continue }

        $candidateParametersTemplateRef = $candidateRendering["Parameters Template"]
        $candidateParametersTemplate = Resolve-ItemFromConfigValue -value $candidateParametersTemplateRef
        if (-not $candidateParametersTemplate) { continue }
        if ($candidateParametersTemplate.ID -ne $parametersTemplateItem.ID) { continue }

        $candidateKey = $candidateRendering.ID.ToString().ToLowerInvariant()
        if (-not $detectedRenderingIds.ContainsKey($candidateKey)) {
            return $true
        }
    }

    return $false
}

function Get-TemplateFieldsInfo {
    param([Item]$templateItem)

    if (-not $templateItem) { return $null }

    $template = [Sitecore.Data.Items.TemplateItem]$templateItem

    $systemTemplateRegex = '^/sitecore/templates/system(?:/|$)'
    $fields = @($template.Fields | Where-Object {
        $fieldPath = if ($_.InnerItem -and $_.InnerItem.Paths) { $_.InnerItem.Paths.FullPath } else { $null }
        -not [regex]::IsMatch($fieldPath, $systemTemplateRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    } | ForEach-Object {
        [ordered]@{
            section = if ($_.Section) { $_.Section.Name } else { '' }
            name    = $_.Name
            type    = $_.Type
        }
    })

    return [ordered]@{
        name   = $templateItem.Name
        id     = $templateItem.ID.ToString()
        fields = $fields
    }
}

function Invoke-DynamicPlaceholderPhase {
    param(
        [Item]$configItem,
        [Item]$mvcStartItem,
        [Item[]]$mvcTemplateConfigItems,
        [hashtable]$renderingMappings,
        [hashtable]$placeholderMappings,
        [string]$headlessPrefix,
        [int]$sampleSize,
        [string]$languageIsoCode
    )

    $mvcPageTemplates = Get-MvcPageTypeTemplatesFromConfiguredItems -configuredItems $mvcTemplateConfigItems
    if (-not $mvcPageTemplates -or $mvcPageTemplates.Count -eq 0) {
        throw "No MVC page type templates could be resolved for Phase 8 sampling."
    }

    $samplesByTemplate = Get-SampledPagesByTemplate -mvcStartItem $mvcStartItem -mvcPageTemplates $mvcPageTemplates -sampleSize $sampleSize -languageIsoCode $languageIsoCode

    $resolvedOwnerMap = @{}
    $sampledPages = [System.Collections.Generic.List[Item]]::new()
    $seenPages = @{}
    $templateSummaryLines = [System.Collections.Generic.List[string]]::new()

    foreach ($templateKey in $samplesByTemplate.Keys) {
        $entry = $samplesByTemplate[$templateKey]
        $templateName = $entry.Template.Paths.FullPath
        $count = @($entry.Pages).Count
        $templateSummaryLines.Add(("- {0}: sampled {1} page(s)" -f $templateName, $count))

        foreach ($page in $entry.Pages) {
            $pageKey = $page.ID.ToString().ToLowerInvariant()
            if (-not $seenPages.ContainsKey($pageKey)) {
                $seenPages[$pageKey] = $true
                $sampledPages.Add($page)
            }
        }
    }

    foreach ($page in $sampledPages) {
        foreach ($fieldId in @($renderingsFieldId, $finalRenderingsFieldId)) {
            $layoutXml = $page.Fields[$fieldId].Value
            if ([string]::IsNullOrWhiteSpace($layoutXml)) { continue }

            try {
                $ownerResult = Get-SitecoreDynamicPlaceholderOwnersFromXml -XmlString $layoutXml

                foreach ($resolved in $ownerResult.resolvedOwnerComponents) {
                    Add-OwnerPlaceholderKeysToMap -targetMap $resolvedOwnerMap -ownerKey $resolved.componentId -placeholderKeys $resolved.placeholderSettingKeys
                }
            } catch {
                Write-Warning "Failed to parse layout XML for page $($page.Paths.FullPath), field ${fieldId}: $($_.Exception.Message)"
            }
        }
    }

    $dynamicTemplateItem = Resolve-DynamicPlaceholderTemplateItem -configItem $configItem
    $dynamicTemplateId = if ($dynamicTemplateItem) { $dynamicTemplateItem.ID.ToString() } else { $null }

    $updatedRenderings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $resolvedRenderings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $updatedParamTemplates = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $updatedPlaceholderSettings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $renderingResolutionLog = [System.Collections.Generic.List[string]]::new()

    $detectedRenderingIds = @{}
    foreach ($sourceComponentId in $resolvedOwnerMap.Keys) {
        $detectedTargetRenderingId = Get-MappedIdValue -map $renderingMappings -sourceId $sourceComponentId
        if ([string]::IsNullOrWhiteSpace($detectedTargetRenderingId)) { continue }

        $detectedTargetRendering = Resolve-ItemFromConfigValue -value $detectedTargetRenderingId
        if (-not $detectedTargetRendering) { continue }

        $detectedRenderingIds[$detectedTargetRendering.ID.ToString().ToLowerInvariant()] = $true
    }

    foreach ($sourceComponentId in $resolvedOwnerMap.Keys) {
        $mappedTargetRenderingId = Get-MappedIdValue -map $renderingMappings -sourceId $sourceComponentId
        if ([string]::IsNullOrWhiteSpace($mappedTargetRenderingId)) {
            $renderingResolutionLog.Add(("- source component {0} -> mapping not found" -f $sourceComponentId))
            continue
        }

        $targetRendering = Resolve-ItemFromConfigValue -value $mappedTargetRenderingId
        if (-not $targetRendering) {
            $renderingResolutionLog.Add(("- source component {0} -> mapped {1} -> target rendering not found" -f $sourceComponentId, $mappedTargetRenderingId))
            continue
        }

        [void]$resolvedRenderings.Add($targetRendering.ID.ToString())
        $renderingResolutionLog.Add(("- source component {0} -> mapped {1} -> {2}" -f $sourceComponentId, $mappedTargetRenderingId, $targetRendering.Paths.FullPath))

        if (Ensure-RenderingOtherPropertyFlag -renderingItem $targetRendering -flagValue $dynamicPlaceholderOtherPropertyFlag) {
            [void]$updatedRenderings.Add($targetRendering.ID.ToString())
            $renderingResolutionLog.Add(("  rendering flag updated on {0}" -f $targetRendering.Paths.FullPath))
            $script:phase8Created.Add(@{
                Action     = "Updated"
                Type       = "Rendering"
                Name       = $targetRendering.Name
                SourcePath = $sourceComponentId
                TargetPath = $targetRendering.Paths.FullPath
                TargetId   = $targetRendering.ID.ToString()
            })
        } else {
            $renderingResolutionLog.Add(("  rendering flag unchanged or field missing on {0}" -f $targetRendering.Paths.FullPath))
        }

        if (-not [string]::IsNullOrWhiteSpace($dynamicTemplateId)) {
            $paramsTemplateRef = $targetRendering["Parameters Template"]
            $paramsTemplateItem = Resolve-ItemFromConfigValue -value $paramsTemplateRef
            if ($paramsTemplateItem) {
                $isSharedWithNonDetectedRendering = Test-ParametersTemplateUsedByNonDetectedRendering `
                    -parametersTemplateItem $paramsTemplateItem `
                    -currentRendering $targetRendering `
                    -renderingMappings $renderingMappings `
                    -detectedRenderingIds $detectedRenderingIds

                if ($isSharedWithNonDetectedRendering) {
                    $renderingResolutionLog.Add(("  parameters template skipped for {0} because {1} is shared with non-detected renderings" -f $targetRendering.Paths.FullPath, $paramsTemplateItem.Paths.FullPath))
                } else {
                    $beforeBase = $paramsTemplateItem["__Base template"]
                    Set-TemplateBaseInheritance -templateItem $paramsTemplateItem -requiredBaseIds @($dynamicTemplateId)
                    if ($beforeBase -ne $paramsTemplateItem["__Base template"]) {
                        [void]$updatedParamTemplates.Add($paramsTemplateItem.ID.ToString())
                        $script:phase8Created.Add(@{
                            Action     = "Updated"
                            Type       = "Parameters Template"
                            Name       = $paramsTemplateItem.Name
                            SourcePath = $sourceComponentId
                            TargetPath = $paramsTemplateItem.Paths.FullPath
                            TargetId   = $paramsTemplateItem.ID
                        })
                    }
                }
            } else {
                $renderingResolutionLog.Add(("  parameters template not found for {0}" -f $targetRendering.Paths.FullPath))
            }
        }
    }

    $lookupMaps = Build-PlaceholderLookupMaps -mapping $placeholderMappings
    $normalizedPrefix = if ([string]::IsNullOrWhiteSpace($headlessPrefix)) { "headless" } else { $headlessPrefix.Trim() }

    $ownerToPlaceholderItemIds = @{}
    foreach ($ownerKey in $resolvedOwnerMap.Keys) {
        foreach ($placeholderDynamicKey in $resolvedOwnerMap[$ownerKey]) {
            if ([string]::IsNullOrWhiteSpace($placeholderDynamicKey)) { continue }

            $baseKey = ($placeholderDynamicKey -replace '-\{\*\}$', '')
            $lookupKey = ("{0}-{1}" -f $normalizedPrefix, $baseKey).ToLowerInvariant()
            $prefixedDynamicKey = "{0}-{1}-{{*}}" -f $normalizedPrefix, $baseKey

            $targetPlaceholderId = $null
            if ($lookupMaps.ByTargetKey.ContainsKey($lookupKey)) {
                $targetPlaceholderId = $lookupMaps.ByTargetKey[$lookupKey]
            } elseif ($lookupMaps.BySourceKey.ContainsKey($baseKey.ToLowerInvariant())) {
                $targetPlaceholderId = $lookupMaps.BySourceKey[$baseKey.ToLowerInvariant()]
            }

            if ([string]::IsNullOrWhiteSpace($targetPlaceholderId)) { continue }

            $targetPlaceholderItem = Resolve-ItemFromConfigValue -value $targetPlaceholderId
            if (-not $targetPlaceholderItem) { continue }

            if (-not $ownerToPlaceholderItemIds.ContainsKey($ownerKey)) {
                $ownerToPlaceholderItemIds[$ownerKey] = [System.Collections.Generic.List[string]]::new()
            }
            $ownerPlaceholderItemId = $targetPlaceholderItem.ID.ToString()
            if (-not $ownerToPlaceholderItemIds[$ownerKey].Contains($ownerPlaceholderItemId)) {
                $ownerToPlaceholderItemIds[$ownerKey].Add($ownerPlaceholderItemId)
            }

            $currentKey = $targetPlaceholderItem["Placeholder Key"]
            if ($currentKey -eq $prefixedDynamicKey) { continue }

            Invoke-ItemEditWithRetry -Item $targetPlaceholderItem -Operation {
                $targetPlaceholderItem["Placeholder Key"] = $prefixedDynamicKey
            } -OperationName ("Update placeholder key on '{0}'" -f $targetPlaceholderItem.Paths.FullPath)

            [void]$updatedPlaceholderSettings.Add($targetPlaceholderItem.ID.ToString())
            $script:phase8Created.Add(@{
                Action     = "Updated"
                Type       = "Placeholder Setting"
                Name       = $targetPlaceholderItem.Name
                SourcePath = $lookupKey
                TargetPath = $targetPlaceholderItem.Paths.FullPath
                TargetId   = $targetPlaceholderItem.ID.ToString()
            })
        }
    }

    # Update Layout Service Placeholders field (Treelist "Placeholders") on each resolved rendering
    $updatedRenderingPlaceholders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ownerKey in $ownerToPlaceholderItemIds.Keys) {
        $mappedId = Get-MappedIdValue -map $renderingMappings -sourceId $ownerKey
        if ([string]::IsNullOrWhiteSpace($mappedId)) { continue }

        $targetRendering = Resolve-ItemFromConfigValue -value $mappedId
        if (-not $targetRendering) { continue }

        $newIds = @($ownerToPlaceholderItemIds[$ownerKey] | Select-Object -Unique)
        if ($newIds.Count -eq 0) { continue }

        $placeholdersField = $targetRendering.Fields["Placeholders"]
        if (-not $placeholdersField) { continue }

        $currentValue = $placeholdersField.Value
        $existingSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if (-not [string]::IsNullOrWhiteSpace($currentValue)) {
            foreach ($id in ($currentValue -split '\|' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                [void]$existingSet.Add($id)
            }
        }

        $addedAny = $false
        foreach ($id in $newIds) {
            if ($existingSet.Add($id)) { $addedAny = $true }
        }
        if (-not $addedAny) { continue }

        $newValue = ($existingSet | Sort-Object) -join '|'
        Invoke-ItemEditWithRetry -Item $targetRendering -Operation {
            $targetRendering["Placeholders"] = $newValue
        } -OperationName ("Update Placeholders field on '{0}'" -f $targetRendering.Paths.FullPath)

        [void]$updatedRenderingPlaceholders.Add($targetRendering.ID.ToString())
        $script:phase8Created.Add(@{
            Action     = "Updated"
            Type       = "Rendering (Placeholders field)"
            Name       = $targetRendering.Name
            SourcePath = $ownerKey
            TargetPath = $targetRendering.Paths.FullPath
            TargetId   = $targetRendering.ID.ToString()
        })
    }

    # Build map: target rendering ID (lowercase) → Headless-prefixed dynamic placeholder keys
    # derived from the same $resolvedOwnerMap already processed above.
    $targetRenderingDynPlaceholders = @{}
    foreach ($sourceComponentId in $resolvedOwnerMap.Keys) {
        $mappedId = Get-MappedIdValue -map $renderingMappings -sourceId $sourceComponentId
        if ([string]::IsNullOrWhiteSpace($mappedId)) { continue }
        $phKeys = @($resolvedOwnerMap[$sourceComponentId] | ForEach-Object {
            $base = $_ -replace '-\{\*\}$', ''
            "{0}-{1}-{{*}}" -f $normalizedPrefix, $base
        })
        $targetRenderingDynPlaceholders[$mappedId.ToLowerInvariant()] = $phKeys
    }

    # Renderings array
    $manifestRenderings = [System.Collections.Generic.List[object]]::new()
    foreach ($targetRenderingId in ($renderingMappings.Values | Select-Object -Unique)) {
        $rendering = Resolve-ItemFromConfigValue -value $targetRenderingId
        if (-not $rendering) { continue }

        $paramsTemplateItem = Resolve-ItemFromConfigValue -value $rendering.Fields["Parameters Template"].Value
        $dsTemplateItem     = Resolve-ItemFromConfigValue -value $rendering.Fields["Datasource Template"].Value

        # Placeholder keys this rendering exposes as dynamic slots, derived from sampled MVC page XML
        $rIdKey = $rendering.ID.ToString().ToLowerInvariant()
        $ownPlaceholders = if ($targetRenderingDynPlaceholders.ContainsKey($rIdKey)) {
            @($targetRenderingDynPlaceholders[$rIdKey])
        } else { @() }

        $manifestRenderings.Add([ordered]@{
            name               = $rendering.Name
            id                 = $rendering.ID.ToString()
            path               = $rendering.Paths.FullPath
            parametersTemplate = (Get-TemplateFieldsInfo -templateItem $paramsTemplateItem)
            datasourceTemplate = (Get-TemplateFieldsInfo -templateItem $dsTemplateItem)
            placeholders       = if ($ownPlaceholders.Count -gt 0) { $ownPlaceholders } else { $null }
        })
    }

    $manifestJson = ([ordered]@{
        generatedAt = (Get-Date -Format "o")
        renderings  = @($manifestRenderings)
    } | ConvertTo-Json -Depth 20)

    $renderingsWithPlaceholders = @($manifestRenderings | Where-Object { $_.placeholders.Count -gt 0 }).Count

    return [PSCustomObject]@{
        LanguageIsoCode                = if ([string]::IsNullOrWhiteSpace($languageIsoCode)) { "(context default)" } else { $languageIsoCode }
        SampledPagesCount               = $sampledPages.Count
        TemplateSampleSummary           = @($templateSummaryLines)
        ResolvedRenderingsCount         = $resolvedRenderings.Count
        UpdatedRenderingsCount                 = $updatedRenderings.Count
        UpdatedParameterTemplatesCount         = $updatedParamTemplates.Count
        UpdatedPlaceholderSettingsCount        = $updatedPlaceholderSettings.Count
        UpdatedRenderingPlaceholderFieldsCount = $updatedRenderingPlaceholders.Count
        RenderingResolutionLog                 = @($renderingResolutionLog)
        DynamicTemplateResolved         = [bool]$dynamicTemplateItem
        ManifestJson                    = $manifestJson
        ManifestRenderingCount          = $manifestRenderings.Count
        ManifestPlaceholderCount        = $renderingsWithPlaceholders
    }
}

# -------------------------
# Phase 1: Renderings
# -------------------------
function Copy-Renderings {
    param(
        [Item]$sourceItem,
        [string]$targetParentPath,
        [Item]$headlessTemplatesRoot,
        [int]$maxTraversalNodes = 200000
    )

    $stack = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push([PSCustomObject]@{ SourceItem = $sourceItem; TargetParentPath = $targetParentPath })
    $visitedSourceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $processedNodes = 0

    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        $currentSource = $node.SourceItem
        $currentTargetParentPath = $node.TargetParentPath

        if (-not $currentSource) {
            continue
        }

        $processedNodes++
        if ($processedNodes -gt $maxTraversalNodes) {
            throw "Copy-Renderings safety stop: processed over $maxTraversalNodes nodes. Check for cyclic children under $($sourceItem.Paths.FullPath)."
        }

        $currentSourceIdKey = $currentSource.ID.ToString().ToLowerInvariant()
        if (-not $visitedSourceIds.Add($currentSourceIdKey)) {
            Write-Warning "Copy-Renderings skipped already-visited source item (possible cycle/duplicate link): $($currentSource.Paths.FullPath)"
            continue
        }

        $templateId = $currentSource.TemplateID.Guid.ToString().ToLowerInvariant()
        $isRendering = $allowedSourceTemplateIds -contains $templateId

        $newItemName = $currentSource.Name -replace "\s", ""
        $newItemPath = "$currentTargetParentPath/$newItemName"

        $newItem = $null
        if (Test-Path -Path $newItemPath) {
            $newItem = Get-Item -Path $newItemPath
            Write-Host "Exists: $newItemPath"
            if ($isRendering -and $newItem) {
                $renderingIdMap[$currentSource.ID.ToString().ToLowerInvariant()] = $newItem.ID.ToString()
            }
        } else {
            if ($isRendering) {
                Write-Host "Creating rendering item at: $newItemPath"
                $newItem = New-Item -Path $newItemPath -ItemType $jsonRenderingTemplateId
                if ($newItem) {
                    $datasourceSourceItem = Resolve-DatasourceConfigurationItem -mvcRenderingItem $currentSource -datasourceConfigRoot $mvcDatasourceConfigurationRoot

                    Invoke-ItemEditWithRetry -Item $newItem -Operation {
                        $newItem["__Display name"]      = $currentSource.DisplayName
                        $newItem["Component Name"]      = $currentSource.Name

                        $newParametersTemplateItem = Copy-TemplateToHeadlessRoot -sourceTemplateValue $currentSource["Parameters Template"] -headlessTemplatesRoot $headlessTemplatesRoot
                        if ($newParametersTemplateItem) {
                            Set-TemplateBaseInheritance -templateItem $newParametersTemplateItem -requiredBaseIds @($baseRenderingParametersTemplateId)
                            $newItem["Parameters Template"] = $newParametersTemplateItem.ID.Guid.ToString("B").ToUpper()
                        } else {
                            $srcParamsTplItem = Resolve-ItemFromConfigValue -value $currentSource["Parameters Template"]
                            if ($srcParamsTplItem) {
                                $newItem["Parameters Template"] = $srcParamsTplItem.ID.Guid.ToString("B").ToUpper()
                            }
                        }

                        $datasourceLocationValue = Get-ItemFieldFirstValue -item $datasourceSourceItem -fieldNames @("Datasource Location", "DatasourceLocation")
                        $newItem["Datasource Location"] = "query:$site/*[@@name='Data']|query:$sharedSites/*[@@name='Data']"

                        $datasourceTemplateValue = Get-ItemFieldFirstValue -item $datasourceSourceItem -fieldNames @("Datasource Template", "DatasourceTemplate")

                        $newDatasourceTemplateItem = Copy-TemplateToHeadlessRoot -sourceTemplateValue $datasourceTemplateValue -headlessTemplatesRoot $headlessTemplatesRoot
                        if ($newDatasourceTemplateItem) {
                            $newItem["Datasource Template"] = $newDatasourceTemplateItem.Paths.FullPath
                        } else {
                            $srcDsTplItem = Resolve-ItemFromConfigValue -value $datasourceTemplateValue
                            if ($srcDsTplItem) {
                                $newItem["Datasource Template"] = $srcDsTplItem.Paths.FullPath
                            }
                        }

                        $newItem["Page Editor Buttons"] = $currentSource["Page Editor Buttons"]
                    } -OperationName ("Initialize rendering '{0}'" -f $newItem.Paths.FullPath)
                    $renderingIdMap[$currentSource.ID.ToString().ToLowerInvariant()] = $newItem.ID.ToString()
                    $script:phase2Created.Add(@{
                        Action     = "Created"
                        Type       = "Rendering"
                        Name       = $newItem.Name
                        SourcePath = $currentSource.Paths.FullPath
                        TargetPath = $newItem.Paths.FullPath
                        TargetId   = $newItem.ID.ToString()
                    })
                }
            } else {
                Write-Host "Creating folder item at: $newItemPath"
                $newItem = New-Item -Path $newItemPath -ItemType $renderingFolderTemplateId
                if ($newItem) {
                    Invoke-ItemEditWithRetry -Item $newItem -Operation {
                        $newItem["__Display name"] = $currentSource.DisplayName
                    } -OperationName ("Initialize rendering folder '{0}'" -f $newItem.Paths.FullPath)
                    $script:phase2Created.Add(@{
                        Action     = "Created"
                        Type       = "Rendering Folder"
                        Name       = $newItem.Name
                        SourcePath = $currentSource.Paths.FullPath
                        TargetPath = $newItem.Paths.FullPath
                        TargetId   = $newItem.ID.ToString()
                    })
                }
            }
        }

        if ($newItem) {
            $children = @($currentSource.Children)
            for ($i = $children.Count - 1; $i -ge 0; $i--) {
                if (-not $children[$i]) { continue }
                $stack.Push([PSCustomObject]@{
                    SourceItem = $children[$i]
                    TargetParentPath = $newItem.Paths.FullPath
                })
            }
        }
    }
}

# -------------------------
# Phase 2: Placeholders
# -------------------------
function Update-PlaceholderFields {
    param(
        [Item]$rootItem,
        [string]$prefix
    )
    $templateId = "{5C547D4E-7111-4995-95B0-6B561751BF2E}"

    if ([string]::IsNullOrWhiteSpace($prefix)) {
        $prefix = "headless"
    }
    $normalizedPrefix = $prefix.Trim()
    $prefixToken = "$normalizedPrefix-"

    if ($rootItem.TemplateID -eq $templateId) {
        $placeholders = @($rootItem)
    } else {
        $placeholders = Get-ChildItem -Path "master:" -ID $rootItem.ID -Recurse | Where-Object {
            $_.TemplateID -eq $templateId
        }
    }

    foreach ($placeholder in $placeholders) {
        Invoke-ItemEditWithRetry -Item $placeholder -Operation {
            $key = $placeholder["Placeholder Key"]
            if ($key -and -not $key.StartsWith($prefixToken, [System.StringComparison]::OrdinalIgnoreCase)) {
                $placeholder["Placeholder Key"] = "$prefixToken$key"
            }

            $allowed = $placeholder["Allowed Controls"]
            if ($allowed) {
                $updatedIds = ($allowed -split '\|') | ForEach-Object {
                    $lower = $_.ToLowerInvariant()
                    if ($renderingIdMap.ContainsKey($lower)) { $renderingIdMap[$lower] } else { $_ }
                }
                $placeholder["Allowed Controls"] = ($updatedIds -join "|")
            }
        } -OperationName ("Update placeholder settings '{0}'" -f $placeholder.Paths.FullPath)
    }
}

function Copy-And-Transform-Placeholders {
    param(
        [Item[]]$sourceItems,
        [Item]$targetRoot,
        [string]$prefix
    )

    $placeholderTemplateId = "{5C547D4E-7111-4995-95B0-6B561751BF2E}"

    foreach ($sourceRoot in $sourceItems) {
        Write-Host "`nProcessing placeholder root: $($sourceRoot.Paths.FullPath)"

        $targetFolder = Get-ChildItem -Path "master:" -ID $targetRoot.ID | Where-Object { $_.Name -eq $sourceRoot.Name }
        if (-not $targetFolder) {
            try {
                $null = $sourceRoot | Copy-Item -Destination $targetRoot.ID -Recurse
                $targetFolder = Get-ChildItem -Path "master:" -ID $targetRoot.ID | Where-Object { $_.Name -eq $sourceRoot.Name }
                if ($targetFolder) {
                    Write-Host "Copied to: $($targetFolder.Paths.FullPath)"
                    $script:phase3Created.Add(@{
                        Action     = "Created"
                        Type       = "Placeholder Root"
                        Name       = $targetFolder.Name
                        SourcePath = $sourceRoot.Paths.FullPath
                        TargetPath = $targetFolder.Paths.FullPath
                        TargetId   = $targetFolder.ID.ToString()
                    })
                } else {
                    Write-Warning "Could not resolve copied item even though Copy-Item ran."
                    continue
                }
            } catch {
                Write-Warning "Failed to copy placeholder root: $_"
                continue
            }
        } else {
            Write-Host "Skipped root copy (already exists): $($targetFolder.Paths.FullPath)"
        }

        if (-not $targetFolder -or -not $targetFolder.ID) {
            Write-Warning "Target folder is null or invalid. Skipping."
            continue
        }

        $originalItems = if ($sourceRoot.TemplateID -eq $placeholderTemplateId) {
            @($sourceRoot)
        } else {
            Get-ChildItem -Path "master:" -ID $sourceRoot.ID -Recurse | Where-Object {
                $_.TemplateID -eq $placeholderTemplateId
            }
        }
        $copiedItems = if ($targetFolder.TemplateID -eq $placeholderTemplateId) {
            @($targetFolder)
        } else {
            Get-ChildItem -Path "master:" -ID $targetFolder.ID -Recurse | Where-Object {
                $_.TemplateID -eq $placeholderTemplateId
            }
        }

        foreach ($original in $originalItems) {
            $matchingCopy = $copiedItems | Where-Object { $_.Name -eq $original.Name }
            if ($matchingCopy) {
                $srcId = $original.ID.ToString().ToLowerInvariant()
                $tgtId = $matchingCopy.ID.ToString()
                $placeholderIdMap[$srcId] = $tgtId
            }
        }

        try { Update-PlaceholderFields -rootItem $targetFolder -prefix $prefix } catch { Write-Warning "Failed to update placeholder fields: $_" }
    }
}

# -------------------------
# Phase 3: Page Templates
# -------------------------
$pageTemplateId = "{AB86861A-6030-46C5-B394-E8F99E8B87DB}"

function Get-OrCreateTemplateChildItem {
    param([Item]$targetParent,[Item]$sourceNode)
    $existing = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $sourceNode.Name }
    if ($existing) { return $existing }
    $newChild = New-Item -Path "$($targetParent.Paths.FullPath)/$($sourceNode.Name)" -ItemType $sourceNode.TemplateID
    if ($newChild) {
        Invoke-ItemEditWithRetry -Item $newChild -Operation {
            $newChild["__Display name"] = $sourceNode.DisplayName
        } -OperationName ("Initialize template node '{0}'" -f $newChild.Paths.FullPath)
        $script:phase4Created.Add(@{
            Action     = "Created"
            Type       = "Template Node"
            Name       = $newChild.Name
            SourcePath = $sourceNode.Paths.FullPath
            TargetPath = $newChild.Paths.FullPath
            TargetId   = $newChild.ID.ToString()
        })
    }
    return $newChild
}

function Get-TargetParentForTemplate {
    param([Item]$sourceRoot,[Item]$templateItem,[Item]$targetRoot)
    $ancestors = @()
    $cursor = $templateItem.Parent
    while ($cursor -and $cursor.ID -ne $sourceRoot.ID) {
        $ancestors = ,$cursor + $ancestors
        $cursor = $cursor.Parent
    }
    $currentTarget = $targetRoot
    foreach ($node in $ancestors) {
        $currentTarget = Get-OrCreateTemplateChildItem -targetParent $currentTarget -sourceNode $node
        if (-not $currentTarget) { throw "Failed to ensure target path for $($node.Paths.FullPath)" }
    }
    return $currentTarget
}

function Copy-PageTemplates {
    param([Item[]]$mvcTemplateRoots,[Item]$jssTemplateRoot)

    foreach ($srcRoot in $mvcTemplateRoots) {
        Write-Host "`nProcessing MVC Page Type Templates root: $($srcRoot.Paths.FullPath)"

        $templateItems = if ($srcRoot.TemplateID -eq $pageTemplateId) {
            @($srcRoot)
        } else {
            Get-ChildItem -Path "master:" -ID $srcRoot.ID -Recurse | Where-Object { $_.TemplateID -eq $pageTemplateId }
        }
        if (-not $templateItems -or $templateItems.Count -eq 0) {
            Write-Host "No template items found under: $($srcRoot.Paths.FullPath)"
            continue
        }

        foreach ($tpl in $templateItems) {
            try {
                $targetParent = Get-TargetParentForTemplate -sourceRoot $srcRoot -templateItem $tpl -targetRoot $jssTemplateRoot
                $newItemName = "Headless $($tpl.Name)"
                $targetExists = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $newItemName }

                if ($targetExists) {
                    $pageTemplateIdMap[$tpl.ID.ToString().ToLowerInvariant()] = $targetExists.ID.ToString()
                    Set-TemplateBaseInheritance -templateItem $targetExists -requiredBaseIds $requiredPageTemplateBaseIds
                    Write-Host "Skipped (exists): $($targetParent.Paths.FullPath)/$newItemName"
                } else {
                    $maybeOldCopy = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $tpl.Name }
                    if ($maybeOldCopy) {
                        Rename-Item -Path $maybeOldCopy.Paths.FullPath -NewName $newItemName
                        $copied = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $newItemName }
                    } else {
                        $null = $tpl | Copy-Item -Destination $targetParent.ID -Recurse
                        $copied = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $tpl.Name }
                        if ($copied) {
                            Rename-Item -Path $copied.Paths.FullPath -NewName $newItemName
                            $copied = Get-ChildItem -Path "master:" -ID $targetParent.ID | Where-Object { $_.Name -eq $newItemName }
                        }
                    }
                    if ($copied) {
                        Invoke-ItemEditWithRetry -Item $copied -Operation {
                            $copied["__Display name"] = $tpl.DisplayName
                        } -OperationName ("Initialize page template '{0}'" -f $copied.Paths.FullPath)
                        Set-TemplateBaseInheritance -templateItem $copied -requiredBaseIds $requiredPageTemplateBaseIds
                        $pageTemplateIdMap[$tpl.ID.ToString().ToLowerInvariant()] = $copied.ID.ToString()
                        $script:phase4Created.Add(@{
                            Action     = "Created"
                            Type       = "Page Template"
                            Name       = $copied.Name
                            SourcePath = $tpl.Paths.FullPath
                            TargetPath = $copied.Paths.FullPath
                            TargetId   = $copied.ID.ToString()
                        })
                    } else {
                        Write-Warning "Failed to create or resolve copied item for $($tpl.Paths.FullPath)"
                    }
                }
            } catch {
                Write-Warning "Error copying template $($tpl.Paths.FullPath): $_"
            }
        }
    }
}

function Update-PageTemplateBaseTemplatesFromMap {
    param([hashtable]$map)

    if (-not $map -or $map.Count -eq 0) { return 0 }

    $updatedCount = 0
    $processedTargetIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($srcIdLower in $map.Keys) {
        $tgtIdStr = $map[$srcIdLower]
        if ([string]::IsNullOrWhiteSpace($tgtIdStr)) { continue }
        if (-not $processedTargetIds.Add($tgtIdStr)) { continue }

        try {
            [Sitecore.Data.ID]$targetTemplateId = [Sitecore.Data.ID]::Null
            if (-not [Sitecore.Data.ID]::TryParse($tgtIdStr, [ref]$targetTemplateId)) {
                Write-Warning ("Skipping mapped target template with invalid ID: {0}" -f $tgtIdStr)
                continue
            }

            $targetTemplate = Get-Item -Path "master:" -ID $targetTemplateId -ErrorAction Stop
            if (-not $targetTemplate) { continue }

            $baseRaw = $targetTemplate["__Base template"]
            if ([string]::IsNullOrWhiteSpace($baseRaw)) { continue }

            $baseIds = @($baseRaw -split '\|' | Where-Object { $_ -and $_.Trim().Length -gt 0 })
            if ($baseIds.Count -eq 0) { continue }

            $changed = $false
            $mappedBaseIds = [System.Collections.Generic.List[string]]::new()

            foreach ($baseId in $baseIds) {
                $mapped = Get-MappedIdValue -map $map -sourceId $baseId

                if (-not [string]::IsNullOrWhiteSpace($mapped)) {
                    [Sitecore.Data.ID]$mappedId = [Sitecore.Data.ID]::Null
                    if ([Sitecore.Data.ID]::TryParse($mapped, [ref]$mappedId)) {
                        $mappedBaseIds.Add($mappedId.ToString())
                        $changed = $true
                    } else {
                        [Sitecore.Data.ID]$originalBaseId = [Sitecore.Data.ID]::Null
                        if ([Sitecore.Data.ID]::TryParse($baseId, [ref]$originalBaseId)) {
                            $mappedBaseIds.Add($originalBaseId.ToString())
                        }
                    }
                } else {
                    [Sitecore.Data.ID]$originalBaseId = [Sitecore.Data.ID]::Null
                    if ([Sitecore.Data.ID]::TryParse($baseId, [ref]$originalBaseId)) {
                        $mappedBaseIds.Add($originalBaseId.ToString())
                    }
                }
            }

            if (-not $changed) { continue }

            $seen = @{}
            $uniqueMappedBaseIds = @()
            foreach ($id in $mappedBaseIds) {
                if (-not $seen.ContainsKey($id)) {
                    $seen[$id] = $true
                    $uniqueMappedBaseIds += $id
                }
            }

            $newValue = ($uniqueMappedBaseIds -join "|")
            if ($newValue -eq $baseRaw) { continue }

            Invoke-ItemEditWithRetry -Item $targetTemplate -Operation {
                $targetTemplate["__Base template"] = $newValue
            } -OperationName ("Update __Base template on '{0}'" -f $targetTemplate.Paths.FullPath)

            $updatedCount++
        } catch {
            Write-Warning ("Failed to update __Base template for target template {0}: {1}" -f $tgtIdStr, $_.Exception.Message)
        }
    }

    return $updatedCount
}

# Phase 5: Update __Masters (insert options)
function Update-PageTemplateInsertOptions {
    param([hashtable]$map)

    Write-Host "`nPhase 5: Updating __Masters on headless page templates"

    foreach ($srcIdLower in $map.Keys) {
        $tgtIdStr = $map[$srcIdLower]
        try {
            $srcId       = [Sitecore.Data.ID]$srcIdLower
            $tgtId       = [Sitecore.Data.ID]$tgtIdStr
            $srcTemplate = Get-Item -Path "master:" -ID $srcId
            $tgtTemplate = Get-Item -Path "master:" -ID $tgtId

            if (-not $srcTemplate -or -not $tgtTemplate) {
                Write-Host ("Skip: resolve failed. src:{0} tgt:{1}" -f $srcIdLower, $tgtIdStr)
                continue
            }

            $srcStd = Get-ChildItem -Path "master:" -ID $srcTemplate.ID | Where-Object { $_.Name -eq "__Standard Values" }
            if (-not $srcStd) {
                Write-Host "Source has no __Standard Values. Skipping."
                continue
            }

            $mastersRaw = $srcStd["__Masters"]
            $mastersArray = @()
            if ($mastersRaw) {
                $mastersArray = $mastersRaw -split '\|' | Where-Object { $_ -and $_.Trim().Length -gt 0 }
            }

            $mappedMastersList = New-Object System.Collections.Generic.List[string]
            foreach ($m in $mastersArray) {
                $rawLower = $m.Trim().ToLowerInvariant()
                $norm     = ($m -replace '[\{\}]','').Trim().ToLowerInvariant()
                $withBr   = "{${norm}}"

                $matchedKey = $null
                $targetVal  = $null

                if ($map.ContainsKey($norm)) {
                    $matchedKey = $norm;   $targetVal = $map[$norm]
                } elseif ($map.ContainsKey($withBr)) {
                    $matchedKey = $withBr; $targetVal = $map[$withBr]
                } elseif ($map.ContainsKey($rawLower)) {
                    $matchedKey = $rawLower; $targetVal = $map[$rawLower]
                }

                if ($matchedKey) {
                    $mapped = "{" + ($targetVal -replace '[\{\}]','').ToUpper() + "}"
                    $mappedMastersList.Add($mapped)
                } else {
                    $mappedMastersList.Add($m)
                }
            }

            $seen = @{}
            $uniqueMasters = @()
            foreach ($id in $mappedMastersList) {
                if (-not $seen.ContainsKey($id)) { $seen[$id] = $true; $uniqueMasters += $id }
            }

            $newValue = ($uniqueMasters -join "|")

            $tgtStd = Get-ChildItem -Path "master:" -ID $tgtTemplate.ID | Where-Object { $_.Name -eq "__Standard Values" }
            if (-not $tgtStd) {
                $tgtStd = New-Item -Path $tgtTemplate.Paths.FullPath -Name "__Standard Values" -ItemType $tgtTemplate.ID
                if (-not $tgtStd) { continue }
            }

            $currentValue = $tgtStd["__Masters"]
            if ($currentValue -eq $newValue) {
                continue
            }

            Invoke-ItemEditWithRetry -Item $tgtStd -Operation {
                $tgtStd["__Masters"] = $newValue
            } -OperationName ("Update __Masters on '{0}'" -f $tgtStd.Paths.FullPath)
        } catch {
            Write-Warning ("Failed updating __Masters for key {0}: {1}" -f $srcIdLower, $_.Exception.Message)
        }
    }
}

function Save-MigrationMapsToConfiguration {
    param([Item]$config)

    $renderingMapJson    = $renderingIdMap    | ConvertTo-Json -Depth 10
    $datasourceMapJson   = $datasourceIdMap   | ConvertTo-Json -Depth 10
    $placeholderMapJson  = $placeholderIdMap  | ConvertTo-Json -Depth 10
    $pageTemplateMapJson = $pageTemplateIdMap | ConvertTo-Json -Depth 10

    Invoke-ItemEditWithRetry -Item $config -Operation {
        $config["Rendering Mappings JSON"]          = $renderingMapJson
        $config["Datasource Mapping JSON"]          = $datasourceMapJson
        $config["Placeholder Mappings JSON"]        = $placeholderMapJson
        $config["Page Type Template Mappings JSON"] = $pageTemplateMapJson
    } -OperationName ("Save migration maps to '{0}'" -f $config.Paths.FullPath)
}

function Normalize-PlaceholderSegment {
    param(
        [string]$segment,
        [hashtable]$placeholderMap,
        [hashtable]$dynamicState = $null
    )

    if ([string]::IsNullOrWhiteSpace($segment)) { return $segment }

    if ($segment -match '^(?<base>.+)-\{(?<guid>[0-9A-Fa-f\-]+)\}-(?<index>\d+)$') {
        $base = $matches["base"]
        $guid = $matches["guid"].ToUpper()

        $mapped = $null
        if ($placeholderMap -and $placeholderMap.ContainsKey($segment)) {
            $mapped = $placeholderMap[$segment]
        } elseif ($placeholderMap -and $placeholderMap.ContainsKey($base)) {
            $mapped = $placeholderMap[$base]
        }

        $mappedBase = if ([string]::IsNullOrWhiteSpace($mapped)) { $base } else { $mapped }

        if ($mappedBase -match '^(?<baseNoWildcard>.+)-\{\*\}$') {
            $mappedBase = $matches["baseNoWildcard"]
        }

        if ($dynamicState) {
            $guidKey = ("{0}|{1}" -f $mappedBase.ToLowerInvariant(), $guid)
            if (-not $dynamicState.ContainsKey("IndexByGuid"))     { $dynamicState["IndexByGuid"]     = @{} }
            if (-not $dynamicState.ContainsKey("NextIndexByBase")) { $dynamicState["NextIndexByBase"] = @{} }
            if (-not $dynamicState.ContainsKey("GuidToUid"))       { $dynamicState["GuidToUid"]       = @{} }

            if (-not $dynamicState["IndexByGuid"].ContainsKey($guidKey)) {
                $baseKey = $mappedBase.ToLowerInvariant()
                $next    = if ($dynamicState["NextIndexByBase"].ContainsKey($baseKey)) { [int]$dynamicState["NextIndexByBase"][$baseKey] } else { 0 }
                $dynamicState["IndexByGuid"][$guidKey]     = $next
                $dynamicState["NextIndexByBase"][$baseKey] = $next + 1
                $dynamicState["GuidToUid"][$guid]          = $next
            }

            # Use the sequential GUID-based index so each unique child instance gets a distinct slot.
            $resolvedIndex = [int]$dynamicState["IndexByGuid"][$guidKey]
            return ("{0}-{1}" -f $mappedBase, $resolvedIndex)
        }

        return ("{0}-{1}" -f $mappedBase, $matches["index"])
    }

    if ($segment -match "^(.+?)(-[{(].+)?$") {
        $base   = $matches[1]
        $suffix = $matches[2]
        if ($placeholderMap -and $placeholderMap.ContainsKey($base)) {
            return $placeholderMap[$base] + $suffix
        }
    }

    if ($placeholderMap -and $placeholderMap.ContainsKey($segment)) {
        return $placeholderMap[$segment]
    }

    return $segment
}

function Normalize-PlaceholderPath {
    param(
        [string]$placeholderPath,
        [hashtable]$placeholderMap,
        [hashtable]$dynamicState = $null
    )

    if ([string]::IsNullOrWhiteSpace($placeholderPath)) { return $placeholderPath }

    $hadLeadingSlash = $placeholderPath.StartsWith("/")
    $parts    = $placeholderPath -split "/"
    $newParts = @()

    foreach ($part in $parts) {
        if ($part -eq "") { continue }
        $newParts += (Normalize-PlaceholderSegment -segment $part -placeholderMap $placeholderMap -dynamicState $dynamicState)
    }

    $newPhCore = ($newParts -join "/")
    if ($hadLeadingSlash) { return "/" + $newPhCore }
    return $newPhCore
}

function Get-XmlAttributeValue {
    param(
        [System.Xml.XmlElement]$node,
        [string]$name
    )

    if (-not $node -or [string]::IsNullOrWhiteSpace($name)) { return $null }

    $value = $node.GetAttribute($name)
    if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }

    $sValue = $node.GetAttribute("s:$name")
    if (-not [string]::IsNullOrWhiteSpace($sValue)) { return $sValue }

    $nsValue = $node.GetAttribute($name, "http://www.sitecore.net/xmlconfig/")
    if (-not [string]::IsNullOrWhiteSpace($nsValue)) { return $nsValue }

    return $null
}

function Convert-ToBracedGuidString {
    param([string]$value)

    if ([string]::IsNullOrWhiteSpace($value)) { return $null }

    $trimmed = $value.Trim()
    [Sitecore.Data.ID]$id = [Sitecore.Data.ID]::Null
    if ([Sitecore.Data.ID]::TryParse($trimmed, [ref]$id)) {
        return $id.Guid.ToString("B").ToUpperInvariant()
    }

    $normalized = ($trimmed -replace '[\{\}]', '').Trim()
    if ($normalized -match '^[0-9A-Fa-f\-]{36}$') {
        return ("{{{0}}}" -f $normalized.ToUpperInvariant())
    }

    return $trimmed
}

function New-NormalizedIdLookupMap {
    param([hashtable]$sourceMap)

    $lookup = @{}
    if (-not $sourceMap) { return $lookup }

    foreach ($k in $sourceMap.Keys) {
        $v = $sourceMap[$k]
        $keyBraced = Convert-ToBracedGuidString -value $k
        $valBraced = Convert-ToBracedGuidString -value $v
        if ([string]::IsNullOrWhiteSpace($keyBraced) -or [string]::IsNullOrWhiteSpace($valBraced)) { continue }

        $lookup[$keyBraced] = $valBraced

        $keyRaw = ($keyBraced -replace '[\{\}]', '').ToLowerInvariant()
        $lookup[$keyRaw] = $valBraced
        $lookup["{$keyRaw}"] = $valBraced
    }

    return $lookup
}

function Ensure-PlaceholderKeyMappingItem {
    param(
        [string]$sourceId,
        [string]$targetId,
        [string]$keyValue,
        [hashtable]$existingMap
    )

    $sourceNorm = Convert-ToBracedGuidString -value $sourceId
    $targetNorm = Convert-ToBracedGuidString -value $targetId
    if ([string]::IsNullOrWhiteSpace($sourceNorm) -or [string]::IsNullOrWhiteSpace($targetNorm)) { return $null }
    if ([string]::IsNullOrWhiteSpace($keyValue)) { return $null }

    $keyTrimmed = $keyValue.Trim()
    $dedupeKey = ("{0}|{1}|{2}" -f $sourceNorm.ToLowerInvariant(), $targetNorm.ToLowerInvariant(), $keyTrimmed.ToLowerInvariant())
    if ($existingMap.ContainsKey($dedupeKey)) {
        return $null
    }

    $safeKey = ($keyTrimmed -replace '[^a-zA-Z0-9\-]', '-')
    if ([string]::IsNullOrWhiteSpace($safeKey)) { $safeKey = "nokey" }

    $sourceNameToken = ($sourceNorm -replace '[\{\}]', '').ToLowerInvariant()
    $baseName = "Placeholder-{0}-{1}" -f $safeKey, $sourceNameToken
    $baseName = $baseName -replace '-{2,}', '-'

    $itemName = $baseName
    $suffix = 1
    while (Test-Path -Path ("{0}/{1}" -f $placeholderMappingRootPath, $itemName)) {
        $suffix++
        $itemName = "{0}-{1}" -f $baseName, $suffix
    }

    $mappingItem = New-Item -Path $placeholderMappingRootPath -Name $itemName -ItemType $placeholderKeyMappingTemplateId
    if (-not $mappingItem) { return $null }

    $resolvedSourceFieldName = if ($mappingItem.Fields[$placeholderKeyMappingSourceFieldId]) {
        $placeholderKeyMappingSourceFieldId
    } elseif ($mappingItem.Fields[$placeholderSourceFieldId]) {
        $placeholderSourceFieldId
    } else {
        $placeholderSourceFieldName
    }

    $resolvedTargetFieldName = if ($mappingItem.Fields[$placeholderKeyMappingTargetFieldId]) {
        $placeholderKeyMappingTargetFieldId
    } elseif ($mappingItem.Fields[$placeholderTargetFieldId]) {
        $placeholderTargetFieldId
    } else {
        $placeholderTargetFieldName
    }

    $resolvedKeyFieldName = if ($mappingItem.Fields[$placeholderKeyMappingKeyFieldId]) {
        $placeholderKeyMappingKeyFieldId
    } else {
        $placeholderKeyMappingKeyFieldName
    }

    if (-not $mappingItem.Fields[$resolvedSourceFieldName] -or -not $mappingItem.Fields[$resolvedTargetFieldName] -or -not $mappingItem.Fields[$resolvedKeyFieldName]) {
        throw ("Placeholder Key Mapping template is missing required fields on item '{0}'." -f $mappingItem.Paths.FullPath)
    }

    Invoke-ItemEditWithRetry -Item $mappingItem -Operation {
        $mappingItem[$resolvedSourceFieldName] = $sourceNorm
        $mappingItem[$resolvedTargetFieldName] = $targetNorm
        $mappingItem[$resolvedKeyFieldName] = $keyTrimmed
    } -OperationName ("Update placeholder-key mapping item '{0}'" -f $mappingItem.Paths.FullPath)

    $existingMap[$dedupeKey] = $mappingItem.ID.ToString()
    $script:phase9Created.Add(@{
        Action     = "Created"
        Type       = "Placeholder Key Mapping"
        Name       = $mappingItem.Name
        SourcePath = $sourceNorm
        TargetPath = $mappingItem.Paths.FullPath
        TargetId   = $mappingItem.ID.ToString()
    })

    return $mappingItem
}

# -------------------------
# MAIN (Interactive)
# -------------------------
$config = Get-Item -Path $configurationItemPath
if (-not $config) {
    Write-Error "Configuration item not found: $configurationItemPath"
    exit
}

Write-Host "Using Migration Configuration: $($config.Paths.FullPath)"

Merge-JsonMapInto -json $config["Rendering Mappings JSON"]          -target $renderingIdMap
Merge-JsonMapInto -json $config["Datasource Mapping JSON"]          -target $datasourceIdMap
Merge-JsonMapInto -json $config["Placeholder Mappings JSON"]        -target $placeholderIdMap
Merge-JsonMapInto -json $config["Page Type Template Mappings JSON"] -target $pageTemplateIdMap

# Load Dynamic Placeholder Sample Size from configuration
$defaultDynamicPlaceholderSampleSize = Get-ConfigIntOrDefault -configItem $config -fieldNames @("Dynamic Placeholder Sample Size") -defaultValue 50

$introText = @"
This wizard migrates MVC renderings, placeholders, datasources, and page templates
to Headless SXA format in 10 discrete phases.

After each phase a results dialog shows:
  - a summary of what was created
  - an option to revert that phase before moving on
  - the overall progress bar

Click through the tabs above to read what each phase does, then click Start.
"@

$introParams = @(
    @{ Name = "overview";  Title = "What this wizard does"; Value = $introText; Editor = "info"; Tab = "Overview" }
    @{ Name = "ph1info"; Title = "Phase 1 — Datasource Migration";
       Value = "Copies MVC datasource content roots to the Headless datasource root and builds a source-to-target ID map used by later phases."; Editor = "info"; Tab = "Phase 1" }
    @{ Name = "ph2info"; Title = "Phase 2 — Renderings Migration";
       Value = "Creates JSON rendering items under the Headless rendering root, copies parameters and datasource templates, and updates datasource locations using the Phase 1 map."; Editor = "info"; Tab = "Phase 2" }
    @{ Name = "ph3info"; Title = "Phase 3 — Placeholders Migration";
       Value = "Copies placeholder settings to the Headless placeholders root, adds the headless prefix to each placeholder key, and remaps Allowed Controls to the new rendering IDs."; Editor = "info"; Tab = "Phase 3" }
    @{ Name = "ph4info"; Title = "Phase 4 — Page Templates Migration";
       Value = "Copies MVC page templates to the Headless templates area, renames them to 'Headless <Name>', and injects the required base template inheritance."; Editor = "info"; Tab = "Phase 4" }
    @{ Name = "ph5info"; Title = "Phase 5 — Insert Options (__Masters)";
       Value = "Reads __Masters on source page template Standard Values and remaps the IDs to their headless equivalents on the target Standard Values items."; Editor = "info"; Tab = "Phase 5" }
    @{ Name = "ph6info"; Title = "Phase 6 — Save JSON Maps";
       Value = "Writes all four mapping tables (renderings, datasources, placeholders, page templates) back to the Migration Configuration item as JSON fields for future incremental runs."; Editor = "info"; Tab = "Phase 6" }
     @{ Name = "ph7info"; Title = "Phase 7 — Create Mapping Items";
         Value = "Creates mapping items under Sitecore migration mapping folders using the JSON mappings produced by earlier phases."; Editor = "info"; Tab = "Phase 7" }
         @{ Name = "ph8info"; Title = "Phase 8 — Dynamic Placeholders";
                 Value = "Samples MVC pages by configured page template, detects dynamic placeholder owners from layout XML, enables dynamic-placeholder support on mapped Headless renderings and parameter templates, and updates mapped Headless placeholder setting keys to name-{*} format."; Editor = "info"; Tab = "Phase 8" }
         @{ Name = "ph9info"; Title = "Phase 9 — Standard Values Update";
                    Value = "Reads rendering, layout, and placeholder mapping items, creates placeholder-key mapping items from <p> nodes, removes all <p> nodes, then updates the Renderings and Final Renderings layout XML fields on __Standard Values of each Headless page template."; Editor = "info"; Tab = "Phase 9" }
         @{ Name = "ph10info"; Title = "Phase 10 — Rendering Manifest Export";
                 Value = "Uses data computed by Phase 8 to build and download a rendering-manifest.json file documenting every migrated Headless rendering with its parameters template fields, datasource template fields, and allowed placeholder assignments."; Editor = "info"; Tab = "Phase 10" }
)

$introProps = @{
    Parameters   = $introParams
    Title        = "Headless SXA Migration Wizard"
    Description  = "Review the phases below, then click Start to begin."
    Width        = 1100; Height = 560
    OkButtonName = "Start"
    CancelButtonName = "Cancel"
}

$introResult = Read-Variable @introProps
if ($introResult -ne "ok") {
    Write-Host "Migration canceled before start."
    exit
}

# Resolve configuration values once
$mvcDatasourceRoots = Get-Item -Path ($config["MVC Datasource Root"] -split '\|') | Where-Object { $_ }
$headlessDatasourceRoot = Resolve-ItemFromConfigValue -value $config["Headless Datasource Root"]

$mvcRenderingItems = Get-Item -Path ($config["MVC Renderings"] -split '\|') | Where-Object { $_ }
$headlessRenderingRoot  = Resolve-ItemFromConfigValue -value $config["Headless Rendering Root"]
$headlessTemplatesRoot  = Resolve-ItemFromConfigValue -value $config["Headless Rendering Datasource and Parameters Templates Root"]
$mvcDatasourceConfigurationRoot = Resolve-ItemFromConfigValue -value $config["MVC Datasource Configuration Root"]

$mvcPlaceholderItems = Get-Item -Path ($config["MVC Placeholders"] -split '\|') | Where-Object { $_ }
$headlessPlaceholderRoot  = Resolve-ItemFromConfigValue -value $config["Headless Placeholders Root"]
$headlessPlaceholderPrefix = if ([string]::IsNullOrWhiteSpace($config["Headless Placeholder Prefix"])) {
    "headless"
} else {
    $config["Headless Placeholder Prefix"].Trim()
}

$mvcPageTemplateRoots = Get-Item -Path ($config["MVC Page Type Templates"] -split '\|') | Where-Object { $_ }
$headlessPageTemplateRoot  = Resolve-ItemFromConfigValue -value $config["Headless Page Type Templates Root"]

if (-not $headlessRenderingRoot) {
    Write-Error "Headless Rendering Root is missing or invalid."
    exit
}
if (-not $headlessTemplatesRoot) {
    Write-Error "Headless Rendering Datasource and Parameters Templates Root is missing or invalid."
    exit
}

# Phase 1
Write-Progress -Activity "Phase 1 of 10: Datasource Migration" -Status "Copying datasource roots and building ID map..." -PercentComplete 5
try {
    $before = Get-MapCount -map $datasourceIdMap
    if ($mvcDatasourceRoots -and $headlessDatasourceRoot) {
        Copy-DatasourceRoots-And-BuildMap -mvcRoots $mvcDatasourceRoots -headlessRoot $headlessDatasourceRoot -map $datasourceIdMap
        $after = Get-MapCount -map $datasourceIdMap
        $summary = "Datasource roots copied and ID map built.`nMappings before: $before  |  After: $after  |  New: $($after - $before)"
        Set-PhaseResult -phase "Phase 1" -success $true -summary $summary
    } else {
        $summary = "Phase 1 skipped — MVC Datasource Root or Headless Datasource Root not configured."
        Set-PhaseResult -phase "Phase 1" -success $false -summary $summary
    }
} catch {
    $summary = "Phase 1 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 1" -success $false -summary $summary
}
Write-Progress -Activity "Phase 1 of 10: Datasource Migration" -Completed

$p1Result = Show-PhaseResultDialog `
    -phaseName "Phase 1: Datasource Migration" `
    -phaseNum 1 -totalPhases 10 `
    -success $phaseResults["Phase 1"].Success `
    -summaryText $phaseResults["Phase 1"].Summary `
    -createdItems $script:phase1Created
if ($p1Result -ne "next") { Write-Host "Migration exited after Phase 1."; exit }

# Phase 2
Write-Progress -Activity "Phase 2 of 10: Renderings Migration" -Status "Copying renderings and templates to headless root..." -PercentComplete 18
try {
    $beforeRendering = Get-MapCount -map $renderingIdMap
    $beforeTemplate  = Get-MapCount -map $templateIdMap

    foreach ($mvcRoot in $mvcRenderingItems) {
        Copy-Renderings -sourceItem $mvcRoot -targetParentPath $headlessRenderingRoot.Paths.FullPath -headlessTemplatesRoot $headlessTemplatesRoot
    }
    Update-RenderingDatasourceLocations -map $datasourceIdMap
    Update-DatasourceItemTemplates -datasourceMap $datasourceIdMap -templateMap $templateIdMap

    $afterRendering = Get-MapCount -map $renderingIdMap
    $afterTemplate  = Get-MapCount -map $templateIdMap
    $summary = "Renderings and templates created under the Headless root.`nRendering mappings — Before: $beforeRendering  After: $afterRendering  New: $($afterRendering - $beforeRendering)`nTemplate mappings  — Before: $beforeTemplate   After: $afterTemplate   New: $($afterTemplate - $beforeTemplate)"
    Set-PhaseResult -phase "Phase 2" -success $true -summary $summary
} catch {
    $stackHint = if ($_.ScriptStackTrace) { "`nStack: $($_.ScriptStackTrace)" } else { "" }
    $summary = "Phase 2 failed: $($_.Exception.Message)$stackHint"
    Set-PhaseResult -phase "Phase 2" -success $false -summary $summary
}
Write-Progress -Activity "Phase 2 of 10: Renderings Migration" -Completed

$p2Result = Show-PhaseResultDialog `
    -phaseName "Phase 2: Renderings Migration" `
    -phaseNum 2 -totalPhases 10 `
    -success $phaseResults["Phase 2"].Success `
    -summaryText $phaseResults["Phase 2"].Summary `
    -createdItems $script:phase2Created
if ($p2Result -ne "next") { Write-Host "Migration exited after Phase 2."; exit }

# Phase 3
Write-Progress -Activity "Phase 3 of 10: Placeholders Migration" -Status "Copying placeholder settings and applying prefix..." -PercentComplete 30
try {
    $before = Get-MapCount -map $placeholderIdMap
    if ($mvcPlaceholderItems -and $headlessPlaceholderRoot) {
        Copy-And-Transform-Placeholders -sourceItems $mvcPlaceholderItems -targetRoot $headlessPlaceholderRoot -prefix $headlessPlaceholderPrefix
        $after = Get-MapCount -map $placeholderIdMap
        $summary = "Placeholder roots copied and keys prefixed with '$headlessPlaceholderPrefix-'.`nAllowed Controls remapped to new rendering IDs.`nMappings — Before: $before  After: $after  New: $($after - $before)"
        Set-PhaseResult -phase "Phase 3" -success $true -summary $summary
    } else {
        $summary = "Phase 3 skipped — MVC Placeholders or Headless Placeholders Root not configured."
        Set-PhaseResult -phase "Phase 3" -success $false -summary $summary
    }
} catch {
    $summary = "Phase 3 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 3" -success $false -summary $summary
}
Write-Progress -Activity "Phase 3 of 10: Placeholders Migration" -Completed

$p3Result = Show-PhaseResultDialog `
    -phaseName "Phase 3: Placeholders Migration" `
    -phaseNum 3 -totalPhases 10 `
    -success $phaseResults["Phase 3"].Success `
    -summaryText $phaseResults["Phase 3"].Summary `
    -createdItems $script:phase3Created
if ($p3Result -ne "next") { Write-Host "Migration exited after Phase 3."; exit }

# Phase 4
Write-Progress -Activity "Phase 4 of 10: Page Templates Migration" -Status "Copying and renaming page templates..." -PercentComplete 44
try {
    $before = Get-MapCount -map $pageTemplateIdMap
    if ($mvcPageTemplateRoots -and $headlessPageTemplateRoot) {
        Copy-PageTemplates -mvcTemplateRoots $mvcPageTemplateRoots -jssTemplateRoot $headlessPageTemplateRoot
        $baseTemplateRemapUpdates = Update-PageTemplateBaseTemplatesFromMap -map $pageTemplateIdMap
        $after = Get-MapCount -map $pageTemplateIdMap
        $summary = "Page templates copied and renamed to 'Headless <Name>'.`nBase template inheritance applied during copy, then __Base template references remapped from old IDs to new IDs using pageTemplateIdMap.`nMappings — Before: $before  After: $after  New: $($after - $before)`nUpdated __Base template fields: $baseTemplateRemapUpdates"
        Set-PhaseResult -phase "Phase 4" -success $true -summary $summary
    } else {
        $summary = "Phase 4 skipped — MVC Page Type Templates or Headless Page Type Templates Root not configured."
        Set-PhaseResult -phase "Phase 4" -success $false -summary $summary
    }
} catch {
    $summary = "Phase 4 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 4" -success $false -summary $summary
}
Write-Progress -Activity "Phase 4 of 10: Page Templates Migration" -Completed

$p4Result = Show-PhaseResultDialog `
    -phaseName "Phase 4: Page Templates Migration" `
    -phaseNum 4 -totalPhases 10 `
    -success $phaseResults["Phase 4"].Success `
    -summaryText $phaseResults["Phase 4"].Summary `
    -createdItems $script:phase4Created
if ($p4Result -ne "next") { Write-Host "Migration exited after Phase 4."; exit }

# Phase 5
Write-Progress -Activity "Phase 5 of 10: Insert Options Update" -Status "Remapping Insert Options on headless page template Standard Values..." -PercentComplete 58
try {
    if ($pageTemplateIdMap.Count -gt 0) {
        Update-PageTemplateInsertOptions -map $pageTemplateIdMap
        $summary = "Insert options (__Masters) updated on $($pageTemplateIdMap.Count) headless page template(s).`nSource __Masters IDs were remapped to headless equivalents."
        Set-PhaseResult -phase "Phase 5" -success $true -summary $summary
    } else {
        $summary = "Phase 5 skipped — no page template mappings available (Phase 4 must run first)."
        Set-PhaseResult -phase "Phase 5" -success $false -summary $summary
    }
} catch {
    $summary = "Phase 5 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 5" -success $false -summary $summary
}
Write-Progress -Activity "Phase 5 of 10: Insert Options Update" -Completed

$p5Result = Show-PhaseResultDialog `
    -phaseName "Phase 5: Insert Options Update" `
    -phaseNum 5 -totalPhases 10 `
    -success $phaseResults["Phase 5"].Success `
    -summaryText $phaseResults["Phase 5"].Summary `
    -createdItems $script:phase5Created
if ($p5Result -ne "next") { Write-Host "Migration exited after Phase 5."; exit }

# Phase 6: save maps
Write-Progress -Activity "Phase 6 of 10: Save JSON Maps" -Status "Writing mapping tables to Migration Configuration item..." -PercentComplete 72
try {
    Save-MigrationMapsToConfiguration -config $config
    $summary = "All mapping tables saved to the Migration Configuration item as JSON.`n`nRendering mappings  : $($renderingIdMap.Count)`nDatasource mappings : $($datasourceIdMap.Count)`nPlaceholder mappings: $($placeholderIdMap.Count)`nPage template maps  : $($pageTemplateIdMap.Count)"
    Set-PhaseResult -phase "Phase 6" -success $true -summary $summary
} catch {
    $summary = "Phase 6 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 6" -success $false -summary $summary
}
Write-Progress -Activity "Phase 6 of 10: Save JSON Maps" -Completed

$p6Result = Show-PhaseResultDialog `
    -phaseName "Phase 6: Save JSON Maps" `
    -phaseNum 6 -totalPhases 10 `
    -success $phaseResults["Phase 6"].Success `
    -summaryText $phaseResults["Phase 6"].Summary `
    -createdItems ([System.Collections.Generic.List[hashtable]]::new())
if ($p6Result -ne "next") { Write-Host "Migration exited after Phase 6."; exit }

# Phase 7: create mapping items
Write-Progress -Activity "Phase 7 of 10: Create Mapping Items" -Status "Creating mapping items from mapping json fields..." -PercentComplete 82
try {
    $renderingMappings = Get-MappingFromField -fieldValue $config.Fields["Rendering Mappings JSON"].Value
    $placeholderMappings = Get-MappingFromField -fieldValue $config.Fields["Placeholder Mappings JSON"].Value
    $pageTemplateMappings = Get-MappingFromField -fieldValue $config.Fields["Page Type Template Mappings JSON"].Value

    $createdCount = 0

    foreach ($sourceId in $renderingMappings.Keys) {
        $targetId = $renderingMappings[$sourceId]
        $item = Create-MappingItem -name ("Rendering-{0}" -f $sourceId) -parentPath $renderingMappingRootPath -templateId $renderingMappingTemplateId -sourceId $sourceId -targetId $targetId -sourceFieldId $renderingSourceFieldId -targetFieldId $renderingTargetFieldId -mappingType "Rendering"
        if ($item) { $createdCount++ }
    }

    foreach ($sourceId in $placeholderMappings.Keys) {
        $targetId = $placeholderMappings[$sourceId]
        $item = Create-MappingItem -name ("Placeholder-{0}" -f $sourceId) -parentPath $placeholderMappingRootPath -templateId $placeholderMappingTemplateId -sourceId $sourceId -targetId $targetId -sourceFieldId $placeholderSourceFieldId -targetFieldId $placeholderTargetFieldId -mappingType "Placeholder"
        if ($item) { $createdCount++ }
    }

    foreach ($sourceId in $pageTemplateMappings.Keys) {
        $targetId = $pageTemplateMappings[$sourceId]
        $item = Create-MappingItem -name ("PageTemplate-{0}" -f $sourceId) -parentPath $pageTemplateMappingRootPath -templateId $pageTemplateMappingTemplateId -sourceId $sourceId -targetId $targetId -sourceFieldId $pageTemplateSourceFieldId -targetFieldId $pageTemplateTargetFieldId -mappingType "Page Template"
        if ($item) { $createdCount++ }
    }

    $summary = "Mapping item creation complete.`nCreated this run: $createdCount`nRendering mappings in JSON: $($renderingMappings.Count)`nPlaceholder mappings in JSON: $($placeholderMappings.Count)`nPage template mappings in JSON: $($pageTemplateMappings.Count)"
    Set-PhaseResult -phase "Phase 7" -success $true -summary $summary
} catch {
    $summary = "Phase 7 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 7" -success $false -summary $summary
}
Write-Progress -Activity "Phase 7 of 10: Create Mapping Items" -Completed

$p7Result = Show-PhaseResultDialog `
    -phaseName "Phase 7: Create Mapping Items" `
    -phaseNum 7 -totalPhases 10 `
    -success $phaseResults["Phase 7"].Success `
    -summaryText $phaseResults["Phase 7"].Summary `
    -createdItems $script:phase7Created
if ($p7Result -ne "next") { Write-Host "Migration exited after Phase 7."; exit }

# Phase 8: dynamic placeholders
Write-Progress -Activity "Phase 8 of 10: Dynamic Placeholders" -Status "Sampling MVC pages and applying dynamic placeholder updates..." -PercentComplete 87
try {
    $mvcStartItem = Resolve-ItemFromConfigValue -value $config["MVC Start Item"]
    if (-not $mvcStartItem) {
        throw "Phase 8 requires 'MVC Start Item' to be configured."
    }

    if (-not $mvcPageTemplateRoots -or $mvcPageTemplateRoots.Count -eq 0) {
        throw "Phase 8 requires 'MVC Page Type Templates' to be configured."
    }

    $phase8LanguageIsoCode = Resolve-PrimaryLanguageIsoCode -configItem $config

    $phase8SampleSize = Get-ConfigIntOrDefault -configItem $config -fieldNames @("Dynamic Placeholder Sample Size", "Dynamic Placeholder Samples Per Template", "Phase 8 Sample Size") -defaultValue $defaultDynamicPlaceholderSampleSize

    $phase8Result = Invoke-DynamicPlaceholderPhase `
        -configItem $config `
        -mvcStartItem $mvcStartItem `
        -mvcTemplateConfigItems $mvcPageTemplateRoots `
        -renderingMappings $renderingIdMap `
        -placeholderMappings $placeholderIdMap `
        -headlessPrefix $headlessPlaceholderPrefix `
        -sampleSize $phase8SampleSize `
        -languageIsoCode $phase8LanguageIsoCode

    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("Dynamic placeholder scan completed across sampled MVC pages.")
    $summaryLines.Add(("Primary language for sampling: {0}." -f $phase8Result.LanguageIsoCode))
    $summaryLines.Add(("Sample size per page type: {0}." -f $phase8SampleSize))
    $summaryLines.Add(("Total sampled pages: {0}." -f $phase8Result.SampledPagesCount))
    $summaryLines.Add(("Renderings updated: {0}." -f $phase8Result.UpdatedRenderingsCount))
    $summaryLines.Add(("Parameters templates updated: {0}." -f $phase8Result.UpdatedParameterTemplatesCount))
    $summaryLines.Add(("Placeholder settings updated: {0}." -f $phase8Result.UpdatedPlaceholderSettingsCount))
    $summaryLines.Add(("Rendering Placeholders fields updated: {0}." -f $phase8Result.UpdatedRenderingPlaceholderFieldsCount))
    $summaryLines.Add("")
    $summaryLines.Add("Per-template sampling:")
    foreach ($line in $phase8Result.TemplateSampleSummary) {
        $summaryLines.Add($line)
    }

    if ($phase8Result.RenderingResolutionLog -and $phase8Result.RenderingResolutionLog.Count -gt 0) {
        $summaryLines.Add("")
        $summaryLines.Add("Rendering resolution details:")
        foreach ($line in $phase8Result.RenderingResolutionLog) {
            $summaryLines.Add($line)
        }
    }

    $phase8UpdatedItems = @($script:phase8Created | Sort-Object TargetPath -Unique)
    if ($phase8UpdatedItems.Count -gt 0) {
        $summaryLines.Add("")
        $summaryLines.Add("Updated items:")
        foreach ($entry in $phase8UpdatedItems) {
            $summaryLines.Add(("- {0}: {1}" -f $entry.Type, $entry.TargetPath))
        }
    }

    if (-not $phase8Result.DynamicTemplateResolved) {
        $summaryLines.Add("")
        $summaryLines.Add("Note: IDynamicPlaceholder template was not resolved. Parameter template inheritance updates were skipped.")
    }

    if (-not [string]::IsNullOrWhiteSpace($phase8Result.ManifestJson)) {
        $summaryLines.Add("")
        $summaryLines.Add(("Rendering manifest ready: {0} rendering(s), {1} with placeholder slot(s). Download will be offered in Phase 10." -f $phase8Result.ManifestRenderingCount, $phase8Result.ManifestPlaceholderCount))
        $script:phase8ManifestResult = $phase8Result
    }

    Set-PhaseResult -phase "Phase 8" -success $true -summary ($summaryLines -join "`n")
} catch {
    $summary = "Phase 8 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 8" -success $false -summary $summary
}
Write-Progress -Activity "Phase 8 of 10: Dynamic Placeholders" -Completed

$p8Result = Show-PhaseResultDialog `
    -phaseName "Phase 8: Dynamic Placeholders" `
    -phaseNum 8 -totalPhases 10 `
    -success $phaseResults["Phase 8"].Success `
    -summaryText $phaseResults["Phase 8"].Summary `
    -createdItems $script:phase8Created
if ($p8Result -ne "next") { Write-Host "Migration exited after Phase 8."; exit }

# Phase 9: Standard Values Update
Write-Progress -Activity "Phase 9 of 10: Standard Values Update" -Status "Updating __Standard Values layout XML on Headless page templates..." -PercentComplete 92
try {
    # Load maps from Phase 6 JSON fields (populated by Phase 6, optionally used to create items in Phase 7)
    # This ensures Phase 9 works regardless of whether Phase 7 mapping items exist or were created in this run
    $p9RenderingMap = Get-MappingFromField -fieldValue $config.Fields["Rendering Mappings JSON"].Value
    $pageTemplateMappingsJson = Get-MappingFromField -fieldValue $config.Fields["Page Type Template Mappings JSON"].Value
    $placeholderMappingsJson = Get-MappingFromField -fieldValue $config.Fields["Placeholder Mappings JSON"].Value
    $p9PlaceholderIdLookup = New-NormalizedIdLookupMap -sourceMap $placeholderMappingsJson

    # Convert placeholder ID mappings to key mappings (source key → target key)
    # Layout XML uses placeholder keys, not IDs
    $p9PlaceholderMap = @{}
    if ($placeholderMappingsJson -and $placeholderMappingsJson.Count -gt 0) {
        $placeholderKeyById = @{}
        $allPlaceholderIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($srcPlaceholderId in $placeholderMappingsJson.Keys) {
            [void]$allPlaceholderIds.Add((Convert-ToBracedGuidString -value $srcPlaceholderId))
            [void]$allPlaceholderIds.Add((Convert-ToBracedGuidString -value $placeholderMappingsJson[$srcPlaceholderId]))
        }

        foreach ($placeholderId in $allPlaceholderIds) {
            if ([string]::IsNullOrWhiteSpace($placeholderId)) { continue }
            $item = Get-Item -Path "master:" -ID $placeholderId -ErrorAction SilentlyContinue
            if ($item) {
                $placeholderKeyById[$placeholderId] = $item.Fields["Placeholder Key"].Value
            }
        }

        foreach ($srcPlaceholderId in $placeholderMappingsJson.Keys) {
            $srcIdNorm = Convert-ToBracedGuidString -value $srcPlaceholderId
            $tgtIdNorm = Convert-ToBracedGuidString -value $placeholderMappingsJson[$srcPlaceholderId]
            if ([string]::IsNullOrWhiteSpace($srcIdNorm) -or [string]::IsNullOrWhiteSpace($tgtIdNorm)) { continue }

            $srcKey = $placeholderKeyById[$srcIdNorm]
            $tgtKey = $placeholderKeyById[$tgtIdNorm]
            if ($srcKey -and $tgtKey) { $p9PlaceholderMap[$srcKey] = $tgtKey }
        }
    }

    # Load layout mappings from mapping items (optional, as they're not stored in JSON from earlier phases)
    $p9LayoutMap = @{}
    foreach ($m in (Get-ChildItem -Path $layoutMappingRootPath -Recurse | Where-Object { $_.TemplateID -eq $layoutMappingTemplateId })) {
        $src = $m.Fields[$layoutSourceFieldId].Value; $tgt = $m.Fields[$layoutTargetFieldId].Value
        if ($src -and $tgt) { $p9LayoutMap[$src] = $tgt }
    }

    # Convert page template map keys/values to uppercase for ID matching
    $p9PageTemplateMap = @{}
    if ($pageTemplateMappingsJson -and $pageTemplateMappingsJson.Count -gt 0) {
        foreach ($src in $pageTemplateMappingsJson.Keys) {
            $tgt = $pageTemplateMappingsJson[$src]
            $p9PageTemplateMap[$src.ToUpper()] = $tgt.ToUpper()
        }
    }

    # Build a dedupe index from existing Placeholder Key Mapping items.
    $placeholderKeyMappingIndex = @{}
    foreach ($existing in (Get-ChildItem -Path $placeholderMappingRootPath -Recurse | Where-Object { $_.TemplateID -eq $placeholderKeyMappingTemplateId })) {
        $existingSourceRaw = if ($existing.Fields[$placeholderKeyMappingSourceFieldId]) {
            $existing.Fields[$placeholderKeyMappingSourceFieldId].Value
        } elseif ($existing.Fields[$placeholderSourceFieldId]) {
            $existing.Fields[$placeholderSourceFieldId].Value
        } else {
            $existing[$placeholderSourceFieldName]
        }

        $existingTargetRaw = if ($existing.Fields[$placeholderKeyMappingTargetFieldId]) {
            $existing.Fields[$placeholderKeyMappingTargetFieldId].Value
        } elseif ($existing.Fields[$placeholderTargetFieldId]) {
            $existing.Fields[$placeholderTargetFieldId].Value
        } else {
            $existing[$placeholderTargetFieldName]
        }

        $existingKey = if ($existing.Fields[$placeholderKeyMappingKeyFieldId]) {
            $existing.Fields[$placeholderKeyMappingKeyFieldId].Value
        } else {
            $existing[$placeholderKeyMappingKeyFieldName]
        }

        $existingSource = Convert-ToBracedGuidString -value $existingSourceRaw
        $existingTarget = Convert-ToBracedGuidString -value $existingTargetRaw
        if ([string]::IsNullOrWhiteSpace($existingSource) -or [string]::IsNullOrWhiteSpace($existingTarget) -or [string]::IsNullOrWhiteSpace($existingKey)) { continue }
        $indexKey = ("{0}|{1}|{2}" -f $existingSource.ToLowerInvariant(), $existingTarget.ToLowerInvariant(), $existingKey.Trim().ToLowerInvariant())
        $placeholderKeyMappingIndex[$indexKey] = $existing.ID.ToString()
    }

    $createdPlaceholderKeyMappings = 0
    $existingPlaceholderKeyMappings = 0
    $missingPlaceholderMdMappings = 0
    $removedPTagsCount = 0

    $updated = 0
    foreach ($targetTplId in ($p9PageTemplateMap.Values | Select-Object -Unique)) {
        try {
            $tplItem = Get-Item -Path "master:" -ID $targetTplId -ErrorAction SilentlyContinue
            if (-not $tplItem) { Write-Warning ("⚠️ Target template not found: {0}" -f $targetTplId); continue }

            $std = $tplItem.Children | Where-Object { $_.Name -eq "__Standard Values" } | Select-Object -First 1
            if (-not $std) {
                Write-Host ("ℹ️ No __Standard Values under {0}" -f $tplItem.Paths.FullPath)
                continue
            }

            $tplChanged = $false

            # Only update shared/final fields if the source field has a value
            $sharedFieldValue = $std.Fields[$renderingsFieldId].Value
            $finalFieldValue = $std.Fields[$finalRenderingsFieldId].Value

            foreach ($fid in @($renderingsFieldId, $finalRenderingsFieldId)) {
                $fieldValue = if ($fid -eq $renderingsFieldId) { $sharedFieldValue } else { $finalFieldValue }
                if ([string]::IsNullOrWhiteSpace($fieldValue)) { continue }
                try {
                    $xmlDoc = New-Object System.Xml.XmlDocument
                    $xmlDoc.PreserveWhitespace = $true
                    $xmlDoc.LoadXml($fieldValue)
                    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
                    if (-not $nsmgr.HasNamespace("s")) { $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/") }
                    $fieldChanged = $false

                    foreach ($d in $xmlDoc.SelectNodes("//d", $nsmgr)) {
                        $la = $d.Attributes["l"]
                        if ($la -and $p9LayoutMap.ContainsKey($la.Value)) { $la.Value = $p9LayoutMap[$la.Value]; $fieldChanged = $true }
                    }

                    # Collect mapping data from <p> nodes, then remove all of them.
                    $pNodes = @($xmlDoc.SelectNodes("//*[local-name()='p']"))
                    $pNodesProcessedInField = $pNodes.Count
                    $pMappingsCreatedInField = 0
                    $pMappingsExistingInField = 0
                    $pMappingsMissingInField = 0
                    $pRemovedInField = 0

                    foreach ($pNode in $pNodes) {
                        $keyFromTag = Get-XmlAttributeValue -node $pNode -name "key"
                        $mdFromTag = Get-XmlAttributeValue -node $pNode -name "md"

                        if (-not [string]::IsNullOrWhiteSpace($keyFromTag) -and -not [string]::IsNullOrWhiteSpace($mdFromTag)) {
                            $mappedPlaceholderTargetId = $null
                            $mdNorm = Convert-ToBracedGuidString -value $mdFromTag
                            if (-not [string]::IsNullOrWhiteSpace($mdNorm)) {
                                $mdRaw = ($mdNorm -replace '[\{\}]', '').ToLowerInvariant()
                                foreach ($candidateKey in @($mdNorm, $mdRaw, "{$mdRaw}")) {
                                    if ($p9PlaceholderIdLookup.ContainsKey($candidateKey)) {
                                        $mappedPlaceholderTargetId = $p9PlaceholderIdLookup[$candidateKey]
                                        break
                                    }
                                }
                            }
                            if (-not [string]::IsNullOrWhiteSpace($mappedPlaceholderTargetId)) {
                                $createdMapping = Ensure-PlaceholderKeyMappingItem `
                                    -sourceId $mdFromTag `
                                    -targetId $mappedPlaceholderTargetId `
                                    -keyValue $keyFromTag `
                                    -existingMap $placeholderKeyMappingIndex
                                if ($createdMapping) {
                                    $createdPlaceholderKeyMappings++
                                    $pMappingsCreatedInField++
                                } else {
                                    $existingPlaceholderKeyMappings++
                                    $pMappingsExistingInField++
                                }
                            } else {
                                $missingPlaceholderMdMappings++
                                $pMappingsMissingInField++
                            }
                        }

                        if ($pNode.ParentNode) {
                            $pNode.ParentNode.RemoveChild($pNode) | Out-Null
                            $removedPTagsCount++
                            $pRemovedInField++
                            $fieldChanged = $true
                        }
                    }

                    if ($pNodesProcessedInField -gt 0) {
                        Write-Host ("[Phase 9] {0} | Field {1}: <p> found={2}, created={3}, existing={4}, missing-md-map={5}, removed={6}" -f $std.Paths.FullPath, $fid, $pNodesProcessedInField, $pMappingsCreatedInField, $pMappingsExistingInField, $pMappingsMissingInField, $pRemovedInField)
                    }

                    foreach ($node in $xmlDoc.SelectNodes("//*[@s:id or @id]", $nsmgr)) {
                        if ($node.HasAttribute("s:id")) {
                            $old = $node.GetAttribute("s:id")
                            if ($p9RenderingMap.ContainsKey($old)) { $node.SetAttribute("s:id", $p9RenderingMap[$old]); $fieldChanged = $true }
                        }
                        if ($node.HasAttribute("id")) {
                            $old = $node.GetAttribute("id")
                            if ($p9RenderingMap.ContainsKey($old)) { $node.SetAttribute("id", $p9RenderingMap[$old]); $fieldChanged = $true }
                        }
                    }

                    # Replace ds / s:ds (datasource references on rendering nodes).
                    # Handles both plain "ds" and namespace-prefixed "s:ds" attributes.
                    foreach ($node in $xmlDoc.SelectNodes('//*[@s:ds or @ds]', $nsmgr)) {
                        $attrName = if ($node.HasAttribute("s:ds")) { "s:ds" } else { "ds" }
                        $dsId     = $node.GetAttribute($attrName)
                        if ([string]::IsNullOrWhiteSpace($dsId)) { continue }
                        $newDsId   = $null
                        $mapSource = $null
                        if      ($p9RenderingMap.ContainsKey($dsId))  { $newDsId = $p9RenderingMap[$dsId];  $mapSource = "rendering map" }
                        elseif  ($datasourceIdMap.ContainsKey($dsId)) { $newDsId = $datasourceIdMap[$dsId]; $mapSource = "datasource map" }
                        if ($newDsId) {
                            $node.SetAttribute($attrName, $newDsId)
                            Write-Host ("🔄 {0} replaced via {1} on {2}: {3} → {4}" -f $attrName, $mapSource, $std.Paths.FullPath, $dsId, $newDsId)
                            $fieldChanged = $true
                        } else {
                            Write-Warning ("⚠️ {0} ID not found in any map on {1}: {2}" -f $attrName, $std.Paths.FullPath, $dsId)
                        }
                    }

                    if ($p9PlaceholderMap.Count -gt 0) {
                        $dynState = @{ IndexByGuid = @{}; NextIndexByBase = @{}; GuidToUid = @{} }
                        foreach ($node in $xmlDoc.SelectNodes('//*[@s:ph or @ph]', $nsmgr)) {
                            $attrName = if ($node.HasAttribute("s:ph")) { "s:ph" } else { "ph" }
                            $oldPh    = $node.GetAttribute($attrName)
                            if ([string]::IsNullOrWhiteSpace($oldPh)) { continue }
                            $newPh = Normalize-PlaceholderPath -placeholderPath $oldPh -placeholderMap $p9PlaceholderMap -dynamicState $dynState
                            if ($newPh -ne $oldPh) { $node.SetAttribute($attrName, $newPh); $fieldChanged = $true }
                        }

                        if ($dynState["GuidToUid"].Count -gt 0) {
                            foreach ($rNode in $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)) {
                                $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                                if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                                $uidUpper = $uid.ToUpper()
                                if (-not $dynState["GuidToUid"].ContainsKey($uidUpper)) { continue }
                                $dynId = [int]$dynState["GuidToUid"][$uidUpper]
                                $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                                $currentPar  = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }
                                $nvc = [System.Collections.Specialized.NameValueCollection]::new()
                                if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                                    $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                                    foreach ($k in $parsed.AllKeys) {
                                        if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                                    }
                                }
                                if ($nvc["DynamicPlaceholderId"] -eq [string]$dynId) { continue }
                                $nvc["DynamicPlaceholderId"] = [string]$dynId
                                $pairs = [System.Collections.Generic.List[string]]::new()
                                foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                                    $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
                                }
                                $rNode.SetAttribute($parAttrName, $pairs -join "&")
                                $fieldChanged = $true
                            }
                        }
                    }

                    # Strip personalization / page-test rules (<rls> elements)
                    $rlsNodes = $xmlDoc.SelectNodes("//rls")
                    foreach ($rls in $rlsNodes) {
                        $rls.ParentNode.RemoveChild($rls) | Out-Null
                        $fieldChanged = $true
                    }
                    if ($rlsNodes.Count -gt 0) {
                        Write-Host ("🧹 Removed {0} <rls> node(s) from {1}" -f $rlsNodes.Count, $std.Paths.FullPath)
                    }

                    # Strip s:pt (page test / content test) attributes from rendering references
                    $ptNodes = $xmlDoc.SelectNodes('//*[@s:pt]', $nsmgr)
                    foreach ($node in $ptNodes) {
                        $node.RemoveAttribute("s:pt")
                        $fieldChanged = $true
                    }
                    if ($ptNodes.Count -gt 0) {
                        Write-Host ("🧹 Removed s:pt (page test) attribute from {0} rendering(s) on {1}" -f $ptNodes.Count, $std.Paths.FullPath)
                    }

                    if ($fieldChanged) {
                        $updatedXml = $xmlDoc.OuterXml
                        Invoke-WithDeadlockRetry -Operation {
                            $stdForEdit = Get-Item -Path "master:" -ID $std.ID -ErrorAction Stop
                            [void]$stdForEdit.Editing.BeginEdit()
                            try {
                                $stdForEdit.Fields[$fid].Value = $updatedXml
                                [void]$stdForEdit.Editing.EndEdit()
                            } catch {
                                if ($stdForEdit.Editing.IsEditing) { [void]$stdForEdit.Editing.CancelEdit() }
                                throw
                            }
                        } -OperationName ("Update field [{0}] on '{1}'" -f $fid, $std.Paths.FullPath) -MaxAttempts 5 -InitialDelayMs 200

                        $tplChanged = $true
                        Write-Host ("✅ Field [{0}] updated on {1}" -f $fid, $std.Paths.FullPath)
                    }
                } catch {
                    Write-Warning ("❌ Field transform/save failed for field {0} on {1}: {2}" -f $fid, $std.Paths.FullPath, $_.Exception.Message)
                }
            }
            if ($tplChanged) {
                $updated++
            } else {
                Write-Host ("ℹ️ No changes needed for {0}" -f $tplItem.Paths.FullPath)
            }
        } catch {
            Write-Warning ("❌ Failed updating Standard Values for template {0}: {1}" -f $targetTplId, $_.Exception.Message)
        }
    }

    $summary = "Standard Values layout XML updated.`nTemplates updated: $updated`nPlaceholder Key Mapping items created: $createdPlaceholderKeyMappings`nPlaceholder Key Mapping items already existed: $existingPlaceholderKeyMappings`n<p> tags with missing Placeholder Mappings JSON md lookup: $missingPlaceholderMdMappings`n<p> tags removed from layout fields: $removedPTagsCount`nPage template mappings loaded: $($p9PageTemplateMap.Count)`nRendering mappings loaded: $($p9RenderingMap.Count)`nLayout mappings loaded: $($p9LayoutMap.Count)`nPlaceholder key mappings loaded: $($p9PlaceholderMap.Count)`nDatasource mappings available: $($datasourceIdMap.Count)"
    Set-PhaseResult -phase "Phase 9" -success $true -summary $summary
} catch {
    $summary = "Phase 9 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 9" -success $false -summary $summary
}
Write-Progress -Activity "Phase 9 of 10: Standard Values Update" -Completed

$p9Result = Show-PhaseResultDialog `
    -phaseName "Phase 9: Standard Values Update" `
    -phaseNum 9 -totalPhases 10 `
    -success $phaseResults["Phase 9"].Success `
    -summaryText $phaseResults["Phase 9"].Summary `
    -createdItems $script:phase9Created
if ($p9Result -ne "next") { Write-Host "Migration exited after Phase 9."; exit }

# Phase 10: Rendering Manifest Export
Write-Progress -Activity "Phase 10 of 10: Rendering Manifest Export" -Status "Generating and downloading rendering manifest JSON..." -PercentComplete 98
try {
    if ($script:phase8ManifestResult -and -not [string]::IsNullOrWhiteSpace($script:phase8ManifestResult.ManifestJson)) {
        $manifestBytes  = [System.Text.Encoding]::UTF8.GetBytes($script:phase8ManifestResult.ManifestJson)
        $manifestStream = [System.IO.MemoryStream]::new([byte[]]$manifestBytes)
        Out-Download -InputObject $manifestStream -Name "rendering-manifest.json" -ContentType "application/json"
        $summary = "Rendering manifest downloaded successfully.`nRenderings: $($script:phase8ManifestResult.ManifestRenderingCount)`nRenderings with placeholder slots: $($script:phase8ManifestResult.ManifestPlaceholderCount)"
        Set-PhaseResult -phase "Phase 10" -success $true -summary $summary
    } else {
        $summary = "Phase 10 skipped — no manifest data available. Phase 8 must run successfully first."
        Set-PhaseResult -phase "Phase 10" -success $false -summary $summary
    }
} catch {
    $summary = "Phase 10 failed: $($_.Exception.Message)"
    Set-PhaseResult -phase "Phase 10" -success $false -summary $summary
}
Write-Progress -Activity "Phase 10 of 10: Rendering Manifest Export" -Completed

$p10Result = Show-PhaseResultDialog `
    -phaseName "Phase 10: Rendering Manifest Export" `
    -phaseNum 10 -totalPhases 10 `
    -success $phaseResults["Phase 10"].Success `
    -summaryText $phaseResults["Phase 10"].Summary `
    -createdItems $script:phase10Created
if ($p10Result -ne "next") { Write-Host "Migration exited after Phase 10."; exit }

$finalLines = @()
foreach ($phaseName in $phaseResults.Keys) {
    $entry  = $phaseResults[$phaseName]
    $status = if ($entry.Success) { "✔ SUCCESS" } else { "✘ SKIPPED / FAILED" }
    $finalLines += ("- {0}: {1}" -f $phaseName, $status)
}
$finalSummary = @"
Phase outcomes:

$($finalLines -join "`n")
"@

$finalResult = Show-PhaseResultDialog `
    -phaseName "Migration Complete" `
    -phaseNum 10 -totalPhases 10 `
    -success $phaseResults["Phase 10"].Success `
    -summaryText $finalSummary `
    -createdItems ([System.Collections.Generic.List[hashtable]]::new()) `
    -isFinal $true

if ($finalResult -eq "revert") {
    Write-Host "Migration reverted and exited from final dialog."
    exit
}

Write-Host "Interactive migration finished."
