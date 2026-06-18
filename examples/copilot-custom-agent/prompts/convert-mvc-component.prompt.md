---
description: "Convert a single Sitecore MVC Razor component to a Next.js Content SDK component. Produces the TSX file and component-map entry."
name: "Convert MVC Component to Next.js"
argument-hint: "Component name to convert (e.g. Hero, Carousel, LeftImageCTA, Navbar)"
agent: "agent"
tools: [read, search, edit, todo]
---

Convert the MVC Razor component **$args** to a Next.js TypeScript component using `@sitecore-content-sdk/nextjs`.

This is an example prompt template. If the project paths are unknown, ask for them first.

Use these path variables:

- `{{MVC_COMPONENT_FILE}}` (example: `src/mvc/components/$args.cshtml`)
- `{{LAYOUT_RESPONSE_FILES}}` (example: `layout-service/home.json`, `layout-service/about.json`)
- `{{REFERENCE_COMPONENTS_DIR}}` (optional)
- `{{INSTRUCTIONS_FILE}}` (example: `.github/instructions/mvc-to-nextjs.instructions.md`)
- `{{TARGET_COMPONENT_FILE}}` (example: `src/components/<kebab-name>/<PascalName>.tsx`)
- `{{COMPONENT_MAP_FILE}}` (example: `.sitecore/component-map.ts`)

## Steps to Follow

1. Read the MVC source file at `{{MVC_COMPONENT_FILE}}` to understand the component's fields, HTML structure, conditions, and rendering logic.

2. Read layout service response files in `{{LAYOUT_RESPONSE_FILES}}` to find JSON field shapes and confirm exact field names.

3. If available, read a similar reference component from `{{REFERENCE_COMPONENTS_DIR}}` to understand import patterns and structure conventions.

4. Read `{{INSTRUCTIONS_FILE}}` for all conversion rules before writing any code.

5. Check if a component folder already exists for the target component.

6. Create the component file at `{{TARGET_COMPONENT_FILE}}` following the instructions.

7. Show the line to add to `{{COMPONENT_MAP_FILE}}` and apply the edit.

## Expected Output

- A new `<PascalName>.tsx` file with:
  - TypeScript interfaces for params and fields
  - A named `Default` export wired to `useSitecore` for editing mode
  - Safe destructuring with fallback for missing datasource
  - All editable fields rendered via `Text`, `RichText`, `ContentSdkImage`, or `ContentSdkLink`
  - Bootstrap CSS class names preserved from MVC source

- Updated `component-map.ts` registration

- A brief field-mapping table: MVC field name → SDK type → SDK component used
