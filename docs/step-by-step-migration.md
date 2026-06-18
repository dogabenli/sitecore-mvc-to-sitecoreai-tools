# MVC to SitecoreAI Migration via SPE scripts and XM to XM Cloud Tool

This document outlines the steps to migrate a legacy MVC site to SitecoreAI using Sitecore PowerShell Scripts and the XM to XM Cloud Tool.

## Migration Overview

![Migration Overview Diagram](images/1-16e08dba-2cc4-413f-bd6c-4c5caa67a030.png)

The migration phases are detailed below:

## Phase 1

Install the necessary Sitecore packages.

![Install Packages](images/2-f9fc521a-59da-44dc-85b8-6be037762ce7.png)

After installing the MVC to Headless SXA Migration package, migration ribbons appear under the Developer tab.

![Developer Ribbon](images/3-8c0f58cf-2661-4811-bcf6-bc661f8d1001.png)

## Phase 2

Create an empty Headless SXA site next to the legacy site.

![Create Headless SXA Site](images/4-d94e9e7a-875d-4c5c-85ec-867538e74e68.png)

For example:

![Example Site Structure](images/5-adb4840f-826b-4bb1-b6b1-9edf266aa77a.png)

## Phase 3

Fill Migration Configuration item fields: `/sitecore/system/Settings/Migration/Migration Configuration`

![Migration Configuration](images/6-834d3dcd-ac8b-4ecb-9803-4593c7932a15.png)

| Field | Type | Description |
|-----|-----|-----|
| MVC Start Item | DropTree | Fill with MVC start item, usually the Home item, e.g., "/sitecore/content/Habitat Standard Sites/Habitat Home Corporate/Home" |
| Dynamic Placeholder Sample Size | Integer | Default value is 50. The `Convert-mvc-to-headless-sxa.ps1` script analyzes MVC site dynamic placeholder usage and updates JSON renderings and rendering parameter templates for the Headless SXA site. It fetches Page Type items starting from the MVC Start Item. The Dynamic Placeholder Sample Size field controls how many pages the script fetches. Increasing this number slows the script, so keep it as is for the first run. You can run the script multiple times. After the first run, all headless renderings, placeholders, and related templates are created. Then you can increase Dynamic Placeholder Sample Size to capture all dynamic placeholder usage and update relevant headless items accordingly. To choose an appropriate number, use the `Get-SitePageCount.ps1` script for page statistics. For example, if the ContentPage template appears in over 800 pages, set the value to at least 400 in the second iteration. This should cover all dynamic placeholder usage. |
| Primary Language | Droplink | Set the site's main language. The `Convert-mvc-to-headless-sxa.ps1` script fetches page items based on this language and analyzes them. |
| MVC Renderings | TreelistEx | Select MVC renderings. Select folders or individual Controller or View Renderings. Avoid selecting high-level Feature or Foundation folders, as they include OOTB Experience Accelerator components. Select only your custom MVC components.<br> ![MVC Renderings Example](images/18-4e9894d8-0289-47a0-a247-244b3a0f619e.png) |
| Headless Rendering Root | Droptree | Set the headless collection root item for headless renderings. It is created automatically when you create a Headless Site Collection.<br> ![Headless Rendering Root Example](images/19-22e95590-95c6-4e45-9fb1-3aad63f2ccef.png) |
| Headless Rendering Datasource and Parameters Templates Root | Droptree | Set the folder where datasource and parameter templates are created. It is recommended to create a folder under site collection templates and set this path because it is easier to delete items underneath when something goes wrong while running the scripts. You can clean up the folder and re-run the script again.<br> ![Headless Rendering Datasource and Parameters Templates Folder](images/20-9e961b39-678a-479d-8ac4-32585643c32c.png)<br>![Headless Rendering Datasource and Parameters Templates Root Value](images/21-0c400cfd-ae68-434d-9e6a-c3dd8c8d0f45.png) |
| MVC Placeholders | TreelistEx | Select MVC placeholders used in the MVC site. Select folders or individual placeholders. Avoid selecting high-level Feature or Foundation folders.<br> ![MVC Placeholders Example](images/22-33582197-59b5-4ebc-bd30-2db91b5fc721.png) |
| Headless Placeholders Root | Droptree | Set the headless collection root item for placeholder settings. It is created automatically when you create a Headless Site Collection.<br> ![Headless Placeholders Root Example](images/23-e255907c-d35e-4ef0-8686-d31059fcd36f.png) |
| Headless Placeholder Prefix | Single-Line Text | Set the prefix value for placeholders. This prefix sets placeholder keys when creating placeholders for the headless site. For example, if you set the prefix to headless and have a main placeholder used in the MVC site, the script creates a placeholder with the key headless-main for the headless site. ![Headless Placeholder Prefix Example](images/24-d098c215-caa8-481a-8420-d616af369ebc.png) |
| MVC Page Type Templates | TreelistEx | Select MVC Page Type Templates. Select individual page type templates or folders. ![MVC Page Type Templates Example](images/25-2640896c-f792-491e-9071-2b7d60f31fbc.png) |
| Headless Page Type Templates Root | Droptree | Set headless page type template root location. It is recommended to create a folder underneath the site collection templates.<br> ![Headless Page Types Folder](images/26-2f2bb978-3c90-49f1-ac9c-819252fc49de.png)<br>![Headless Page Type Templates Root Value](images/27-16a2067e-8ca9-42a7-b7e3-0d33a8027ca5.png) |
| Local Data Source Template | Droptree | Fill this field if your project uses local data sources for page items. Leave it empty if your project does not have local data source items.<br> ![Local Data Source Folder Example](images/28-41eb758b-f46c-4b24-9c53-57c90774e31d.png)<br>![Local Data Source Template Value](images/29-4d9ce3a0-d32f-403f-a1e0-0605914225a5.png) |
| MVC Datasource Configuration Root | Droptree | Set MVC Datasource Configuration Root item. Some MVC projects include datasource configuration under the site instead of MVC renderings. These setting items include Datasource Location and Datasource Template fields. For SitecoreAI migration, these field values need to be migrated to the headless renderings and these MVC datasource items should not be used anymore. If you have datasource configuration like this, set this field. Otherwise leave it empty. ![MVC Datasource Configuration Root Item](images/30-93941323-df89-41c7-ac81-e9113499cca3.png)<br>![MVC Datasource Configuration Root Value](images/31-0337feb9-eea6-448f-8e13-63f9ceae4835.png) |
| MVC Datasource Root | Droptree | Set your MVC datasource root.<br> ![MVC Datasource Root Example](images/32-fb20f372-967b-40c0-b19c-a9a03623aad8.png) |
| Headless Datasource Root | Droptree | Set the target for migrating MVC datasources in the headless site, usually the Data folder in headless SXA. Create a temporary folder, such as Migration, under the Data folder to easily delete items if needed. This allows you to remove items under this folder and rerun the script if something goes wrong. After migration, restructure the Data folder and remove the Migration folder. <br>![Headless Datasource Migration Folder](images/33-7a1d3a01-9a09-4d0c-b914-68b6ed85f818.png)<br>![Headless Datasource Root Value](images/34-214b34ac-97a6-4868-a1fe-3323038366b9.png) |

