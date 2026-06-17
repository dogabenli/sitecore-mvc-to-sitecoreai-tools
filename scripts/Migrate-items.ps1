# Define parameters and make them interactive
$scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$sourceRootPath = ""
$targetRootPath = ""
$renderingMappingRootPath = "/sitecore/system/Settings/Migration/Mappings/Rendering Mappings"
$layoutMappingRootPath    = "/sitecore/system/Settings/Migration/Mappings/Layout Mappings"
$detailedLogging = $false

$props = @{
    Parameters = @(
        @{ Name = "sourceRootPath"; Title = "Select Source Item"; Tooltip = "Choose the source root item"; Root = "/sitecore/content/"; Editor = "item" },
        @{ Name = "targetRootPath"; Title = "Select Target Item"; Tooltip = "Choose the target root item"; Root = "/sitecore/content/"; Editor = "item" },
        @{ Name = "includeChildren"; Title = "Include Children?"; Tooltip = "Check to include all descendants"; Value = $false; Editor = "checkbox" }
    )
    Title = "Select Source and Target Items"
    Description = "Please select the source and target root items from the content tree."
    Width = 700
    Height = 600
}
if (-not (Read-Variable @props)) { Exit }

$warningTotals = @{}
$warningSeenByCategory = @{}
$sectionDurations = [ordered]@{}

function Write-Log {
    param(
        [string]$Message,
        [switch]$Detailed
    )

    if ($Detailed -and -not $detailedLogging) { return }
    Write-Host $Message
}

