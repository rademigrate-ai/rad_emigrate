# Destination photography inventory

Country and World Time cards use repository-bundled, deterministic editorial
photographs under `assets/images/destinations/`. Source identifiers are kept in
the Git history and the corresponding mappings are stored in:

- `lib/features/visa/presentation/widgets/country_photography.dart`
- `lib/features/global_time/presentation/widgets/city_clock_card.dart`

These images are used under the [Unsplash License](https://unsplash.com/license).
They are editorial destination context only and do not imply an immigration
outcome, eligibility, or service availability.

The source files were downloaded from `images.unsplash.com` during development
and are used under the [Unsplash License](https://unsplash.com/license).

Bundled source identifiers:

| Asset | Unsplash photo ID |
| --- | --- |
| `at.jpg` | `photo-1516550893923-42d28e5677af` |
| `au.jpg` | `photo-1506973035872-a4ec16b8e8d9` |
| `ca.jpg` | `photo-1517935706615-2717063c2225` |
| `ch.jpg` | `photo-1527668752968-14dc70a27c95` |
| `de.jpg` | `photo-1467269204594-9661b134dd2b` |
| `es.jpg` | `photo-1543783207-ec64e4d95325` |
| `fallback.jpg` | `photo-1488085061387-422e29b40080` |
| `fr.jpg` | `photo-1502602898657-3e91760cbb34` |
| `gb.jpg` | `photo-1513635269975-59663e0ac1ad` |
| `ie.jpg` | `photo-1590089415225-401ed6f9db8e` |
| `it.jpg` | `photo-1523906834658-6e24ef2386f9` |
| `jp.jpg` | `photo-1493976040374-85c8e12f0c0e` |
| `kr.jpg` | `photo-1517154421773-0529f29ea451` |
| `nl.jpg` | `photo-1534351590666-13e3e96b5017` |
| `nz.jpg` | `photo-1507699622108-4be3abd695ad` |
| `se.jpg` | `photo-1509356843151-3e7d96241e11` |
| `sg.jpg` | `photo-1525625293386-3f8f99389edd` |
| `tr.jpg` | `photo-1524231757912-21f4fe3a7200` |
| `us.jpg` | `photo-1485738422979-f5c462d49f74` |

Implementation safeguards:

- no runtime hotlink, API key, CORS request, or third-party availability is
  required;
- unsupported destinations intentionally render the bundled neutral travel
  photograph (Visa) or a branded city plate (World Time);
- missing/corrupt assets render a deliberate city/public fallback;
- no image URL is accepted from user or backend content.

The user-supplied RAD phoenix remains the only assistant identity asset. No
generated imagery or third-party logo is used for the assistant.
