# Finoteku design direction

Personal finance app for everyday Indonesian users: logging money in and out quickly and seeing where it went. The design is **calm and sharp**: quiet surfaces, one strong accent, numbers as the focal point.

Dial: ENERGY 2 / RHYTHM 2 / MOTION 1

## Identity
- **Motif: the number is the hero.** Amounts are large, tabular, and the "Rp" sits smaller and muted before them. Used the same way for balances, totals, list rows and detail screens, so every screen reads money the same way.
- **Typeface: Plus Jakarta Sans.** Made for Jakarta's city identity, so it fits an Indonesian product without being a generic default. Tabular figures (`FontFeature.tabularFigures()`) on every amount so rupiah columns line up.
- **Icons: Phosphor.** Regular weight by default, Fill for the active tab and selected items, so state reads from shape and not from colour alone.

## Palette (2 core + 1 accent, plus money colours)
| Role | Light | Dark | Why |
|---|---|---|---|
| Background | `#F6F5F2` warm off-white | `#131211` warm near-black | warm neutrals feel less clinical than pure grey; easy on the eyes for daily use |
| Surface (cards, sheets) | `#FFFFFF` | `#1B1A18` | one step up from the background; separation by tone and a hairline, not shadow |
| Hairline | `#E4E1DA` | `#2E2C28` | |
| Text / muted text | `#1C1B19` / `#64605A` | `#F2F0EB` / `#A9A49A` | muted passes AA (5.7:1 / 7.5:1) |
| **Accent** | `#1F56C9` | `#8EB0FF` | deeper than the old iOS blue so it reads as Finoteku's own; used for primary actions, active tab, selected filter. Not for decoration. |
| Income | `#1D7444` | `#62CC8E` | |
| Expense | `#BE3A2F` | `#FF7B6E` | |

All text pairs checked: ≥ 4.5:1 (AA).

## Shape and depth
- Radius scale: 16 for full-width blocks and sheets, 12 for cards and list groups, 10 for chips, inputs and buttons. Nothing pill-shaped except the FAB.
- Depth: surfaces sit flat with a hairline. Shadow only on what floats: FAB, bottom sheets, dialogs.

## Layout
- Screens open with a plain title and the one number that matters (balance, period total).
- Lists are grouped by date with quiet sticky headers; rows are 56dp+ with the amount right-aligned.
- Filters are a row of chips under the header; an active chip shows its value and a clear (×).
- Spacing scale 4 / 8 / 12 / 16 / 24 / 32. Sections are separated by 24, items inside by 8–12.

## Motion
Hover/press feedback and standard route and sheet transitions only. No loops, no entrance animations.

## Copy
Indonesian first, short and concrete. No emoji in UI text. Buttons say the action ("Simpan transaksi", "Pilih kategori").