function Start-SectionTimer {
    param([string]$Name)

    return [pscustomobject]@{
        Name = $Name
        Timer = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Stop-SectionTimer {
    param($Section)

    if (-not $Section -or -not $Section.Timer) { return }
    $Section.Timer.Stop()
    $sectionDurations[$Section.Name] = $Section.Timer.Elapsed
    Write-Log ("⏱️ Section '{0}' duration: {1:hh\:mm\:ss}" -f $Section.Name, $Section.Timer.Elapsed)
}

function Write-DedupedWarning {
    param(
        [string]$Category,
        [string]$Key,
        [string]$Message
    )

    if (-not $warningTotals.ContainsKey($Category)) {
        $warningTotals[$Category] = 0
        $warningSeenByCategory[$Category] = @{}
    }

    $warningTotals[$Category]++
    $normalizedKey = if ([string]::IsNullOrWhiteSpace($Key)) { "<EMPTY>" } else { $Key.ToUpperInvariant() }

    if (-not $warningSeenByCategory[$Category].ContainsKey($normalizedKey)) {
        $warningSeenByCategory[$Category][$normalizedKey] = 1
        Write-Warning $Message
    } else {
        $warningSeenByCategory[$Category][$normalizedKey]++
    }
}

# Field IDs
$renderingsFieldId       = "{F1A1FE9E-A60C-4DDB-A3A0-BB5B29FE732E}"
$finalRenderingsFieldId  = "{04BF00DB-F5FB-41F7-8AB7-22408372A981}"
$sourceFieldId           = "{AF375DB4-D362-4886-B551-111AE9DDFD2D}"
$targetFieldId           = "{6E311F1C-87E1-41FE-A69A-C4A064B3F92F}"
$layoutSourceFieldId     = "{8560BA59-6006-4C1C-8280-D4FEDBBD1C08}"
$layoutTargetFieldId     = "{226DC703-6995-4FDF-B69B-78AE689C19DA}"

$placeholderMappingRootPath = "/sitecore/system/Settings/Migration/Mappings/Placeholder Mappings"
$placeholderSourceFieldId   = "{CCB522D4-0862-4348-81BB-12CBBD293036}"
$placeholderTargetFieldId   = "{B60C925B-9CF8-4A3A-8D86-82B90546D10B}"

# Placeholder Key Migration Map constants
$placeholderKeyMigrationTemplateId = "{55281BC0-F06B-49E0-87D0-6B6594A261CA}"
$placeholderKeySourceFieldId       = "{D53FA402-33E7-4219-9A24-2078FE173F62}"
$placeholderKeyTargetFieldId       = "{DC84EA35-942E-4BFC-8DF4-F79E90AAF7D0}"
$placeholderKeyFieldId             = "{F0251DE5-611B-4D82-9E74-E75D9C63A138}"

# NEW: Page Template Mapping constants
$pageTemplateMappingRootPath   = "/sitecore/system/Settings/Migration/Mappings/Page Template Mappings"
$pageTemplateMappingTemplateId = "{5C9897BB-FDAC-418F-8044-4BB1FCCC41FB}"
$pageTemplateSourceFieldId     = "{C48EFCEE-F8DF-47EA-A5A3-4670B1E3356A}"
$pageTemplateTargetFieldId     = "{2BF34BA0-B6FB-4DBF-A856-9F2C821896DA}"

$migrationConfigPath = "/sitecore/system/Settings/Migration/Migration Configuration"
$migrationConfig = Get-Item -Path $migrationConfigPath
if (-not $migrationConfig) {
    throw "Migration Configuration item not found at $migrationConfigPath"
}

$localDataSourceTemplateId = $migrationConfig.Fields["Local Data Source Template"].Value
if ([string]::IsNullOrWhiteSpace($localDataSourceTemplateId)) {
    Write-Warning "Local Data Source Template is empty. Falling back to name 'Data'."
    $useNameFallback = $true
} else {
    $dataFolderTemplateItem = Get-Item -Path "master:" -ID $localDataSourceTemplateId
    if (-not $dataFolderTemplateItem) {
        Write-Warning "Could not resolve Local Data Source Template by ID $localDataSourceTemplateId. Falling back to name 'Data'."
        $useNameFallback = $true
    } else {
        $dataFolderTemplateGuidB = $dataFolderTemplateItem.ID.Guid.ToString("B").ToUpper()
        $useNameFallback = $false
        Write-Host "✅ Using Local Data Source Template: $($dataFolderTemplateItem.Paths.FullPath) [$dataFolderTemplateGuidB]"
    }
}

# Global Datasource ID Map (from Phase 1, saved by Phase 6)
$globalDsIdMap = @{}
$globalDsJson = $migrationConfig.Fields["Datasource Mapping JSON"].Value
if (-not [string]::IsNullOrWhiteSpace($globalDsJson)) {
    try {
        $parsed = $globalDsJson | ConvertFrom-Json
        $parsed.PSObject.Properties | ForEach-Object { $globalDsIdMap[$_.Name] = $_.Value }
        Write-Host "✅ Loaded $($globalDsIdMap.Count) global datasource mapping(s) from Migration Configuration."
    } catch {
        Write-Warning "⚠️ Failed to parse Datasource Mapping JSON: $_"
    }
} else {
    Write-Host "ℹ️ No Datasource Mapping JSON found on Migration Configuration — global datasource remapping skipped."
}

# Rendering Migration Map
$renderingMap = @{}
$renderingMappingItems = Get-ChildItem -Path $renderingMappingRootPath -Recurse | Where-Object {
    $_.TemplateID -eq "{627EE9FF-F63B-441C-93D6-0A69FB623BBB}"
}
foreach ($map in $renderingMappingItems) {
    $source = $map.Fields[$sourceFieldId].Value
    $target = $map.Fields[$targetFieldId].Value
    if ($source -and $target) { $renderingMap[$source] = $target }
}

function Resolve-ItemFromReferenceValue {
    param([string]$referenceValue)

    if ([string]::IsNullOrWhiteSpace($referenceValue)) { return $null }

    $trimmed = $referenceValue.Trim()
    $trimmed = $trimmed -replace '^master:\s*', ''

    [Sitecore.Data.ID]$parsedId = [Sitecore.Data.ID]::Null
    if ([Sitecore.Data.ID]::TryParse($trimmed, [ref]$parsedId)) {
        return Get-Item -Path "master:" -ID $parsedId -ErrorAction SilentlyContinue
    }

    if ($trimmed.StartsWith("/")) {
        return Get-Item -Path $trimmed -ErrorAction SilentlyContinue
    }

    return $null
}

# Datasource Template Map (derived from mapped rendering items)
$datasourceTemplateMap = @{}
foreach ($sourceRenderingId in $renderingMap.Keys) {
    $targetRenderingId = $renderingMap[$sourceRenderingId]

    $sourceRenderingItem = Get-Item -Path "master:" -ID $sourceRenderingId -ErrorAction SilentlyContinue
    $targetRenderingItem = Get-Item -Path "master:" -ID $targetRenderingId -ErrorAction SilentlyContinue
    if (-not $sourceRenderingItem -or -not $targetRenderingItem) { continue }

    $sourceDsTemplateItem = Resolve-ItemFromReferenceValue -referenceValue $sourceRenderingItem["Datasource Template"]
    $targetDsTemplateItem = Resolve-ItemFromReferenceValue -referenceValue $targetRenderingItem["Datasource Template"]
    if (-not $sourceDsTemplateItem -or -not $targetDsTemplateItem) { continue }

    $sourceTemplateId = $sourceDsTemplateItem.ID.Guid.ToString("B").ToUpper()
    $targetTemplateId = $targetDsTemplateItem.ID.Guid.ToString("B").ToUpper()

    if ($datasourceTemplateMap.ContainsKey($sourceTemplateId) -and $datasourceTemplateMap[$sourceTemplateId] -ne $targetTemplateId) {
        Write-Warning "⚠️ Conflicting datasource template mapping for $sourceTemplateId. Existing: $($datasourceTemplateMap[$sourceTemplateId]); New: $targetTemplateId"
        continue
    }

    $datasourceTemplateMap[$sourceTemplateId] = $targetTemplateId
}
Write-Host "✅ Derived $($datasourceTemplateMap.Count) datasource template mapping(s) from rendering mappings."

# Layout Migration Map
$layoutMap = @{}
$layoutMappingItems = Get-ChildItem -Path $layoutMappingRootPath -Recurse | Where-Object {
    $_.TemplateID -eq "{E75AB56F-5171-4064-98DC-2D856BF2668D}"
}
foreach ($map in $layoutMappingItems) {
    $source = $map.Fields[$layoutSourceFieldId].Value
    $target = $map.Fields[$layoutTargetFieldId].Value
    if ($source -and $target) { $layoutMap[$source] = $target }
}

# Placeholder Migration Map
$placeholderMap = @{}
$placeholderMappingItems = Get-ChildItem -Path $placeholderMappingRootPath -Recurse | Where-Object {
    $_.TemplateID -eq "{13BFDC26-3A55-4E54-BBD4-C4813DA119D2}"
}
foreach ($map in $placeholderMappingItems) {
    $sourceItem = Get-Item -Path "master:" -ID $map.Fields[$placeholderSourceFieldId].Value
    $targetItem = Get-Item -Path "master:" -ID $map.Fields[$placeholderTargetFieldId].Value
    if ($sourceItem -and $targetItem) {
        $sourceKey = $sourceItem.Fields["Placeholder Key"].Value
        $targetKey = $targetItem.Fields["Placeholder Key"].Value
        if ($sourceKey -and $targetKey) {
            $placeholderMap[$sourceKey] = $targetKey
            Write-Host "📌 Placeholder key mapping added: $sourceKey → $targetKey"
        } else {
            Write-Warning "⚠️ Missing 'Placeholder Key' on source or target item for mapping: $($map.Paths.FullPath)"
        }
    } else {
        Write-Warning "⚠️ Could not resolve source or target placeholder item by ID in mapping: $($map.Paths.FullPath)"
    }
}

# Placeholder Key Migration Map (new format with Key field and Target Placeholder Key)
$placeholderKeyMappingItems = Get-ChildItem -Path $placeholderMappingRootPath -Recurse | Where-Object {
    $_.TemplateID -eq $placeholderKeyMigrationTemplateId
}
foreach ($map in $placeholderKeyMappingItems) {
    $sourceKey = $map.Fields[$placeholderKeyFieldId].Value
    $targetItemId = $map.Fields[$placeholderKeyTargetFieldId].Value
    if ([string]::IsNullOrWhiteSpace($sourceKey) -or [string]::IsNullOrWhiteSpace($targetItemId)) { continue }
    
    $targetItem = Get-Item -Path "master:" -ID $targetItemId -ErrorAction SilentlyContinue
    if (-not $targetItem) {
        Write-Warning "⚠️ Could not resolve target placeholder item by ID in Placeholder Key Migration Map: $($map.Paths.FullPath)"
        continue
    }
    
    $targetKey = $targetItem.Fields["Placeholder Key"].Value
    if ([string]::IsNullOrWhiteSpace($targetKey)) {
        Write-Warning "⚠️ Missing 'Placeholder Key' on target item in Placeholder Key Migration Map: $($targetItem.Paths.FullPath)"
        continue
    }
    
    $placeholderMap[$sourceKey] = $targetKey
    Write-Host "📌 Placeholder key migration mapping added: $sourceKey → $targetKey"
}

# NEW: Page Template Map (source template ID → target template ID)
$pageTemplateMap = @{}
$pageTemplateMappingItems = Get-ChildItem -Path $pageTemplateMappingRootPath -Recurse | Where-Object {
    $_.TemplateID -eq $pageTemplateMappingTemplateId
}
foreach ($map in $pageTemplateMappingItems) {
    $source = $map.Fields[$pageTemplateSourceFieldId].Value
    $target = $map.Fields[$pageTemplateTargetFieldId].Value
    if ($source -and $target) { $pageTemplateMap[$source.ToUpper()] = $target.ToUpper() }
}

# --- Helpers -------------------------------------------------------------

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

        # Prefer explicit source-key mapping, then fall back to base-key mapping.
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

        # Convert name-{GUID}-index to name-index in Headless SXA.
        # The source index (slot within the instance) is preserved unchanged.
        # DynamicPlaceholderId assignment (GUID→sequential) is tracked in $dynamicState
        # so the caller can later stamp each parent rendering node.
        if ($dynamicState) {
            $guidKey = ("{0}|{1}" -f $mappedBase.ToLowerInvariant(), $guid)
            if (-not $dynamicState.ContainsKey("IndexByGuid")) { $dynamicState["IndexByGuid"] = @{} }
            if (-not $dynamicState.ContainsKey("NextIndexByBase")) { $dynamicState["NextIndexByBase"] = @{} }
            if (-not $dynamicState.ContainsKey("GuidToUid")) { $dynamicState["GuidToUid"] = @{} }

            if (-not $dynamicState["IndexByGuid"].ContainsKey($guidKey)) {
                $baseKey = $mappedBase.ToLowerInvariant()
                $next = if ($dynamicState["NextIndexByBase"].ContainsKey($baseKey)) { [int]$dynamicState["NextIndexByBase"][$baseKey] } else { 0 }
                $dynamicState["IndexByGuid"][$guidKey] = $next
                $dynamicState["NextIndexByBase"][$baseKey] = $next + 1
                # Record GUID → assigned DynamicPlaceholderId so caller can stamp parent nodes
                $dynamicState["GuidToUid"][$guid] = $next
            }

            # Use the sequential GUID-based index so each unique child instance gets a distinct slot.
            $resolvedIndex = [int]$dynamicState["IndexByGuid"][$guidKey]
            return ("{0}-{1}" -f $mappedBase, $resolvedIndex)
        }

        # Fallback: preserve source index if no state container is supplied.
        return ("{0}-{1}" -f $mappedBase, $matches["index"])
    }

    if ($segment -match "^(.+?)(-[{(].+)?$") {
        $base = $matches[1]
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
    $parts = $placeholderPath -split "/"
    $newParts = @()

    foreach ($part in $parts) {
        if ($part -eq "") { continue }
        $newParts += (Normalize-PlaceholderSegment -segment $part -placeholderMap $placeholderMap -dynamicState $dynamicState)
    }

    $newPhCore = ($newParts -join "/")
    if ($hadLeadingSlash) { return "/" + $newPhCore }
    return $newPhCore
}

function Get-DynamicPlaceholderIdsFromLayoutXml {
    param([string]$fieldValue)

    $result = @{}
    if ([string]::IsNullOrWhiteSpace($fieldValue)) { return $result }

    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.PreserveWhitespace = $true
        $xmlDoc.LoadXml($fieldValue)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        foreach ($attr in $xmlDoc.DocumentElement.Attributes) {
            if ($attr.Name -eq "xmlns") { $nsmgr.AddNamespace("", $attr.Value) }
            elseif ($attr.Prefix -eq "xmlns") { $nsmgr.AddNamespace($attr.LocalName, $attr.Value) }
        }
        if (-not $nsmgr.HasNamespace("s")) { $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/") }

        $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
        foreach ($rNode in $allRenderingNodes) {
            $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }
            $uidUpper = $uid.ToUpper()

            $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
            if (-not $rNode.HasAttribute($parAttrName)) { continue }
            $currentPar = $rNode.GetAttribute($parAttrName)
            if ([string]::IsNullOrWhiteSpace($currentPar)) { continue }

            $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
            $dynValue = $parsed["DynamicPlaceholderId"]
            if ([string]::IsNullOrWhiteSpace($dynValue)) { continue }

            $result[$uidUpper] = [string]$dynValue
        }
    } catch {
        Write-Warning ("⚠️ Could not extract DynamicPlaceholderId map from layout XML: {0}" -f $_.Exception.Message)
    }

    return $result
}

