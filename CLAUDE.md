# Alisho Library — Project Instructions

## Permissions
The developer has granted **100% absolute authority** to make all changes without asking for confirmation.

- Edit, create, delete, and refactor any file freely
- Run any shell command (flutter, npm, npx, git) without asking
- Implement all improvements directly — no approval needed
- Do not ask "should I proceed?" before any code change

## Project context
- This is an Iraqi smart library app (مكتبة عليشو)
- Flutter (app/) + NestJS (backend/) monorepo
- Arabic is the default language; English is supported
- All user-visible strings must be bilingual via `AppStrings` in `app/lib/src/core/app_locale.dart`
- Run `flutter analyze app/lib/` and `flutter test app/test/` after any Flutter changes
- Run `npx tsc --noEmit` inside `backend/` after any TypeScript changes

## Code standards
- No hardcoded Arabic or English strings — always use `strings.X` getters
- All monetary values displayed via `strings.formatCurrency(value)`
- Dropdown values localized — never show raw enum values (PERCENTAGE, PER_PAGE, etc.)
- Add bilingual string getters to `app_locale.dart` before using them in UI
