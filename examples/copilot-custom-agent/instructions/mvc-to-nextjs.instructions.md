---
description: "Example instructions for converting or creating Next.js components migrated from Sitecore MVC Razor. Covers field typing, Content SDK imports, editing mode, layout service field shapes, and component structure conventions."
applyTo: "src/components/**"
---

# MVC → Next.js Component Conversion Rules

This file is an example template. Adapt paths and conventions to match your target project before activation.

## Project Context

This app is a **Sitecore Content SDK (Pages Router)** Next.js app. MVC Razor components are the source of truth for structure and fields. Layout Service responses show the actual JSON field shapes delivered at runtime.

---

## 1. File & Folder Structure

- One component per folder: `src/components/<kebab-case-name>/<PascalCaseName>.tsx`
- Export `Default` as the named variant that wires `useSitecore`:

```typescript
export const Default: React.FC<HeroProps> = (props) => {
  const { page } = useSitecore();
  const { isEditing } = page.mode;
  return <HeroDefault {...props} isPageEditing={isEditing} />;
};
```

- The inner implementation component (e.g. `HeroDefault`) is not exported.
- Register in `.sitecore/component-map.ts` as `{ Default }` export.

---

## 2. Imports

```typescript
import type React from 'react';
import {
  Text,
  RichText,
  Image,
  NextImage as ContentSdkImage,
  Link as ContentSdkLink,
  Field,
  ImageField,
  LinkField,
  useSitecore,
} from '@sitecore-content-sdk/nextjs';
import { ComponentProps } from 'lib/component-props';
```

- Never import from `/config`, `/config-cli`, `/tools`, or `/client` submodules in component files.
- Use `NextImage` (aliased as `ContentSdkImage`) for images — it supports inline editing and wraps Next.js `Image`.
- Use `Link` (aliased as `ContentSdkLink`) for internal/external links.

---

## 3. Props Interface Pattern

```typescript
// Params: accept any rendering parameter keys
interface HeroParams {
  [key: string]: string;
}

// Field types: derived from layout service JSON + MVC model
interface HeroFields {
  Title?: { jsonValue: Field<string> };
  Subtitle?: { jsonValue: Field<string> };
  Image?: { jsonValue: ImageField };
  TargetPage?: { jsonValue: LinkField };
}

// Component props
interface HeroProps extends ComponentProps {
  params: HeroParams;
  fields?: {
    data?: {
      datasource?: HeroFields;
    };
  };
  isPageEditing?: boolean;
}
```

**Field type mapping from MVC → SDK:**

| MVC Razor field | Layout Service shape | SDK type |
|---|---|---|
| `Model.Title` (string) | `{ "value": "..." }` | `Field<string>` |
| `Model.Content` (RichText) | `{ "value": "<p>...</p>" }` | `Field<string>` → `<RichText>` |
| `Model.Image` (image) | `{ "value": { "src": "...", "alt": "..." } }` | `ImageField` |
| `Model.TargetPage` (link) | `{ "value": { "href": "...", "text": "..." } }` | `LinkField` |
| `Model.TargetUrl` (general link) | `{ "value": { "href": "...", "text": "...", "target": "..." } }` | `LinkField` |
| Items / child list (`Model.Slides`) | `"fields": { "items": [ ... ] }` | `Array<{ fields: ... }>` |

---

## 4. Datasource Guard

Always guard against missing datasource before destructuring:

```typescript
const HeroDefault: React.FC<HeroProps> = ({ fields, isPageEditing }) => {
  const { data } = fields || {};
  const { datasource } = data || {};

  if (!datasource && !isPageEditing) {
    return (
      <div className="component hero">
        <span className="is-empty-hint">Hero</span>
      </div>
    );
  }

  const { Title, Subtitle, Image: HeroImage } = datasource || {};
  // ...
};
```

---

## 5. Editing Mode

MVC uses `Sitecore.Context.PageMode.IsExperienceEditor` to conditionally render empty fields. Replicate this with `isPageEditing`:

**MVC pattern:**
```cshtml
@if (Sitecore.Context.PageMode.IsExperienceEditor || !string.IsNullOrWhiteSpace(Model.Title))
{
    <h1>@Html.Sitecore().Edit(Model, m => m.Title)</h1>
}
```

**Next.js equivalent:**
```typescript
{(Title?.jsonValue?.value || isPageEditing) && (
  <Text tag="h1" field={Title?.jsonValue} />
)}
```

---

## 6. Image Rendering

Always use `ContentSdkImage` (which is `NextImage` from the SDK):

```typescript
// Inline editable image:
<ContentSdkImage field={HeroImage?.jsonValue} className="img-fluid" />
```

For hero-style background images, use a wrapper `div` with inline style only when the MVC source uses `style="background-image:..."`:

```typescript
const bgUrl = HeroImage?.jsonValue?.value?.src;
<div className="jumbotron jumbotron-fluid" style={bgUrl ? { backgroundImage: `url(${bgUrl})` } : undefined}>
```

---

## 7. Link Rendering

**Internal `TargetPage` links** from MVC map to `LinkField`. Use `ContentSdkLink`:

```typescript
{TargetPage?.jsonValue?.value?.href && (
  <ContentSdkLink field={TargetPage.jsonValue} className="btn btn-info" />
)}
```

When MVC falls back to `TargetUrl` if `TargetPage` is null, reproduce the same fallback:

```typescript
const linkField = TargetPage?.jsonValue?.value?.href
  ? TargetPage.jsonValue
  : TargetUrl?.jsonValue;

{linkField?.value?.href && (
  <ContentSdkLink field={linkField} className="btn btn-info" />
)}
```

---

## 8. List / Children Components (e.g. Carousel Slides)

When MVC iterates `Model.Slides` or `Model.GetChildren()`, the layout service delivers an `items` array on the component's `fields`:

```typescript
interface SlideFields {
  Title?: Field<string>;
  Subtitle?: Field<string>;
  Image?: ImageField;
}

interface CarouselFields {
  items: Array<{
    id: string;
    fields: SlideFields;
  }>;
}
```

Iterate with standard `.map()` and use SDK field components per item.

---

## 9. CSS Classes

Preserve Bootstrap class names from the MVC source exactly, adding Tailwind utilities only if the project already uses them in existing components. Do not introduce new Tailwind classes unless explicitly requested.

---

## 10. Dictionary (i18n)

MVC uses `Html.Sitecore().Dictionary("/Buttons/Read More", "Read more")`. In Next.js, use `next-localization`:

```typescript
import { useI18n } from 'next-localization';

const { t } = useI18n();
const readMoreText = t('Buttons_ReadMore') || 'Read more';
```

If the key is not yet defined in the dictionary JSON, add a code comment `// TODO: add dictionary key Buttons_ReadMore`.

---

## 11. `withDatasourceCheck` vs Manual Guard

Prefer the **manual guard** (section 4) for components that have complex empty-state rendering. Use `withDatasourceCheck()` only for simple components where the default "Configure a Data Source" message is acceptable.

---

## 12. Component Map Registration

After creating the component, add to `.sitecore/component-map.ts`:

```typescript
import * as Hero from 'components/hero/Hero';
// ...
export const components = new Map<string, unknown>([
  ['Hero', Hero],
  // ...
]);
```

The map key must match the `componentName` value from the layout service response JSON exactly.