function Sync-FinalRenderingsDynamicPlaceholderIdsFromShared {
    param(
        [Sitecore.Data.Items.Item]$item,
        [string]$sharedFieldId,
        [string]$finalFieldId
    )

    if (-not $item -or -not $item.Fields) { return $false }

    $sharedField = $item.Fields[$sharedFieldId]
    $finalField = $item.Fields[$finalFieldId]
    $sharedValue = if ($sharedField) { $sharedField.Value } else { "" }
    $finalValue = if ($finalField) { $finalField.Value } else { "" }
    if ([string]::IsNullOrWhiteSpace($sharedValue) -or [string]::IsNullOrWhiteSpace($finalValue)) { return $false }

    $sharedDynamicIdByUid = Get-DynamicPlaceholderIdsFromLayoutXml -fieldValue $sharedValue
    if ($sharedDynamicIdByUid.Count -eq 0) { return $false }

    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.PreserveWhitespace = $true
        $xmlDoc.LoadXml($finalValue)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        foreach ($attr in $xmlDoc.DocumentElement.Attributes) {
            if ($attr.Name -eq "xmlns") { $nsmgr.AddNamespace("", $attr.Value) }
            elseif ($attr.Prefix -eq "xmlns") { $nsmgr.AddNamespace($attr.LocalName, $attr.Value) }
        }
        if (-not $nsmgr.HasNamespace("s")) { $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/") }

        $changed = $false
        $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
        foreach ($rNode in $allRenderingNodes) {
            $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
            if ([string]::IsNullOrWhiteSpace($uid)) { continue }
            $uidUpper = $uid.ToUpper()
            if (-not $sharedDynamicIdByUid.ContainsKey($uidUpper)) { continue }

            $dynId = [string]$sharedDynamicIdByUid[$uidUpper]
            $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
            $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }

            $nvc = [System.Collections.Specialized.NameValueCollection]::new()
            if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                foreach ($k in $parsed.AllKeys) {
                    if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                }
            }

            if ($nvc["DynamicPlaceholderId"] -eq $dynId) { continue }

            $nvc["DynamicPlaceholderId"] = $dynId
            $pairs = [System.Collections.Generic.List[string]]::new()
            foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
            }
            $newPar = $pairs -join "&"
            $rNode.SetAttribute($parAttrName, $newPar)
            Write-Log -Detailed ("🔁 Final field post-pass synced DynamicPlaceholderId={0} from shared for uid={1} on {2}" -f $dynId, $uid, $item.ItemPath)
            $changed = $true
        }

        if ($changed) {
            [void]$item.Editing.BeginEdit()
            $item.Fields[$finalFieldId].Value = $xmlDoc.OuterXml
            [void]$item.Editing.EndEdit()
            Write-Log -Detailed ("✅ Final Renderings post-pass updated on {0}" -f $item.ItemPath)
        }

        return $changed
    } catch {
        Write-Warning ("❌ Final Renderings DynamicPlaceholderId post-pass failed for {0}: {1}" -f $item.ItemPath, $_.Exception.Message)
        return $false
    }
}

function Update-LayoutXmlFieldOnItem {
    param(
        [Sitecore.Data.Items.Item]$item,
        [string]$fieldId,
        [hashtable]$placeholderMap = $null
    )
    $fieldValue = $item.Fields[$fieldId].Value
    if ([string]::IsNullOrWhiteSpace($fieldValue)) { return $false }

    try {
        $xmlDoc = New-Object System.Xml.XmlDocument
        $xmlDoc.PreserveWhitespace = $true
        $xmlDoc.LoadXml($fieldValue)

        $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
        foreach ($attr in $xmlDoc.DocumentElement.Attributes) {
            if ($attr.Name -eq "xmlns") { $nsmgr.AddNamespace("", $attr.Value) }
            elseif ($attr.Prefix -eq "xmlns") { $nsmgr.AddNamespace($attr.LocalName, $attr.Value) }
        }
        if (-not $nsmgr.HasNamespace("s")) { $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/") }

        $changed = $false

        # Update layout IDs on <d l="...">
        $deviceNodes = $xmlDoc.SelectNodes("//d", $nsmgr)
        foreach ($d in $deviceNodes) {
            $layoutAttr = $d.Attributes["l"]
            if ($layoutAttr) {
                $oldId = $layoutAttr.Value
                if ($layoutMap.ContainsKey($oldId)) {
                    $layoutAttr.Value = $layoutMap[$oldId]
                    $changed = $true
                }
            }
        }

        # Update rendering references s:id / id
        $renderingNodes = $xmlDoc.SelectNodes("//*[@s:id or @id]", $nsmgr)
        foreach ($node in $renderingNodes) {
            if ($node.HasAttribute("s:id")) {
                $old = $node.GetAttribute("s:id")
                if ($renderingMap.ContainsKey($old)) {
                    $node.SetAttribute("s:id", $renderingMap[$old])
                    $changed = $true
                }
            }
            if ($node.HasAttribute("id")) {
                $old = $node.GetAttribute("id")
                if ($renderingMap.ContainsKey($old)) {
                    $node.SetAttribute("id", $renderingMap[$old])
                    $changed = $true
                }
            }
        }

        # Update placeholders s:ph or ph (ONLY if a map is provided)
        if ($placeholderMap -and $placeholderMap.Count -gt 0) {
            $dynamicState = @{
                IndexByGuid     = @{}
                NextIndexByBase = @{}
                GuidToUid       = @{}
            }
            $phNodes = $xmlDoc.SelectNodes('//*[@s:ph or @ph]', $nsmgr)
            foreach ($node in $phNodes) {
                $attrName = if ($node.HasAttribute("s:ph")) { "s:ph" } else { "ph" }
                $oldPh = $node.GetAttribute($attrName)
                if ([string]::IsNullOrWhiteSpace($oldPh)) { continue }

                $newPh = Normalize-PlaceholderPath -placeholderPath $oldPh -placeholderMap $placeholderMap -dynamicState $dynamicState
                if ($newPh -ne $oldPh) {
                    $node.SetAttribute($attrName, $newPh)
                    $changed = $true
                }
            }

            # Stamp DynamicPlaceholderId on each parent rendering whose uid was referenced
            # as a dynamic placeholder owner in the layout XML.
            if ($dynamicState["GuidToUid"].Count -gt 0) {
                $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
                foreach ($rNode in $allRenderingNodes) {
                    $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                    if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                    $uidUpper = $uid.ToUpper()
                    if (-not $dynamicState["GuidToUid"].ContainsKey($uidUpper)) { continue }

                    $dynId = [int]$dynamicState["GuidToUid"][$uidUpper]
                    $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                    $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }

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
                    $changed = $true
                }
            }
        }
 

        if ($changed) {
            [void]$item.Editing.BeginEdit()
            $item.Fields[$fieldId].Value = $xmlDoc.OuterXml
            [void]$item.Editing.EndEdit()
            Write-Host "✅ Field [$fieldId] updated on $($item.ItemPath)"
        }
        return $changed
    } catch {
        Write-Warning ("❌ Could not parse XML for {0}: {1}" -f $item.ItemPath, $_.Exception.Message)
        return $false
    }
}

 
# NEW: Switch copied items to JSS page templates (copying non-standard fields with same names)
function Set-PageTemplateForItemIfMapped {
    param(
        [Sitecore.Data.Items.Item]$item,
        [hashtable]$ptMap
    )

    if (-not $item -or -not $item.ID) { return }
    $currentTemplateB = $item.TemplateID.Guid.ToString("B").ToUpper()
    if (-not $ptMap.ContainsKey($currentTemplateB)) { return }

    $targetTplId = $ptMap[$currentTemplateB]
    $targetTplItem = Get-Item -Path "master:" -ID $targetTplId
    if (-not $targetTplItem) {
        Write-Warning "⚠️ Target template not found for $($item.ItemPath): $targetTplId"
        return
    }

    # Build FieldsToCopy map: non-standard fields that also exist on the target template
    $item.Fields.ReadAll()
    $srcFields = $item.Fields | Where-Object { $_.Name -notlike '__*' }

    $tmpl = [Sitecore.Data.Managers.TemplateManager]::GetTemplate($targetTplItem.ID, $item.Database)
    if (-not $tmpl) {
        Write-Warning "⚠️ Could not resolve TemplateManager object for $($targetTplItem.Paths.FullPath)"
        return
    }

    $fieldsToCopy = @{}
    foreach ($f in $srcFields) {
        if ($tmpl.GetField($f.Name)) { $fieldsToCopy[$f.Name] = $f.Name }
    }

    $tplRelPath = $targetTplItem.Paths.FullPath.Replace("/sitecore/templates/", "")
    try {
        Set-ItemTemplate -Path $item.ItemPath -Template $tplRelPath -FieldsToCopy $fieldsToCopy
        Write-Log -Detailed "🧬 Template changed on $($item.ItemPath): $currentTemplateB → $targetTplId (copied $($fieldsToCopy.Count) field(s))"
    } catch {
        Write-Warning "❌ Set-ItemTemplate failed for $($item.ItemPath): $($_.Exception.Message)"
    }
}

