# Kraft — design spec ("Apple-premium stationery")

One page. Every colour below was sampled (region medians) from a private four-image mood board — glossy pastel tags,
die-cut sticker icons and a kraft-paper folder collage — except where marked *derived*. The references themselves are not
included because they are other artists' work. Code tokens live in `Sources/Kraft/Design/Tokens.swift`.

## Surfaces (ref-8: kraft folder collage)
| Token | Hex | Use |
|---|---|---|
| page | `#FDF6E6` | window background, warm off-white page |
| page.hi | `#FFF9E9` | page highlight |
| kraft | `#CD9059` | board + active folder tab |
| kraft.light | `#D59862` | board top light |
| kraft.deep | `#B87541` | board edge, inactive tab bottom |
| kraft.ink | `#744416` | debossed text on kraft |
| grid.paper | `#F3EBDD` | grid sheet peeking behind the board |
| grid.line | `#D2C9B8` | 12 pt grid |

Board: rounded 18 pt continuous, 1 pt `kraft.deep` edge, fibre grain overlay, a 1 pt top highlight (card thickness),
shadow `black 12% r18 y10` + contact `black 18% r1 y1`. A grid sheet sits behind it, rotated −1.2°, peeking out top/right.

## Folder tabs — navigation (ref-8)
All · Today · Money · Reminders · To-do · Notes · Done. Height 38, side slant 8, top radius 9, bottom flare 9.
Active tab = board colour, merges into the board via flares. Inactive = tucked behind: `#C99059 → #B07440`, ink at 70%.
Each tab: 15 pt die-cut sticker + 13 pt SF Pro semibold label + count.

## Glossy tags — buttons, filters, chips (ref-5)
Shape: continuous rounded rect, radius = 28 % of height. Layers: vertical fill gradient → 1 pt edge of the same hue →
top inner bevel (white 95 % → 0) → soft top sheen → drop `edge 50% y1.5` + `black 10% r6 y4`.
Text + SF Symbol in the same hue, embossed (white 1 pt highlight below).
| Tint | top | bottom | edge | ink |
|---|---|---|---|---|
| blue | `#DCEFFE` | `#CFE9FF` | `#93C3F3` | `#5390E0` |
| lime | `#EEFF8D` | `#E4F86A` | `#C4D698` | `#7A9D0F` |
| mint | `#D7FCDD` | `#C6F5CE` | `#A3E3AF` | `#27A274` |
| pink *derived* | `#FFE3EE` | `#FFD3E3` | `#F2A7C3` | `#D4497F` |
| amber *derived* | `#FFF2CC` | `#FFE7A6` | `#E8C774` | `#B07C12` |
Sizes: regular 30 pt (13 pt label), mini 22 pt (11 pt label). Pressed: scale 0.97, fill darkens 4 %.

## Die-cut stickers — kind icons, empty states, app icon (ref-6, ref-7)
Bold SF Symbol in ink `#271F2C`, over a flat colour blob that follows the glyph silhouette (dilated 20 %),
over a white die-cut outline (dilated 34 %), offset shadow `ink 22% x1.5 y2.5`, rotated −6…−10°.
| Kind | Symbol | Fill |
|---|---|---|
| Note | `square.and.pencil` | sky `#68C9F6` |
| To-do | `list.bullet` | coral `#FBA08E` |
| Reminder | `bell` | yellow `#FFD96A` |
| Owes me | `wallet.bifold` | pink `#FE93B1` |
| I owe | `creditcard` | purple `#C3A7E1` |
| Bill | `receipt` | green `#94E387` |
| Done | `checkmark` | lime `#AEFF5D` |

## Sticky notes
Paper colours (*derived*: sticker fills mixed into the page): lemon `#FFF1A8`, mint `#DDF6D2`, sky `#D8EEFC`,
pink `#FFDDE8`, peach `#FFE2CF`, lilac `#E9E0FA`, white `#FFFDF6`, + custom hex.
Sizes S 176 / M 204 / L 236 pt square, corner 3 pt. Adhesive band: top 16 % darkened 3.5 %. Grain overlay 5 %.
Lifted-corner shadow (curved bottom edge, `black 22% r7 y6`) + contact shadow. Tilt −3…+3°.
Fasteners: washi tape 72×22 (white 55 %, zig-zag ends) or glossy red pin `#FD2441`.
Ruling: none / lines 26 pt / grid 13 pt / dots.
PAID stamp: rounded 8 pt double border, SF Rounded heavy 30 pt, `#E0313F` 85 % multiply, −14°, ink grain mask.

## Type
UI: SF Pro (Latin) / SF Arabic — system font only. Board title 30 bold · tab 13 semibold · tag 13/11 semibold · meta 11 medium.
Handwriting (stickies only): Latin → Playpen Sans Arabic; Arabic → Molhim (×1.2 optical size), RTL.
Chosen by the first strong character of the text. Title 22 · body 16 · amount 34.

## Motion
Hover lifts a sticky (scale 1.02, tilt eases toward 0, shadow deepens) on a 0.35 s spring. No decorative animation.