Layout mappings are not automated; create layout migration maps manually under `/sitecore/system/Settings/Migration/Mappings/Layout Mappings`.

![Layout Migration Maps](images/7-283f90df-d99c-4f00-bf25-a1befb10aebc.png)

## Phase 4

Run "Convert Items from MVC to Headless SXA" script. It automatically creates headless renderings, placeholders and migrate data sources.

![Convert Items Wizard](images/8-a043b2d5-3f48-4ce5-a859-38ca51722fe6.png)

## Phase 5

Using “Migrate Pages”, legacy pages can be migrated to Headless SXA site.

![Migrate Pages Dialog](images/9-c245d933-7bf8-45b6-8ddc-265f079fe89b.png)

Migration updates all components and related data source references.

| MVC | Headless |
|-----|----------|
| ![MVC Layout and Renderings](images/10-3229bf49-9335-463d-a18d-2b28ce55a086.png) | ![Headless Layout and Renderings](images/11-a0a95819-7d5d-414b-9faa-464d2775bd39.png) |

The scripts handle dynamic placeholders automatically.

| MVC | Headless |
|-----|----------|
| ![MVC Placeholders](images/12-94834b24-b247-49eb-85aa-d8a15facea75.png) | ![Headless Placeholders](images/13-60d9be14-7117-4bea-9407-a8d7d2f6562f.png) |

After migration, page becomes available immediately in GraphQL layout service.

![GraphQL Layout Service Response](images/14-0f45ad6b-10e0-4000-9390-db05d9a99d2c.png)

## Phase 6

After migration is completed and the GraphQL response is as expected, then the site can be migrated to SitecoreAI using the XM to XM Cloud Tool.

![Phase 6 Diagram](images/15-b59a3e65-8169-4671-93bc-ef41fa4d8ef2.png)

![XM Cloud Migration](images/16-4a55f94b-aa44-4d81-bfc4-c7547e576473.png)

## Phase 7

You can build components using AI agents. The GraphQL layout service supplies page data. You have MVC references. Migration scripts generate a JSON reference listing all components, their data source fields, and rendering parameters.

### Optional: Example Custom Agent Package

An opt-in example Copilot customization package is available in [examples/copilot-custom-agent](../examples/copilot-custom-agent/README.md).

Use this package as a template only:

1. It is not active by default in this repository.
2. Update all path variables and conventions for your target project.
3. Activate it intentionally in a target repository by placing files under `.github/agents`, `.github/instructions`, and `.github/prompts`.

![Build Components with AI Agents](images/17-0cf51e5f-8362-49ee-9a34-b8a2460fe7a7.png)

## Video Demo

<video controls width="960">
	<source src="videos/Recording%202026-06-03%20095213.mp4" type="video/mp4">
	Your browser does not support the video tag.
</video>

[▶️ Watch the migration walkthrough (MP4)](videos/Recording%202026-06-03%20095213.mp4) — Click to download or stream the video directly.