function Set-DatasourceTemplateForItemIfMapped {
    param(
        [Sitecore.Data.Items.Item]$item,
        [hashtable]$templateMap
    )

    if (-not $item -or -not $item.ID) { return $false }
    if (-not $templateMap -or $templateMap.Count -eq 0) { return $false }

    $currentTemplateId = $item.TemplateID.Guid.ToString("B").ToUpper()
    if (-not $templateMap.ContainsKey($currentTemplateId)) { return $false }

    $targetTemplateId = $templateMap[$currentTemplateId]
    if ([string]::IsNullOrWhiteSpace($targetTemplateId) -or $targetTemplateId -eq $currentTemplateId) { return $false }

    $targetTemplateItem = Get-Item -Path "master:" -ID $targetTemplateId -ErrorAction SilentlyContinue
    if (-not $targetTemplateItem) {
        Write-Warning "⚠️ Target datasource template not found for $($item.ItemPath): $targetTemplateId"
        return $false
    }

    $item.Fields.ReadAll()
    $srcFields = $item.Fields | Where-Object { $_.Name -notlike '__*' }

    $templateDef = [Sitecore.Data.Managers.TemplateManager]::GetTemplate($targetTemplateItem.ID, $item.Database)
    if (-not $templateDef) {
        Write-Warning "⚠️ Could not resolve TemplateManager object for $($targetTemplateItem.Paths.FullPath)"
        return $false
    }

    $fieldsToCopy = @{}
    foreach ($f in $srcFields) {
        if ($templateDef.GetField($f.Name)) { $fieldsToCopy[$f.Name] = $f.Name }
    }

    $tplRelPath = $targetTemplateItem.Paths.FullPath.Replace("/sitecore/templates/", "")
    try {
        Set-ItemTemplate -Path $item.ItemPath -Template $tplRelPath -FieldsToCopy $fieldsToCopy
        Write-Log -Detailed "🧬 Datasource template changed on $($item.ItemPath): $currentTemplateId → $targetTemplateId (copied $($fieldsToCopy.Count) field(s))"
        return $true
    } catch {
        Write-Warning "❌ Failed to switch datasource template for $($item.ItemPath): $($_.Exception.Message)"
        return $false
    }
}

function Get-HeadlessTemplateForSourceTemplate {
    param(
        [Sitecore.Data.Items.Item]$sourceTemplateItem,
        [Sitecore.Data.Items.Item]$headlessTemplatesRoot
    )

    if (-not $sourceTemplateItem -or -not $headlessTemplatesRoot) { return $null }

    $fullPath = $sourceTemplateItem.Paths.FullPath
    $relativePath = $null

    $m = [regex]::Match($fullPath, "^/sitecore/templates/(Feature|Foundation|Project)/(.+)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        $relativePath = $m.Groups[2].Value
    } else {
        $m2 = [regex]::Match($fullPath, "^/sitecore/templates/(.+)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m2.Success) {
            $relativePath = $m2.Groups[1].Value
        }
    }

    if ([string]::IsNullOrWhiteSpace($relativePath)) { return $null }

    $targetPath = "{0}/{1}" -f $headlessTemplatesRoot.Paths.FullPath.TrimEnd('/'), $relativePath.TrimStart('/')
    return Get-Item -Path $targetPath -ErrorAction SilentlyContinue
}

function Set-DatasourceTemplateForItemFromSourceItem {
    param(
        [Sitecore.Data.Items.Item]$copiedItem,
        [Sitecore.Data.Items.Item]$sourceItem,
        [Sitecore.Data.Items.Item]$headlessTemplatesRoot
    )

    if (-not $copiedItem -or -not $sourceItem -or -not $headlessTemplatesRoot) { return $false }

    $sourceTemplateItem = Get-Item -Path "master:" -ID $sourceItem.TemplateID -ErrorAction SilentlyContinue
    if (-not $sourceTemplateItem) { return $false }

    $targetTemplateItem = Get-HeadlessTemplateForSourceTemplate -sourceTemplateItem $sourceTemplateItem -headlessTemplatesRoot $headlessTemplatesRoot
    if (-not $targetTemplateItem) { return $false }

    $currentTemplateId = $copiedItem.TemplateID.Guid.ToString("B").ToUpper()
    $targetTemplateId = $targetTemplateItem.ID.Guid.ToString("B").ToUpper()
    if ($currentTemplateId -eq $targetTemplateId) { return $false }

    $copiedItem.Fields.ReadAll()
    $srcFields = $copiedItem.Fields | Where-Object { $_.Name -notlike '__*' }

    $templateDef = [Sitecore.Data.Managers.TemplateManager]::GetTemplate($targetTemplateItem.ID, $copiedItem.Database)
    if (-not $templateDef) { return $false }

    $fieldsToCopy = @{}
    foreach ($f in $srcFields) {
        if ($templateDef.GetField($f.Name)) { $fieldsToCopy[$f.Name] = $f.Name }
    }

    $tplRelPath = $targetTemplateItem.Paths.FullPath.Replace("/sitecore/templates/", "")
    try {
        Set-ItemTemplate -Path $copiedItem.ItemPath -Template $tplRelPath -FieldsToCopy $fieldsToCopy
        Write-Log -Detailed "🧬 Datasource template changed (fallback) on $($copiedItem.ItemPath): $currentTemplateId → $targetTemplateId (copied $($fieldsToCopy.Count) field(s))"
        return $true
    } catch {
        Write-Warning "❌ Fallback datasource template switch failed for $($copiedItem.ItemPath): $($_.Exception.Message)"
        return $false
    }
}

# ------------------------------------------------------------------------

# Copy root item including descendants
$sourceRoot = Get-Item -Path $sourceRootPath.Paths.FullPath
$targetRoot = Get-Item -Path $targetRootPath.Paths.FullPath
 
$originalDataFolders = @()
$copiedDataFolders   = @()
$copiedPageItems     = @()
$copiedPageItemsByLanguage = @()

# Field ID for __Tracking system field
$trackingFieldId = "{B0A67B2A-8B07-4E0B-8809-69F751709806}"
# Field ID for __Security system field
$securityFieldId = "{DEC8D2D5-E3CF-48B6-A653-8E69E2716641}"

$copySection = Start-SectionTimer -Name "Copying root and descendants"

if ($includeChildren) {
    Write-Host "📦 Copying root and all descendants..."
    # Get a single latest-version source item (current language context) before copying.
    # Using -Language * can return multiple root items and trigger duplicate root copies.
    $sourceRootLatest = Get-Item -Path $sourceRoot.ItemPath -Version "latest"
    try {
        $copiedRoot = $sourceRootLatest | Copy-Item -Destination $targetRoot.ItemPath -Recurse -PassThru -ErrorAction Stop
    } catch {
        throw "Root copy failed for '$($sourceRoot.ItemPath)' into '$($targetRoot.ItemPath)': $($_.Exception.Message)"
    }

    if (-not $copiedRoot) {
        throw "Root copy returned no item for '$($sourceRoot.ItemPath)'. Migration stopped to avoid corrupt path mapping."
    }

    $copiedItems = @($copiedRoot)
    $copiedItems += Get-ChildItem -Path $copiedRoot.ItemPath -Recurse

    # 🔍 Find all Datasource folders recursively
    if ($useNameFallback) {
        $origDataFolders      = Get-ChildItem -Path $sourceRoot.ItemPath -Recurse | Where-Object { $_.Name -eq "Data" }
        $copiedDataFoldersAll = Get-ChildItem -Path $copiedRoot.ItemPath -Recurse | Where-Object { $_.Name -eq "Data" }
    } else {
        $origDataFolders      = Get-ChildItem -Path $sourceRoot.ItemPath -Recurse | Where-Object { $_.TemplateID -eq $dataFolderTemplateGuidB }
        $copiedDataFoldersAll = Get-ChildItem -Path $copiedRoot.ItemPath -Recurse | Where-Object { $_.TemplateID -eq $dataFolderTemplateGuidB }
    } 

    foreach ($origData in $origDataFolders) {
        $relativePath = $origData.Paths.FullPath.Replace($sourceRoot.Paths.FullPath, "").TrimStart("/")
        $expectedCopiedPath = "{0}/{1}" -f $copiedRoot.Paths.FullPath.TrimEnd('/'), $relativePath
        $copiedMatchCandidates = @($copiedDataFoldersAll | Where-Object {
            $_.Paths.FullPath -ieq $expectedCopiedPath
        })

        # Fallback for legacy edge-cases where exact relative path fails.
        if ($copiedMatchCandidates.Count -eq 0) {
            $copiedMatchCandidates = @($copiedDataFoldersAll | Where-Object {
                $_.Paths.FullPath.EndsWith($relativePath, [System.StringComparison]::OrdinalIgnoreCase)
            })
        }

        # Deduplicate possible language/version duplicates of the same item.
        $copiedMatchCandidates = @($copiedMatchCandidates |
            Group-Object { $_.ID.Guid.ToString("B").ToUpper() } |
            ForEach-Object { $_.Group[0] })

        $copiedMatch = if ($copiedMatchCandidates.Count -gt 0) { $copiedMatchCandidates[0] } else { $null }
        if ($copiedMatchCandidates.Count -gt 1) {
            Write-Warning "⚠️ Multiple copied matches found for Data folder '$($origData.Paths.FullPath)'. Using first match '$($copiedMatch.Paths.FullPath)'."
        }

        if ($copiedMatch) {
            if ($copiedMatch.Name -ne "Data") {
                try {
                    Rename-Item -Path $copiedMatch.ItemPath -NewName "Data" -ErrorAction Stop
                    $copiedMatch = Get-Item -Path ($copiedMatch.Parent.Paths.FullPath + "/Data") -ErrorAction SilentlyContinue
                    if ($copiedMatch) {
                        Write-Log -Detailed "📝 Renamed copied datasource folder to Data: $($copiedMatch.Paths.FullPath)"
                    }
                } catch {
                    Write-Warning "⚠️ Could not rename copied datasource folder '$($origData.Paths.FullPath)' match '$($copiedMatch.Paths.FullPath)' to Data: $($_.Exception.Message)"
                }
            }

            $originalDataFolders += $origData
            $copiedDataFolders   += $copiedMatch
        } else {
            Write-Warning "⚠️ Could not find copied match for Data folder: $($origData.Paths.FullPath)"
        }
    }
} else {
    Write-Host "📦 Copying only root item and its 'Data' child..."

    # Copy only the root item (no children) - get latest version only
    # Use a single latest-version source item to avoid duplicate root copy attempts.
    $sourceRootLatest = Get-Item -Path $sourceRoot.ItemPath -Version "latest"
    try {
        $copiedRoot  = $sourceRootLatest | Copy-Item -Destination $targetRoot.ItemPath -PassThru -ErrorAction Stop
    } catch {
        throw "Root copy failed for '$($sourceRoot.ItemPath)' into '$($targetRoot.ItemPath)': $($_.Exception.Message)"
    }

    if (-not $copiedRoot) {
        throw "Root copy returned no item for '$($sourceRoot.ItemPath)'. Migration stopped to avoid corrupt path mapping."
    }

    $copiedItems = @($copiedRoot)

    # Find 'Data' child under the original source
    if ($useNameFallback) {
        $dataChild = Get-ChildItem -Path $sourceRoot.ItemPath | Where-Object { $_.Name -eq "Data" } | Select-Object -First 1
    } else {
        $dataChild = Get-ChildItem -Path $sourceRoot.ItemPath | Where-Object { $_.TemplateID -eq $dataFolderTemplateGuidB } | Select-Object -First 1
    }
    
    if ($dataChild) {
        # Copy 'Data' branch under the new copied root
        $dataDestPath = "$($copiedRoot.ItemPath)/Data"
        $dataChild | Copy-Item -Destination $dataDestPath -Recurse
        
        # Re-fetch copied Data item for valid metadata
        $copiedDataItem = Get-Item -Path $dataDestPath
        
        $copiedItems += $copiedDataItem
        $copiedItems += Get-ChildItem -Path $copiedDataItem.ItemPath -Recurse
        
        # Add to mapping collections
        $originalDataFolders += $dataChild
        $copiedDataFolders   += $copiedDataItem
    } else {
        Write-Warning "⚠️ No 'Data' child found under source root: $($sourceRoot.ItemPath)"
    }
}

$copiedItems = @($copiedItems | Where-Object { $_ -and $_.ID -and $_.Paths })
if ($copiedItems.Count -eq 0) {
    throw "No copied items were found after copy step. Migration stopped."
}
Stop-SectionTimer -Section $copySection

$dataPathPrefix = "{0}/Data" -f $copiedRoot.ItemPath.TrimEnd('/')
$copiedPageItems = @($copiedItems | Where-Object {
    $fullPath = $_.Paths.FullPath
    $fullPath -and
    $fullPath -ne $dataPathPrefix -and
    (-not $fullPath.StartsWith("$dataPathPrefix/", [System.StringComparison]::OrdinalIgnoreCase))
})

if ($copiedPageItems.Count -eq 0) {
    $copiedPageItems = @($copiedRoot)
}

function Test-ItemHasFinalLayoutRenderings {
    param(
        [Sitecore.Data.Items.Item]$item
    )

    if (-not $item -or -not $item.ID) { return $false }

    try {
        $renderings = Get-Rendering -Item $item -FinalLayout -ErrorAction SilentlyContinue
        return ($null -ne $renderings -and @($renderings).Count -gt 0)
    } catch {
        return $false
    }
}

$layoutBearingPageItems = @($copiedPageItems | Where-Object { Test-ItemHasFinalLayoutRenderings -item $_ })
Write-Host ("ℹ️ Layout-bearing page items: {0}/{1}" -f $layoutBearingPageItems.Count, $copiedPageItems.Count)

# Build a latest-version set per language only for pages that actually have renderings in final layout.
$copiedPageItemsByLanguage = @($layoutBearingPageItems |
    ForEach-Object {
        $latestByLanguage = Get-Item -Path $_.ItemPath -Language * -Version "latest" -ErrorAction SilentlyContinue
        if ($latestByLanguage) { $latestByLanguage }
    } |
    Where-Object { $_ -and $_.ID -and $_.Paths } |
    Group-Object { "{0}|{1}|{2}" -f $_.ID.Guid.ToString("B").ToUpper(), $_.Language.Name.ToLowerInvariant(), $_.Version.Number } |
    ForEach-Object { $_.Group[0] })

Write-Host ("ℹ️ Language-specific layout processing items: {0}" -f $copiedPageItemsByLanguage.Count)

function Map-DataSourcesRecursively {
    param (
        [Sitecore.Data.Items.Item]$originalItem,
        [Sitecore.Data.Items.Item]$copiedItem
    )

    if ($originalItem -and $copiedItem -and $originalItem.ID -and $copiedItem.ID) {
        $origId = $originalItem.ID.Guid.ToString("B").ToUpper()
        $copyId = $copiedItem.ID.Guid.ToString("B").ToUpper()
        $dsIdMap[$origId] = $copyId
        Write-Log -Detailed "🔗 Mapped data source: $origId → $copyId"

        foreach ($origChild in $originalItem.Children) {
            $copiedChild = $copiedItem.Children | Where-Object { $_.Name -ieq $origChild.Name }
            if ($copiedChild) {
                Map-DataSourcesRecursively -originalItem $origChild -copiedItem $copiedChild
            } else {
                Write-Warning "⚠️ No matching copied item for '$($origChild.Name)' under '$($copiedItem.Paths.FullPath)'"
            }
        }
    }
}

# Build Data Source ID Map with recursive mapping
$mapDataSourcesSection = Start-SectionTimer -Name "Map datasource IDs"
$dsIdMap = @{}
$pageDataTemplateId = "{1C82E550-EBCD-4E5D-8ABD-D50D0809541E}"
for ($j = 0; $j -lt $originalDataFolders.Count; $j++) {
    $origFolder   = $originalDataFolders[$j]
    $copiedFolder = $copiedDataFolders[$j]
    if (-not $origFolder -or -not $copiedFolder) {
        Write-Warning "⚠️ Missing Data folder at index $j — original or copied folder is null"
        continue
    }
    Write-Log -Detailed "📂 Mapping from original '$($origFolder.Paths.FullPath)' → copied '$($copiedFolder.Paths.FullPath)'"
    Map-DataSourcesRecursively -originalItem $origFolder -copiedItem $copiedFolder
}
Stop-SectionTimer -Section $mapDataSourcesSection

# Switch copied Data folder template to SXA Page Data template
$pageDataTemplateGuidB = "{1C82E550-EBCD-4E5D-8ABD-D50D0809541E}"
$db = [Sitecore.Configuration.Factory]::GetDatabase("master")
$pageDataTpl = $db.Templates[$pageDataTemplateGuidB]
if (-not $pageDataTpl) {
    Write-Warning "⚠️ SXA Page Data template not found ($pageDataTemplateGuidB). Data folder template switch skipped."
} else {
    foreach ($copiedFolder in $copiedDataFolders) {
        if (-not $copiedFolder) { continue }
        $freshFolder = $db.GetItem($copiedFolder.ID)
        if (-not $freshFolder) {
            Write-Warning "⚠️ Could not re-fetch copied data folder by ID $($copiedFolder.ID)"
            continue
        }
        if ($freshFolder.TemplateID -eq $pageDataTpl.ID) {
            Write-Host "ℹ️ Data folder already on Page Data template: $($freshFolder.Paths.FullPath)"
            continue
        }
        try {
            [void]$freshFolder.Editing.BeginEdit()
            [void]$freshFolder.ChangeTemplate($pageDataTpl)
            [void]$freshFolder.Editing.EndEdit()
            Write-Log -Detailed "📄 Data folder template switched to Page Data on $($freshFolder.Paths.FullPath)"
        } catch {
            $freshFolder.Editing.CancelEdit()
            Write-Warning "❌ Could not switch template on $($freshFolder.Paths.FullPath): $($_.Exception.Message)"
        }
    }
}

# NEW: Clear __Tracking and __Security fields on all copied items to clean migration history
Write-Host "🧹 Clearing __Tracking and __Security fields on migrated page items (excluding Data subtree)..."
$clearSecuritySection = Start-SectionTimer -Name "Clear tracking/security fields"
foreach ($copiedItem in $copiedPageItems) {
    if ($copiedItem -and $copiedItem.ID) {
        try {
            [void]$copiedItem.Editing.BeginEdit()
            $copiedItem.Fields[$trackingFieldId].Value = ""
            $copiedItem.Fields[$securityFieldId].Value = ""
            [void]$copiedItem.Editing.EndEdit()
            Write-Log -Detailed "✅ __Tracking and __Security fields cleared on $($copiedItem.ItemPath)"
        } catch {
            if ($copiedItem.Editing.IsEditing) {
                [void]$copiedItem.Editing.CancelEdit()
            }
            Write-Warning "⚠️ Could not clear __Tracking and __Security fields on $($copiedItem.ItemPath): $($_.Exception.Message)"
        }
    }
}
Stop-SectionTimer -Section $clearSecuritySection

# NEW: Switch templates on copied items (before we rewrite their layout fields)
$setItemTemplateSection = Start-SectionTimer -Name "Set-ItemTemplate remap"
foreach ($ci in ($copiedPageItems |
    Group-Object { $_.ID.Guid.ToString("B").ToUpper() } |
    ForEach-Object { $_.Group[0] })) {
    Set-PageTemplateForItemIfMapped -item $ci -ptMap $pageTemplateMap
}

# Switch local datasource item templates using mappings derived from Phase 2 rendering datasource templates.
$copiedLocalDatasourceItems = [System.Collections.Generic.List[Sitecore.Data.Items.Item]]::new()
foreach ($copiedFolder in $copiedDataFolders) {
    if (-not $copiedFolder) { continue }
    $copiedLocalDatasourceItems.Add($copiedFolder)
    foreach ($desc in (Get-ChildItem -Path $copiedFolder.ItemPath -Recurse -ErrorAction SilentlyContinue)) {
        if ($desc) { $copiedLocalDatasourceItems.Add($desc) }
    }
}

$headlessTemplatesRootItem = Resolve-ItemFromReferenceValue -referenceValue $migrationConfig.Fields["Headless Rendering Datasource and Parameters Templates Root"].Value
$reverseDsIdMap = @{}
foreach ($sourceId in $dsIdMap.Keys) {
    $copyId = $dsIdMap[$sourceId]
    if (-not [string]::IsNullOrWhiteSpace($copyId)) {
        $reverseDsIdMap[$copyId.ToUpperInvariant()] = $sourceId.ToUpperInvariant()
    }
}

$localDsTemplateCounters = [ordered]@{
    TotalCandidates = $copiedLocalDatasourceItems.Count
    SwitchedByDerivedMap = 0
    SwitchedByFallback = 0
    UnchangedOrUnresolved = 0
}

if ($copiedLocalDatasourceItems.Count -gt 0) {
    foreach ($dsItem in $copiedLocalDatasourceItems) {
        if (-not $dsItem -or -not $dsItem.ID) {
            $localDsTemplateCounters.UnchangedOrUnresolved++
            continue
        }

        $switched = $false
        if ($datasourceTemplateMap.Count -gt 0) {
            $switched = Set-DatasourceTemplateForItemIfMapped -item $dsItem -templateMap $datasourceTemplateMap
            if ($switched) {
                $localDsTemplateCounters.SwitchedByDerivedMap++
                continue
            }
        }

        if ($headlessTemplatesRootItem) {
            $copyIdKey = $dsItem.ID.Guid.ToString("B").ToUpper()
            if ($reverseDsIdMap.ContainsKey($copyIdKey)) {
                $sourceId = $reverseDsIdMap[$copyIdKey]
                $sourceItem = Get-Item -Path "master:" -ID $sourceId -ErrorAction SilentlyContinue
                if ($sourceItem) {
                    $switched = Set-DatasourceTemplateForItemFromSourceItem -copiedItem $dsItem -sourceItem $sourceItem -headlessTemplatesRoot $headlessTemplatesRootItem
                    if ($switched) {
                        $localDsTemplateCounters.SwitchedByFallback++
                        continue
                    }
                }
            }
        }

        $localDsTemplateCounters.UnchangedOrUnresolved++
    }

    Write-Host (
        "ℹ️ Local datasource template remap summary: total={0}, derived-map switched={1}, fallback switched={2}, unchanged/unresolved={3}" -f
        $localDsTemplateCounters.TotalCandidates,
        $localDsTemplateCounters.SwitchedByDerivedMap,
        $localDsTemplateCounters.SwitchedByFallback,
        $localDsTemplateCounters.UnchangedOrUnresolved
    )
} else {
    Write-Host "ℹ️ Datasource template remap skipped (no copied local datasource items)."
}
Stop-SectionTimer -Section $setItemTemplateSection

# Process rendering fields on migrated page items (exclude Data subtree)
$renderingsSection = Start-SectionTimer -Name "Process rendering XML fields"
foreach ($item in $copiedPageItemsByLanguage) {
    if (-not $item -or -not $item.Fields) { continue }

    # Final Renderings may only contain deltas (uid + overridden params). Build a shared-field
    # fallback map so DynamicPlaceholderId can be propagated by uid when absent in final XML.
    $sharedField = $item.Fields[$renderingsFieldId]
    $sharedFieldValue = if ($sharedField) { $sharedField.Value } else { "" }

    # Only update shared or final field if the source field had a value
    $sharedField = $item.Fields[$renderingsFieldId]
    $sharedFieldValue = if ($sharedField) { $sharedField.Value } else { "" }
    $finalField = $item.Fields[$finalRenderingsFieldId]
    $finalFieldValue = if ($finalField) { $finalField.Value } else { "" }
    $sharedDynamicIdByUid = Get-DynamicPlaceholderIdsFromLayoutXml -fieldValue $sharedFieldValue
    $pendingFieldUpdates = @{}

    # Update shared field if it has a value
    if (![string]::IsNullOrWhiteSpace($sharedFieldValue)) {
        $fieldId = $renderingsFieldId
        $fieldValue = $sharedFieldValue
        try {
            $xmlDoc = New-Object System.Xml.XmlDocument
            $xmlDoc.PreserveWhitespace = $true
            $xmlDoc.LoadXml($fieldValue)

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
            foreach ($attr in $xmlDoc.DocumentElement.Attributes) {
                if ($attr.Name -eq "xmlns") {
                    $nsmgr.AddNamespace("", $attr.Value)
                } elseif ($attr.Prefix -eq "xmlns") {
                    $nsmgr.AddNamespace($attr.LocalName, $attr.Value)
                }
            }
            if (-not $nsmgr.HasNamespace("s")) {
                $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/")
            }

            $changed = $false
            # ...existing code for updating layout, renderings, ds, ph, etc. (copy from above)...
            # Replace layout ID (NO injection fallback anymore)
            $deviceNodes = $xmlDoc.SelectNodes("//d", $nsmgr)
            foreach ($d in $deviceNodes) {
                $layoutAttr = $d.Attributes["l"]
                if ($layoutAttr) {
                    $oldId = $layoutAttr.Value
                    Write-Log -Detailed "🔍 Found layout attribute in $($item.ItemPath): $oldId"
                    if ($layoutMap.ContainsKey($oldId)) {
                        $layoutAttr.Value = $layoutMap[$oldId]
                        Write-Log -Detailed "🎯 Layout ID updated in $($item.ItemPath)"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "LayoutIdNotFound" -Key $oldId -Message "❌ Layout ID not found in map: $oldId"
                    }
                }
            }
            # ...existing code for updating renderings, ds, ph, etc. (copy from above)...
            # Replace s:id and id (rendering references)
            $renderingNodes = $xmlDoc.SelectNodes("//*[@s:id or @id]", $nsmgr)
            foreach ($node in $renderingNodes) {
                if ($node.HasAttribute("s:id")) {
                    $old = $node.GetAttribute("s:id")
                    if ($renderingMap.ContainsKey($old)) {
                        $node.SetAttribute("s:id", $renderingMap[$old])
                        Write-Log -Detailed "🔄 s:id replaced in $($item.ItemPath): $old → $($renderingMap[$old])"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "RenderingIdNotFound" -Key $old -Message "⚠️ s:id NOT FOUND in renderingMap: $old"
                    }
                }
                if ($node.HasAttribute("id")) {
                    $old = $node.GetAttribute("id")
                    if ($renderingMap.ContainsKey($old)) {
                        $node.SetAttribute("id", $renderingMap[$old])
                        Write-Log -Detailed "🔄 id replaced in $($item.ItemPath): $old → $($renderingMap[$old])"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "RenderingIdNotFound" -Key $old -Message "⚠️ id NOT FOUND in renderingMap: $old"
                    }
                }
            }
            # ...existing code for updating ds, ph, etc. (copy from above)...
            $dsNodes = $xmlDoc.SelectNodes('//*[@s:ds or @ds]', $nsmgr)
            foreach ($node in $dsNodes) {
                $attrName = if ($node.HasAttribute("s:ds")) { "s:ds" } else { "ds" }
                $dsId = $node.GetAttribute($attrName)
                if ([string]::IsNullOrWhiteSpace($dsId)) { continue }
                if ($renderingMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $renderingMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via mapping → $($renderingMap[$dsId])"
                    $changed = $true
                } elseif ($dsIdMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $dsIdMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via copied data → $($dsIdMap[$dsId])"
                    $changed = $true
                } elseif ($globalDsIdMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $globalDsIdMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via global datasource map → $($globalDsIdMap[$dsId])"
                    $changed = $true
                } else {
                    Write-DedupedWarning -Category "DatasourceIdNotFound" -Key $dsId -Message "⚠️ $attrName ID not found in any map → $dsId"
                }
            }
            # ...existing code for updating ph, etc. (copy from above)...
            $dynamicState = @{
                IndexByGuid     = @{}
                NextIndexByBase = @{}
                GuidToUid       = @{}
            }
            $phNodes = $xmlDoc.SelectNodes('//*[@s:ph or @ph]', $nsmgr)
            foreach ($node in $phNodes) {
                $attrName = if ($node.HasAttribute("s:ph")) { "s:ph" } else { "ph" }
                $oldPh = $node.GetAttribute($attrName)
                if ([string]::IsNullOrWhiteSpace($oldPh)) { continue }
                $newPh = Normalize-PlaceholderPath -placeholderPath $oldPh -placeholderMap $placeholderMap -dynamicState $dynamicState
                if ($newPh -ne $oldPh) {
                    $node.SetAttribute($attrName, $newPh)
                    Write-Log -Detailed "🔁 Placeholder updated in $($item.ItemPath): $oldPh → $newPh"
                    $changed = $true
                }
            }
            # ...existing code for dynamic placeholder id, etc. (copy from above)...
            if ($dynamicState["GuidToUid"].Count -gt 0) {
                $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
                foreach ($rNode in $allRenderingNodes) {
                    $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                    if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                    $uidUpper = $uid.ToUpper()
                    if (-not $dynamicState["GuidToUid"].ContainsKey($uidUpper)) { continue }
                    $dynId = [int]$dynamicState["GuidToUid"][$uidUpper]
                    $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                    $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }
                    $nvc = [System.Collections.Specialized.NameValueCollection]::new()
                    if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                        $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                        foreach ($k in $parsed.AllKeys) {
                            if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                        }
                    }
                    $existingValue = $nvc["DynamicPlaceholderId"]
                    if ($existingValue -eq [string]$dynId) { continue }
                    $nvc["DynamicPlaceholderId"] = [string]$dynId
                    $pairs = [System.Collections.Generic.List[string]]::new()
                    foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                        $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
                    }
                    $newPar = $pairs -join "&"
                    $rNode.SetAttribute($parAttrName, $newPar)
                    Write-Log -Detailed ("🔢 DynamicPlaceholderId={0} set on rendering uid={1} in {2}" -f $dynId, $uid, $item.ItemPath)
                    $changed = $true
                }
            }
            # ...existing code for fallback from shared, etc. (copy from above)...
            if ($sharedDynamicIdByUid.Count -gt 0) {
                $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
                foreach ($rNode in $allRenderingNodes) {
                    $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                    if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                    $uidUpper = $uid.ToUpper()
                    if (-not $sharedDynamicIdByUid.ContainsKey($uidUpper)) { continue }
                    $dynId = [string]$sharedDynamicIdByUid[$uidUpper]
                    $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                    $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }
                    $nvc = [System.Collections.Specialized.NameValueCollection]::new()
                    if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                        $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                        foreach ($k in $parsed.AllKeys) {
                            if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                        }
                    }
                    if ($nvc["DynamicPlaceholderId"] -eq $dynId) { continue }
                    $nvc["DynamicPlaceholderId"] = $dynId
                    $pairs = [System.Collections.Generic.List[string]]::new()
                    foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                        $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
                    }
                    $newPar = $pairs -join "&"
                    $rNode.SetAttribute($parAttrName, $newPar)
                    Write-Log -Detailed ("🔁 Fallback DynamicPlaceholderId={0} synced from shared layout for uid={1} in {2} field={3}" -f $dynId, $uid, $item.ItemPath, $fieldId)
                    $changed = $true
                }
            }
            # ...existing code for stripping rls, s:pt, etc. (copy from above)...
            $rlsNodes = $xmlDoc.SelectNodes("//rls")
            foreach ($rls in $rlsNodes) {
                $rls.ParentNode.RemoveChild($rls) | Out-Null
                $changed = $true
            }
            if ($rlsNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed $($rlsNodes.Count) <rls> node(s) from $($item.ItemPath)"
            }
            $ptNodes = $xmlDoc.SelectNodes('//*[@s:pt]', $nsmgr)
            foreach ($node in $ptNodes) {
                $node.RemoveAttribute("s:pt")
                $changed = $true
            }
            if ($ptNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed s:pt (page test) attribute from $($ptNodes.Count) rendering(s) on $($item.ItemPath)"
            }
            # Remove <p> placeholder key mapping nodes (legacy format)
            $pNodes = $xmlDoc.SelectNodes("//*[local-name()='p']", $nsmgr)
            foreach ($p in $pNodes) {
                $p.ParentNode.RemoveChild($p) | Out-Null
                $changed = $true
            }
            if ($pNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed $($pNodes.Count) <p> node(s) from shared layout on $($item.ItemPath)"
            }
            if ($changed) {
                $pendingFieldUpdates[$fieldId] = $xmlDoc.OuterXml
            }
        } catch {
            Write-Warning "❌ Could not parse XML for $($item.ItemPath): $($_.Exception.Message)"
        }
    }

    # Update final field if it has a value
    if (![string]::IsNullOrWhiteSpace($finalFieldValue)) {
        $fieldId = $finalRenderingsFieldId
        $fieldValue = $finalFieldValue
        try {
            $xmlDoc = New-Object System.Xml.XmlDocument
            $xmlDoc.PreserveWhitespace = $true
            $xmlDoc.LoadXml($fieldValue)

            $nsmgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
            foreach ($attr in $xmlDoc.DocumentElement.Attributes) {
                if ($attr.Name -eq "xmlns") {
                    $nsmgr.AddNamespace("", $attr.Value)
                } elseif ($attr.Prefix -eq "xmlns") {
                    $nsmgr.AddNamespace($attr.LocalName, $attr.Value)
                }
            }
            if (-not $nsmgr.HasNamespace("s")) {
                $nsmgr.AddNamespace("s", "http://www.sitecore.net/xmlconfig/")
            }

            $changed = $false
            # ...repeat the same update logic as above for the final field...
            # Replace layout ID (NO injection fallback anymore)
            $deviceNodes = $xmlDoc.SelectNodes("//d", $nsmgr)
            foreach ($d in $deviceNodes) {
                $layoutAttr = $d.Attributes["l"]
                if ($layoutAttr) {
                    $oldId = $layoutAttr.Value
                    Write-Log -Detailed "🔍 Found layout attribute in $($item.ItemPath): $oldId"
                    if ($layoutMap.ContainsKey($oldId)) {
                        $layoutAttr.Value = $layoutMap[$oldId]
                        Write-Log -Detailed "🎯 Layout ID updated in $($item.ItemPath)"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "LayoutIdNotFound" -Key $oldId -Message "❌ Layout ID not found in map: $oldId"
                    }
                }
            }
            $renderingNodes = $xmlDoc.SelectNodes("//*[@s:id or @id]", $nsmgr)
            foreach ($node in $renderingNodes) {
                if ($node.HasAttribute("s:id")) {
                    $old = $node.GetAttribute("s:id")
                    if ($renderingMap.ContainsKey($old)) {
                        $node.SetAttribute("s:id", $renderingMap[$old])
                        Write-Log -Detailed "🔄 s:id replaced in $($item.ItemPath): $old → $($renderingMap[$old])"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "RenderingIdNotFound" -Key $old -Message "⚠️ s:id NOT FOUND in renderingMap: $old"
                    }
                }
                if ($node.HasAttribute("id")) {
                    $old = $node.GetAttribute("id")
                    if ($renderingMap.ContainsKey($old)) {
                        $node.SetAttribute("id", $renderingMap[$old])
                        Write-Log -Detailed "🔄 id replaced in $($item.ItemPath): $old → $($renderingMap[$old])"
                        $changed = $true
                    } else {
                        Write-DedupedWarning -Category "RenderingIdNotFound" -Key $old -Message "⚠️ id NOT FOUND in renderingMap: $old"
                    }
                }
            }
            $dsNodes = $xmlDoc.SelectNodes('//*[@s:ds or @ds]', $nsmgr)
            foreach ($node in $dsNodes) {
                $attrName = if ($node.HasAttribute("s:ds")) { "s:ds" } else { "ds" }
                $dsId = $node.GetAttribute($attrName)
                if ([string]::IsNullOrWhiteSpace($dsId)) { continue }
                if ($renderingMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $renderingMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via mapping → $($renderingMap[$dsId])"
                    $changed = $true
                } elseif ($dsIdMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $dsIdMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via copied data → $($dsIdMap[$dsId])"
                    $changed = $true
                } elseif ($globalDsIdMap.ContainsKey($dsId)) {
                    $node.SetAttribute($attrName, $globalDsIdMap[$dsId])
                    Write-Log -Detailed "🔄 $attrName replaced via global datasource map → $($globalDsIdMap[$dsId])"
                    $changed = $true
                } else {
                    Write-DedupedWarning -Category "DatasourceIdNotFound" -Key $dsId -Message "⚠️ $attrName ID not found in any map → $dsId"
                }
            }
            $dynamicState = @{
                IndexByGuid     = @{}
                NextIndexByBase = @{}
                GuidToUid       = @{}
            }
            $phNodes = $xmlDoc.SelectNodes('//*[@s:ph or @ph]', $nsmgr)
            foreach ($node in $phNodes) {
                $attrName = if ($node.HasAttribute("s:ph")) { "s:ph" } else { "ph" }
                $oldPh = $node.GetAttribute($attrName)
                if ([string]::IsNullOrWhiteSpace($oldPh)) { continue }
                $newPh = Normalize-PlaceholderPath -placeholderPath $oldPh -placeholderMap $placeholderMap -dynamicState $dynamicState
                if ($newPh -ne $oldPh) {
                    $node.SetAttribute($attrName, $newPh)
                    Write-Log -Detailed "🔁 Placeholder updated in $($item.ItemPath): $oldPh → $newPh"
                    $changed = $true
                }
            }
            if ($dynamicState["GuidToUid"].Count -gt 0) {
                $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
                foreach ($rNode in $allRenderingNodes) {
                    $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                    if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                    $uidUpper = $uid.ToUpper()
                    if (-not $dynamicState["GuidToUid"].ContainsKey($uidUpper)) { continue }
                    $dynId = [int]$dynamicState["GuidToUid"][$uidUpper]
                    $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                    $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }
                    $nvc = [System.Collections.Specialized.NameValueCollection]::new()
                    if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                        $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                        foreach ($k in $parsed.AllKeys) {
                            if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                        }
                    }
                    $existingValue = $nvc["DynamicPlaceholderId"]
                    if ($existingValue -eq [string]$dynId) { continue }
                    $nvc["DynamicPlaceholderId"] = [string]$dynId
                    $pairs = [System.Collections.Generic.List[string]]::new()
                    foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                        $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
                    }
                    $newPar = $pairs -join "&"
                    $rNode.SetAttribute($parAttrName, $newPar)
                    Write-Log -Detailed ("🔢 DynamicPlaceholderId={0} set on rendering uid={1} in {2}" -f $dynId, $uid, $item.ItemPath)
                    $changed = $true
                }
            }
            if ($sharedDynamicIdByUid.Count -gt 0) {
                $allRenderingNodes = $xmlDoc.SelectNodes('//*[@uid]', $nsmgr)
                foreach ($rNode in $allRenderingNodes) {
                    $uid = $rNode.GetAttribute("uid") -replace '[{}]', ''
                    if ([string]::IsNullOrWhiteSpace($uid)) { continue }
                    $uidUpper = $uid.ToUpper()
                    if (-not $sharedDynamicIdByUid.ContainsKey($uidUpper)) { continue }
                    $dynId = [string]$sharedDynamicIdByUid[$uidUpper]
                    $parAttrName = if ($rNode.HasAttribute("s:par")) { "s:par" } else { "par" }
                    $currentPar = if ($rNode.HasAttribute($parAttrName)) { $rNode.GetAttribute($parAttrName) } else { "" }
                    $nvc = [System.Collections.Specialized.NameValueCollection]::new()
                    if (-not [string]::IsNullOrWhiteSpace($currentPar)) {
                        $parsed = [System.Web.HttpUtility]::ParseQueryString($currentPar)
                        foreach ($k in $parsed.AllKeys) {
                            if (-not [string]::IsNullOrWhiteSpace($k)) { $nvc[$k] = $parsed[$k] }
                        }
                    }
                    if ($nvc["DynamicPlaceholderId"] -eq $dynId) { continue }
                    $nvc["DynamicPlaceholderId"] = $dynId
                    $pairs = [System.Collections.Generic.List[string]]::new()
                    foreach ($k in ($nvc.AllKeys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                        $pairs.Add(("{0}={1}" -f [System.Uri]::EscapeDataString($k), [System.Uri]::EscapeDataString([string]$nvc[$k])))
                    }
                    $newPar = $pairs -join "&"
                    $rNode.SetAttribute($parAttrName, $newPar)
                    Write-Log -Detailed ("🔁 Fallback DynamicPlaceholderId={0} synced from shared layout for uid={1} in {2} field={3}" -f $dynId, $uid, $item.ItemPath, $fieldId)
                    $changed = $true
                }
            }
            $rlsNodes = $xmlDoc.SelectNodes("//rls")
            foreach ($rls in $rlsNodes) {
                $rls.ParentNode.RemoveChild($rls) | Out-Null
                $changed = $true
            }
            if ($rlsNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed $($rlsNodes.Count) <rls> node(s) from $($item.ItemPath)"
            }
            $ptNodes = $xmlDoc.SelectNodes('//*[@s:pt]', $nsmgr)
            foreach ($node in $ptNodes) {
                $node.RemoveAttribute("s:pt")
                $changed = $true
            }
            if ($ptNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed s:pt (page test) attribute from $($ptNodes.Count) rendering(s) on $($item.ItemPath)"
            }
            # Remove <p> placeholder key mapping nodes (legacy format)
            $pNodes = $xmlDoc.SelectNodes("//*[local-name()='p']", $nsmgr)
            foreach ($p in $pNodes) {
                $p.ParentNode.RemoveChild($p) | Out-Null
                $changed = $true
            }
            if ($pNodes.Count -gt 0) {
                Write-Log -Detailed "🧹 Removed $($pNodes.Count) <p> node(s) from final layout on $($item.ItemPath)"
            }
            if ($changed) {
                $pendingFieldUpdates[$fieldId] = $xmlDoc.OuterXml
            }
        } catch {
            Write-Warning "❌ Could not parse XML for $($item.ItemPath): $($_.Exception.Message)"
        }
    }

    if ($pendingFieldUpdates.Count -gt 0) {
        try {
            [void]$item.Editing.BeginEdit()
            foreach ($pendingFieldId in $pendingFieldUpdates.Keys) {
                $item.Fields[$pendingFieldId].Value = $pendingFieldUpdates[$pendingFieldId]
            }
            [void]$item.Editing.EndEdit()
            foreach ($pendingFieldId in $pendingFieldUpdates.Keys) {
                Write-Log -Detailed "✅ Field [$pendingFieldId] updated on $($item.ItemPath)"
            }
        } catch {
            if ($item.Editing.IsEditing) {
                $item.Editing.CancelEdit()
            }
            Write-Warning "❌ Could not commit rendering field updates for $($item.ItemPath): $($_.Exception.Message)"
        }
    }

    # Only sync DynamicPlaceholderId from shared to final if both fields exist
    if (![string]::IsNullOrWhiteSpace($sharedFieldValue) -and ![string]::IsNullOrWhiteSpace($finalFieldValue)) {
        [void](Sync-FinalRenderingsDynamicPlaceholderIdsFromShared -item $item -sharedFieldId $renderingsFieldId -finalFieldId $finalRenderingsFieldId)
    }
}
Stop-SectionTimer -Section $renderingsSection

if ($warningTotals.Count -gt 0) {
    Write-Log "⚠️ Deduped warning summary:"
    foreach ($category in $warningTotals.Keys) {
        $uniqueCount = if ($warningSeenByCategory.ContainsKey($category)) { $warningSeenByCategory[$category].Count } else { 0 }
        Write-Log ("   - {0}: total={1}, unique={2}" -f $category, $warningTotals[$category], $uniqueCount)
    }
}

if ($sectionDurations.Count -gt 0) {
    Write-Log "⏱️ Section duration summary:"
    foreach ($sectionName in $sectionDurations.Keys) {
        Write-Log ("   - {0}: {1:hh\:mm\:ss}" -f $sectionName, $sectionDurations[$sectionName])
    }
}

$scriptStopwatch.Stop()
Write-Host ("⏱️ Total migration duration: {0:hh\:mm\:ss}" -f $scriptStopwatch.Elapsed)
