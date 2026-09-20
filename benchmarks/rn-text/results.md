# RN Text benchmark results

Latest native measurement, mounting, and drawing results for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 20, 2026. iPhone 17 Pro simulator, iOS 26.2. React Native 0.87.1, Text Engine 0.2.0, Release build.

| Test                                      | Operations/sample |    RN Text (ms) |   TextView (ms) | TextView / RN |
| ----------------------------------------- | ----------------: | --------------: | --------------: | ------------: |
| Chat list layout                          |               512 |  68.637 ± 0.201 |  23.222 ± 0.195 |        0.338× |
| Native layout, mount, and first draw      |               512 | 322.727 ± 0.312 | 266.196 ± 0.008 |        0.825× |
| Retained paragraph measurement            |            16,384 |  12.630 ± 0.210 |   0.214 ± 0.001 |        0.017× |
| Short labels, natural line height         |               512 |  13.970 ± 0.148 |   5.851 ± 0.053 |        0.419× |
| Plain text creation and layout            |               512 |  65.662 ± 0.416 |  21.914 ± 0.140 |        0.334× |
| Manager queries, 768 keys                 |            98,304 |  43.953 ± 0.604 |   7.578 ± 0.128 |        0.172× |
| Manager queries, 768 keys, two-line limit |            98,304 |  43.871 ± 0.038 |  20.078 ± 0.344 |        0.458× |
| Styled text creation and layout           |               384 |  69.283 ± 0.460 |  26.760 ± 0.055 |        0.386× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T06:31:23.995-04:00
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphonesimulator26.2; Node v22.21.1
- Git HEAD: `a55036ffbc91a43a20f571d6ad38ce1480a7028a`
- Source checksum (SHA256): `6db2d6121913f15c0515bf7a597e15340b3d749d65fb2f923e40d18e48f0a21e`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                                      | Implementation | Run | Samples (ms)                                                                                               |
| ----------------------------------------- | -------------- | --: | ---------------------------------------------------------------------------------------------------------- |
| Chat list layout                          | RN Text        |   1 | 68.838625, 71.128083, 72.306166, 68.872291, 67.985667, 69.366375, 68.129458, 68.085959, 67.963083          |
| Chat list layout                          | RN Text        |   2 | 68.775250, 68.921458, 71.347625, 67.880083, 67.932792, 67.749833, 67.859334, 67.743791, 69.117875          |
| Chat list layout                          | RN Text        |   3 | 68.748500, 68.637250, 69.647750, 68.530834, 68.173542, 68.332375, 68.966084, 69.059375, 68.112583          |
| Chat list layout                          | TextView       |   1 | 23.241708, 23.222042, 24.392750, 23.758959, 23.068416, 23.039959, 23.149459, 22.939041, 24.276334          |
| Chat list layout                          | TextView       |   2 | 23.083375, 24.183417, 23.397792, 23.022833, 22.853958, 23.225083, 22.963209, 23.027333, 22.940792          |
| Chat list layout                          | TextView       |   3 | 23.494750, 23.365042, 24.588125, 23.741833, 23.261917, 23.194041, 24.282500, 23.632541, 24.523250          |
| Native layout, mount, and first draw      | RN Text        |   1 | 318.795416, 320.311584, 329.015041, 321.107875, 322.849542, 321.202834, 323.117792, 320.128708, 322.226459 |
| Native layout, mount, and first draw      | RN Text        |   2 | 319.759416, 330.668000, 321.064583, 323.008917, 324.180917, 321.087250, 326.344083, 322.106625, 322.726625 |
| Native layout, mount, and first draw      | RN Text        |   3 | 324.189708, 320.478458, 322.308750, 322.985250, 323.764209, 323.038375, 341.497042, 323.284000, 319.076417 |
| Native layout, mount, and first draw      | TextView       |   1 | 265.930291, 263.635125, 276.754791, 275.067125, 266.351208, 266.196250, 264.557708, 264.983083, 268.024666 |
| Native layout, mount, and first draw      | TextView       |   2 | 263.063875, 264.730750, 269.150125, 272.410250, 267.199709, 264.864042, 269.545875, 266.203958, 265.215583 |
| Native layout, mount, and first draw      | TextView       |   3 | 265.741375, 269.183917, 266.010375, 265.656667, 265.886291, 267.748875, 267.092083, 264.916084, 272.571166 |
| Retained paragraph measurement            | RN Text        |   1 | 12.742417, 12.630375, 12.595167, 12.524750, 12.629250, 12.808208, 12.813833, 12.756167, 12.593125          |
| Retained paragraph measurement            | RN Text        |   2 | 12.831791, 12.840000, 12.849541, 12.834250, 12.857208, 12.819500, 12.847167, 12.840250, 12.867500          |
| Retained paragraph measurement            | RN Text        |   3 | 12.017334, 12.017959, 12.029125, 12.012458, 12.003291, 12.033791, 11.795084, 11.772833, 12.017833          |
| Retained paragraph measurement            | TextView       |   1 | 0.211042, 0.210208, 0.223458, 0.216167, 0.214834, 0.214583, 0.219500, 0.214750, 0.212333                   |
| Retained paragraph measurement            | TextView       |   2 | 0.209792, 0.210333, 0.209917, 0.209959, 0.209125, 0.211500, 0.210291, 0.211125, 0.210208                   |
| Retained paragraph measurement            | TextView       |   3 | 0.215833, 0.213917, 0.214917, 0.214167, 0.214333, 0.214042, 0.212958, 0.213875, 0.215792                   |
| Short labels, natural line height         | RN Text        |   1 | 14.333375, 14.117750, 14.440625, 14.500250, 13.901167, 14.255041, 14.055542, 13.755625, 13.641834          |
| Short labels, natural line height         | RN Text        |   2 | 13.466583, 13.337000, 13.530792, 13.386542, 13.490375, 13.403625, 13.967375, 13.413209, 13.500417          |
| Short labels, natural line height         | RN Text        |   3 | 13.642209, 13.598209, 13.519167, 14.344417, 15.038542, 14.112750, 14.047000, 13.969500, 13.560292          |
| Short labels, natural line height         | TextView       |   1 | 6.193167, 5.885916, 6.135792, 6.023500, 5.903625, 6.044792, 5.800708, 5.668250, 5.786917                   |
| Short labels, natural line height         | TextView       |   2 | 5.767583, 5.836417, 5.734875, 5.823875, 5.786000, 5.810083, 5.748083, 5.820916, 5.757292                   |
| Short labels, natural line height         | TextView       |   3 | 5.850667, 5.783542, 5.814667, 5.791125, 6.235292, 6.199666, 6.188709, 5.985417, 5.827875                   |
| Plain text creation and layout            | RN Text        |   1 | 65.805375, 67.623000, 69.370125, 65.637375, 66.074041, 70.115084, 67.982958, 67.963792, 66.751959          |
| Plain text creation and layout            | RN Text        |   2 | 66.346625, 67.976708, 65.390375, 65.203625, 67.541041, 65.230666, 65.246208, 65.102458, 64.954208          |
| Plain text creation and layout            | RN Text        |   3 | 65.705542, 65.558625, 65.518125, 65.483417, 65.662458, 67.512042, 68.174166, 65.677792, 65.313208          |
| Plain text creation and layout            | TextView       |   1 | 21.842167, 21.650625, 21.910791, 21.639334, 22.948667, 22.969167, 22.443208, 22.796958, 22.054375          |
| Plain text creation and layout            | TextView       |   2 | 21.647833, 22.040083, 21.928083, 22.084125, 22.224125, 21.913875, 21.754833, 21.813125, 21.729625          |
| Plain text creation and layout            | TextView       |   3 | 21.677875, 21.647375, 21.630000, 21.760708, 21.571292, 21.542750, 21.728542, 21.664875, 21.582125          |
| Manager queries, 768 keys                 | RN Text        |   1 | 46.234959, 44.848625, 45.010625, 45.058209, 45.335250, 48.751125, 48.140250, 48.224208, 46.620125          |
| Manager queries, 768 keys                 | RN Text        |   2 | 43.786041, 43.793959, 44.186667, 43.776791, 44.918292, 44.808750, 43.969625, 43.952917, 43.835833          |
| Manager queries, 768 keys                 | RN Text        |   3 | 43.600417, 43.348833, 43.254500, 43.253417, 43.684291, 43.009167, 43.038750, 43.862917, 45.030709          |
| Manager queries, 768 keys                 | TextView       |   1 | 7.450791, 7.443083, 7.440708, 7.399167, 7.411542, 7.515750, 8.361667, 8.325458, 8.080333                   |
| Manager queries, 768 keys                 | TextView       |   2 | 7.705125, 7.735250, 7.459750, 7.576958, 7.649625, 7.578375, 7.514042, 7.553417, 7.661583                   |
| Manager queries, 768 keys                 | TextView       |   3 | 7.780334, 7.726375, 7.798708, 7.733833, 7.753750, 7.704875, 7.840625, 7.811333, 7.966500                   |
| Manager queries, 768 keys, two-line limit | RN Text        |   1 | 45.912000, 45.209125, 44.032417, 44.813333, 43.481167, 43.480958, 43.502208, 43.520375, 43.871209          |
| Manager queries, 768 keys, two-line limit | RN Text        |   2 | 44.573208, 45.199833, 44.750292, 44.527083, 44.876416, 44.538333, 44.494084, 45.546416, 44.139791          |
| Manager queries, 768 keys, two-line limit | RN Text        |   3 | 45.326958, 44.032208, 43.842375, 43.758708, 43.744000, 43.653667, 44.127292, 43.833209, 43.649583          |
| Manager queries, 768 keys, two-line limit | TextView       |   1 | 20.960125, 20.947500, 20.193292, 20.213333, 20.015666, 20.078084, 19.667417, 19.715584, 20.048458          |
| Manager queries, 768 keys, two-line limit | TextView       |   2 | 20.665834, 21.403917, 20.856042, 20.425875, 20.324042, 20.112333, 20.031292, 20.570625, 20.029209          |
| Manager queries, 768 keys, two-line limit | TextView       |   3 | 19.852583, 19.843333, 19.670667, 19.568542, 19.598958, 19.734208, 20.138791, 19.794208, 19.705083          |
| Styled text creation and layout           | RN Text        |   1 | 70.053000, 72.377042, 69.577250, 68.822458, 68.436667, 70.607334, 68.281458, 68.623250, 68.358625          |
| Styled text creation and layout           | RN Text        |   2 | 69.357875, 69.101833, 70.090417, 70.234334, 69.833125, 69.449583, 69.093666, 70.597375, 71.230959          |
| Styled text creation and layout           | RN Text        |   3 | 69.367042, 69.629459, 69.574209, 71.363333, 69.226292, 69.246916, 69.010625, 69.282584, 69.187791          |
| Styled text creation and layout           | TextView       |   1 | 27.330959, 27.659375, 26.639541, 26.681334, 26.580417, 27.030417, 26.517625, 26.489917, 26.539750          |
| Styled text creation and layout           | TextView       |   2 | 26.654458, 26.760375, 26.707458, 27.089583, 27.256208, 26.714583, 26.645042, 27.586125, 27.902875          |
| Styled text creation and layout           | TextView       |   3 | 26.839291, 26.746875, 27.243250, 27.261542, 26.921583, 26.716292, 26.778917, 26.734709, 26.815667          |

</details>

## Android

September 20, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.2.0, Release build.

### RN Text with default layout

| Test                                      | Operations/sample |    RN Text (ms) |   TextView (ms) | TextView / RN |
| ----------------------------------------- | ----------------: | --------------: | --------------: | ------------: |
| Chat list layout                          |               512 | 153.262 ± 0.061 | 105.646 ± 0.016 |        0.689× |
| Native layout, mount, and first draw      |               512 | 892.899 ± 0.755 | 433.754 ± 0.146 |        0.486× |
| Retained paragraph measurement            |            16,384 |  19.205 ± 0.202 |   5.916 ± 0.020 |        0.308× |
| Short labels, natural line height         |               512 |  53.647 ± 0.064 |  37.144 ± 0.090 |        0.692× |
| Plain text creation and layout            |               512 | 141.358 ± 0.127 |  97.729 ± 0.125 |        0.691× |
| Manager queries, 768 keys                 |             6,144 |   3.901 ± 0.006 |   1.477 ± 0.000 |        0.378× |
| Manager queries, 768 keys, two-line limit |             6,144 |   3.905 ± 0.001 |   1.609 ± 0.017 |        0.412× |
| Styled text creation and layout           |               384 | 317.251 ± 0.207 | 190.069 ± 0.670 |        0.599× |

### RN Text with prepared layout

| Test                                      | Operations/sample |     RN Text (ms) |   TextView (ms) | TextView / RN |
| ----------------------------------------- | ----------------: | ---------------: | --------------: | ------------: |
| Chat list layout                          |               512 |  160.039 ± 0.078 | 105.966 ± 0.130 |        0.662× |
| Native layout, mount, and first draw      |               512 |  450.216 ± 1.132 | 435.373 ± 0.806 |        0.967× |
| Retained paragraph measurement            |            16,384 |    0.242 ± 0.001 |   5.984 ± 0.033 |       24.769× |
| Short labels, natural line height         |               512 |   58.103 ± 0.060 |  37.137 ± 0.018 |        0.639× |
| Plain text creation and layout            |               512 |  145.591 ± 0.201 |  97.893 ± 0.326 |        0.672× |
| Manager queries, 768 keys                 |             6,144 | 1744.242 ± 0.877 |   1.477 ± 0.005 |        0.001× |
| Manager queries, 768 keys, two-line limit |             6,144 | 1829.725 ± 4.496 |   1.597 ± 0.001 |        0.001× |
| Styled text creation and layout           |               384 |  298.585 ± 1.372 | 189.372 ± 0.056 |        0.634× |

The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T10:30:29.733Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `78c0f7e2ca688b2f5f4c3f631843df257eaa75ed002f8802a492cbe34a6c9cc5`
- Git HEAD: `a55036ffbc91a43a20f571d6ad38ce1480a7028a`
- Source checksum (SHA256): `97e9431968a13a3c17f291ff407784139c1cd7e13b4786fbbd1091fa64e194f3`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                                      | Implementation | RN configuration | Run | Samples (ms)                                                                                                        |
| ----------------------------------------- | -------------- | ---------------- | --: | ------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                          | RN Text        | Default          |   1 | 153.462280, 153.354533, 153.460978, 153.924235, 155.933431, 153.910197, 153.872437, 153.439209, 156.761190          |
| Chat list layout                          | RN Text        | Default          |   2 | 152.913330, 153.181845, 153.048665, 153.261597, 156.421387, 153.540609, 153.871908, 153.047567, 153.672404          |
| Chat list layout                          | RN Text        | Default          |   3 | 153.217001, 153.073568, 152.771444, 152.947388, 156.183512, 153.200643, 153.417481, 152.732341, 155.611003          |
| Chat list layout                          | RN Text        | Prepared         |   1 | 159.256267, 162.680868, 158.142700, 160.327514, 159.440877, 159.741821, 161.484416, 159.721395, 159.028890          |
| Chat list layout                          | RN Text        | Prepared         |   2 | 158.528321, 162.228800, 166.032634, 160.117106, 160.082560, 160.118774, 161.434896, 160.048665, 159.055379          |
| Chat list layout                          | RN Text        | Prepared         |   3 | 159.703980, 160.699219, 160.565267, 160.137451, 160.039266, 159.774496, 161.278077, 159.409749, 158.538208          |
| Chat list layout                          | TextView       | Default          |   1 | 105.498291, 105.136475, 106.048014, 105.133504, 106.155111, 105.373942, 106.420940, 105.646159, 106.218343          |
| Chat list layout                          | TextView       | Default          |   2 | 108.921753, 103.133789, 106.694051, 106.534302, 106.174561, 105.924602, 106.551595, 105.614664, 106.869874          |
| Chat list layout                          | TextView       | Default          |   3 | 105.307577, 105.100057, 105.970214, 105.273193, 106.255697, 105.192505, 106.461466, 105.630005, 106.056396          |
| Chat list layout                          | TextView       | Prepared         |   1 | 105.581828, 105.966349, 106.542969, 105.469646, 106.343181, 105.899130, 106.239543, 106.988078, 105.704468          |
| Chat list layout                          | TextView       | Prepared         |   2 | 106.374797, 106.698445, 106.668091, 106.253296, 106.391520, 106.510579, 106.360271, 110.709106, 107.084676          |
| Chat list layout                          | TextView       | Prepared         |   3 | 106.117432, 104.985270, 106.301147, 104.921346, 105.836141, 105.312052, 108.787068, 104.760579, 106.009888          |
| Native layout, mount, and first draw      | RN Text        | Default          |   1 | 813.429973, 835.814982, 858.095297, 882.653077, 914.873576, 951.318889, 912.141277, 931.045370, 956.994304          |
| Native layout, mount, and first draw      | RN Text        | Default          |   2 | 820.464274, 889.432821, 843.906495, 867.933879, 892.143514, 910.392131, 936.192791, 960.065674, 1082.053915         |
| Native layout, mount, and first draw      | RN Text        | Default          |   3 | 802.425212, 819.486776, 847.479696, 866.563965, 892.898927, 916.394247, 1002.005168, 916.620768, 938.475871         |
| Native layout, mount, and first draw      | RN Text        | Prepared         |   1 | 454.419597, 450.554403, 451.548584, 462.915527, 451.347982, 448.995483, 455.501791, 449.626303, 451.138997          |
| Native layout, mount, and first draw      | RN Text        | Prepared         |   2 | 449.297729, 448.809408, 447.782105, 447.863852, 447.186524, 447.350220, 449.042928, 447.211141, 448.103760          |
| Native layout, mount, and first draw      | RN Text        | Prepared         |   3 | 448.743164, 450.216471, 451.845825, 449.795288, 449.433268, 452.532715, 450.426189, 448.853964, 452.689046          |
| Native layout, mount, and first draw      | TextView       | Default          |   1 | 438.746257, 433.359619, 434.669637, 435.837281, 438.420451, 430.699341, 430.415324, 432.357991, 433.753948          |
| Native layout, mount, and first draw      | TextView       | Default          |   2 | 436.370158, 433.607992, 433.893962, 433.303142, 433.680217, 432.340373, 432.376587, 433.482056, 434.462037          |
| Native layout, mount, and first draw      | TextView       | Default          |   3 | 433.744060, 436.072144, 438.948283, 433.146281, 434.003377, 435.251180, 436.340047, 441.208659, 433.949504          |
| Native layout, mount, and first draw      | TextView       | Prepared         |   1 | 432.980754, 433.233317, 434.651490, 436.178589, 438.648112, 432.868368, 445.047364, 442.332438, 437.053589          |
| Native layout, mount, and first draw      | TextView       | Prepared         |   2 | 435.372884, 439.233073, 435.755250, 434.530436, 434.564657, 433.552124, 436.220988, 435.804850, 435.017293          |
| Native layout, mount, and first draw      | TextView       | Prepared         |   3 | 433.739299, 433.824423, 437.860759, 432.162842, 432.529297, 433.864909, 434.797892, 439.175089, 432.172323          |
| Retained paragraph measurement            | RN Text        | Default          |   1 | 18.919148, 18.980631, 18.841837, 18.916871, 18.894653, 18.881714, 18.846924, 18.983317, 19.087443                   |
| Retained paragraph measurement            | RN Text        | Default          |   2 | 19.127238, 19.244100, 19.214722, 19.104370, 19.263957, 19.168987, 19.205444, 19.051025, 19.228679                   |
| Retained paragraph measurement            | RN Text        | Default          |   3 | 19.382202, 19.414917, 19.407755, 19.398804, 19.395915, 19.420858, 19.360433, 19.526367, 19.415852                   |
| Retained paragraph measurement            | RN Text        | Prepared         |   1 | 0.241455, 0.241740, 0.241333, 0.241903, 0.261759, 0.241577, 0.241618, 0.241455, 0.241333                            |
| Retained paragraph measurement            | RN Text        | Prepared         |   2 | 0.245890, 0.264730, 0.245890, 0.246094, 0.245565, 0.245687, 0.245890, 0.245565, 0.245524                            |
| Retained paragraph measurement            | RN Text        | Prepared         |   3 | 0.240804, 0.241008, 0.240600, 0.240560, 0.240926, 0.240600, 0.240804, 0.240763, 0.241048                            |
| Retained paragraph measurement            | TextView       | Default          |   1 | 5.898356, 5.900675, 5.941975, 5.913208, 5.986694, 5.936239, 5.944621, 5.897827, 6.029093                            |
| Retained paragraph measurement            | TextView       | Default          |   2 | 5.827759, 5.787679, 5.820394, 6.005656, 5.796753, 5.833943, 5.814697, 5.824951, 5.908406                            |
| Retained paragraph measurement            | TextView       | Default          |   3 | 5.968343, 5.916341, 5.947998, 5.934042, 5.975830, 5.887207, 5.879842, 5.891032, 5.914062                            |
| Retained paragraph measurement            | TextView       | Prepared         |   1 | 5.956218, 5.951131, 5.994466, 5.905273, 5.908081, 5.931722, 5.885579, 5.955607, 6.001018                            |
| Retained paragraph measurement            | TextView       | Prepared         |   2 | 6.022135, 5.983643, 6.002278, 5.913208, 5.941732, 5.892782, 6.038737, 5.961101, 6.058105                            |
| Retained paragraph measurement            | TextView       | Prepared         |   3 | 6.284749, 6.227051, 6.250569, 6.174072, 6.255249, 6.238241, 6.163900, 6.263672, 6.223673                            |
| Short labels, natural line height         | RN Text        | Default          |   1 | 53.918539, 53.856689, 53.671469, 53.583090, 53.582967, 59.970907, 51.651775, 51.672119, 50.592366                   |
| Short labels, natural line height         | RN Text        | Default          |   2 | 54.042277, 53.829305, 53.534465, 53.678874, 53.684896, 56.109050, 53.240885, 53.719197, 54.031331                   |
| Short labels, natural line height         | RN Text        | Default          |   3 | 53.909627, 53.767579, 53.646932, 53.466878, 53.610311, 55.287679, 51.613688, 53.645305, 53.869832                   |
| Short labels, natural line height         | RN Text        | Prepared         |   1 | 58.230917, 58.046753, 58.128458, 58.071655, 62.039836, 58.162720, 58.190267, 58.195679, 58.156046                   |
| Short labels, natural line height         | RN Text        | Prepared         |   2 | 57.988241, 58.006185, 57.758422, 57.613160, 60.550578, 58.887614, 57.755656, 58.083944, 58.075236                   |
| Short labels, natural line height         | RN Text        | Prepared         |   3 | 58.177287, 58.103109, 58.015991, 57.845337, 58.227620, 59.516765, 57.115723, 58.208090, 58.098104                   |
| Short labels, natural line height         | TextView       | Default          |   1 | 37.192546, 37.212077, 37.099528, 37.129232, 37.144491, 37.232137, 39.671265, 35.219930, 35.041788                   |
| Short labels, natural line height         | TextView       | Default          |   2 | 37.420085, 37.615885, 38.269409, 37.437663, 34.798177, 37.059245, 37.272542, 37.172119, 37.236003                   |
| Short labels, natural line height         | TextView       | Default          |   3 | 37.145060, 37.054891, 37.134684, 36.925415, 37.025472, 37.111572, 39.491578, 34.182820, 35.297933                   |
| Short labels, natural line height         | TextView       | Prepared         |   1 | 37.361857, 37.401937, 39.484945, 35.032227, 35.236898, 37.164307, 37.251831, 37.214315, 37.176676                   |
| Short labels, natural line height         | TextView       | Prepared         |   2 | 37.050497, 37.119791, 37.581095, 38.688111, 34.584798, 36.746704, 37.199300, 37.198527, 37.103679                   |
| Short labels, natural line height         | TextView       | Prepared         |   3 | 36.616781, 37.155965, 37.137329, 37.120850, 37.099447, 37.152750, 37.076864, 37.181478, 39.591105                   |
| Plain text creation and layout            | RN Text        | Default          |   1 | 142.000081, 141.737956, 141.976156, 141.939616, 144.452636, 142.339030, 141.599040, 141.714885, 144.541626          |
| Plain text creation and layout            | RN Text        | Default          |   2 | 141.411255, 141.275920, 141.091308, 140.990560, 143.585246, 142.007446, 141.358195, 141.162313, 143.775553          |
| Plain text creation and layout            | RN Text        | Default          |   3 | 141.393555, 141.231487, 141.117188, 141.132853, 141.887858, 141.805257, 141.114136, 140.929891, 143.608073          |
| Plain text creation and layout            | RN Text        | Prepared         |   1 | 148.572754, 145.112060, 145.610880, 140.828857, 147.148641, 142.103272, 143.783122, 145.665040, 145.591105          |
| Plain text creation and layout            | RN Text        | Prepared         |   2 | 146.295085, 146.076741, 145.792236, 145.355957, 145.493123, 146.083049, 145.796793, 145.569946, 145.378581          |
| Plain text creation and layout            | RN Text        | Prepared         |   3 | 146.639119, 145.092774, 145.536824, 145.235636, 145.364624, 147.798136, 145.536052, 145.313476, 144.978394          |
| Plain text creation and layout            | TextView       | Default          |   1 | 97.728881, 99.124430, 95.896200, 97.961018, 97.727295, 97.644409, 97.819092, 97.734294, 97.689290                   |
| Plain text creation and layout            | TextView       | Default          |   2 | 98.561767, 96.720906, 97.930176, 97.949138, 97.786499, 98.213705, 98.135742, 98.045532, 98.018839                   |
| Plain text creation and layout            | TextView       | Default          |   3 | 97.538167, 98.180704, 96.250935, 98.017253, 97.603394, 97.486532, 97.549764, 97.661906, 98.085693                   |
| Plain text creation and layout            | TextView       | Prepared         |   1 | 98.058390, 97.856933, 97.857910, 97.849162, 98.145427, 97.892904, 97.929850, 97.802816, 98.004150                   |
| Plain text creation and layout            | TextView       | Prepared         |   2 | 98.269491, 98.383422, 98.508830, 98.339600, 98.204142, 98.625529, 98.211263, 98.421876, 98.006633                   |
| Plain text creation and layout            | TextView       | Prepared         |   3 | 97.570923, 97.566935, 97.725830, 97.778850, 97.473185, 97.271241, 97.233765, 97.816609, 97.561565                   |
| Manager queries, 768 keys                 | RN Text        | Default          |   1 | 3.918295, 3.902099, 3.888713, 3.893596, 3.892618, 3.915975, 3.879639, 3.895671, 3.950440                            |
| Manager queries, 768 keys                 | RN Text        | Default          |   2 | 3.904459, 3.906087, 3.906575, 3.934408, 3.919515, 3.910564, 3.909220, 3.951009, 3.890991                            |
| Manager queries, 768 keys                 | RN Text        | Default          |   3 | 3.889771, 3.897989, 3.901246, 3.962931, 3.905314, 3.896728, 3.901205, 3.929810, 3.892537                            |
| Manager queries, 768 keys                 | RN Text        | Prepared         |   1 | 1751.574789, 1748.810467, 1743.410889, 1744.241781, 1742.586752, 1759.726401, 1744.333945, 1736.415162, 1734.151938 |
| Manager queries, 768 keys                 | RN Text        | Prepared         |   2 | 1755.124187, 1743.364869, 1742.106772, 1747.796550, 1742.576580, 1745.710287, 1743.773154, 1736.973755, 1730.554851 |
| Manager queries, 768 keys                 | RN Text        | Prepared         |   3 | 1752.527019, 1745.999879, 1747.239787, 1749.383220, 1747.487997, 1743.602296, 1742.198325, 1734.129517, 1735.003419 |
| Manager queries, 768 keys                 | TextView       | Default          |   1 | 1.464722, 1.574341, 1.476888, 1.464518, 1.485473, 1.477661, 1.454956, 1.480265, 1.476156                            |
| Manager queries, 768 keys                 | TextView       | Default          |   2 | 1.471273, 1.468180, 1.598552, 1.470378, 1.476603, 1.511230, 1.467977, 1.516683, 1.477905                            |
| Manager queries, 768 keys                 | TextView       | Default          |   3 | 1.569132, 1.450236, 1.473022, 1.473511, 1.446126, 1.487305, 1.459554, 1.453125, 1.490560                            |
| Manager queries, 768 keys                 | TextView       | Prepared         |   1 | 1.557861, 1.473266, 1.462931, 1.506552, 1.463216, 1.476970, 1.577718, 1.467733, 1.510010                            |
| Manager queries, 768 keys                 | TextView       | Prepared         |   2 | 1.463745, 1.457683, 1.592529, 1.482178, 1.462280, 1.506469, 1.543905, 1.498982, 1.479696                            |
| Manager queries, 768 keys                 | TextView       | Prepared         |   3 | 1.439413, 1.465821, 1.498861, 1.440877, 1.462727, 1.471802, 1.458496, 1.464396, 1.446737                            |
| Manager queries, 768 keys, two-line limit | RN Text        | Default          |   1 | 3.897990, 3.905681, 3.937378, 3.903402, 3.901733, 3.905395, 3.933227, 3.904135, 3.910034                            |
| Manager queries, 768 keys, two-line limit | RN Text        | Default          |   2 | 4.019816, 3.921427, 3.902059, 3.901571, 3.919190, 3.900635, 3.891480, 3.904785, 3.938843                            |
| Manager queries, 768 keys, two-line limit | RN Text        | Default          |   3 | 3.901611, 3.909790, 3.908854, 3.943156, 3.905599, 3.912231, 3.919189, 3.930746, 3.917684                            |
| Manager queries, 768 keys, two-line limit | RN Text        | Prepared         |   1 | 2388.733888, 1832.742392, 1826.399415, 1828.462037, 1830.992392, 1826.901450, 1824.382772, 1831.556845, 1829.724976 |
| Manager queries, 768 keys, two-line limit | RN Text        | Prepared         |   2 | 1824.837485, 1825.487875, 1827.552410, 1823.982015, 1823.209881, 2350.611411, 1825.414308, 1824.929770, 1811.136882 |
| Manager queries, 768 keys, two-line limit | RN Text        | Prepared         |   3 | 1849.186362, 1834.221070, 1833.909424, 1845.404217, 1834.652914, 1822.644654, 1825.807578, 1823.303752, 1836.394003 |
| Manager queries, 768 keys, two-line limit | TextView       | Default          |   1 | 1.595459, 1.626749, 1.600057, 1.692424, 1.744181, 1.791910, 4.041951, 1.619466, 1.590617                            |
| Manager queries, 768 keys, two-line limit | TextView       | Default          |   2 | 1.593669, 1.622233, 1.609457, 1.595622, 1.743164, 1.605265, 1.628052, 1.613647, 1.600504                            |
| Manager queries, 768 keys, two-line limit | TextView       | Default          |   3 | 1.775839, 3.724121, 1.577189, 1.566284, 1.608968, 1.546875, 1.566162, 1.540446, 1.569458                            |
| Manager queries, 768 keys, two-line limit | TextView       | Prepared         |   1 | 1.625977, 1.596476, 1.597372, 1.633382, 1.590088, 1.630859, 1.594564, 1.593221, 1.718872                            |
| Manager queries, 768 keys, two-line limit | TextView       | Prepared         |   2 | 1.629395, 1.593099, 1.618164, 1.594645, 1.579549, 1.716878, 1.590454, 1.617717, 1.596680                            |
| Manager queries, 768 keys, two-line limit | TextView       | Prepared         |   3 | 1.630493, 1.585571, 1.718628, 1.595988, 1.585775, 1.642252, 1.592652, 1.612915, 1.608643                            |
| Styled text creation and layout           | RN Text        | Default          |   1 | 315.150268, 317.250651, 317.910645, 314.423218, 317.802816, 315.846558, 319.482788, 316.076253, 318.545085          |
| Styled text creation and layout           | RN Text        | Default          |   2 | 317.044068, 316.003337, 317.099081, 316.078816, 317.623698, 315.624471, 318.426635, 316.206258, 318.732748          |
| Styled text creation and layout           | RN Text        | Default          |   3 | 318.470215, 320.558553, 314.914510, 322.657756, 322.617188, 315.791382, 321.104940, 315.020304, 319.389039          |
| Styled text creation and layout           | RN Text        | Prepared         |   1 | 297.680298, 298.584758, 300.008667, 297.949544, 300.776978, 297.716431, 302.146403, 300.026368, 297.545573          |
| Styled text creation and layout           | RN Text        | Prepared         |   2 | 301.074503, 300.337809, 295.006511, 300.446656, 294.931275, 297.124146, 295.744344, 294.949422, 297.080159          |
| Styled text creation and layout           | RN Text        | Prepared         |   3 | 296.116984, 302.148560, 302.018596, 297.740356, 301.309001, 296.263875, 299.956380, 301.779419, 297.260620          |
| Styled text creation and layout           | TextView       | Default          |   1 | 190.815796, 190.444703, 190.429118, 192.711263, 190.738973, 191.043945, 190.644694, 193.795736, 190.486084          |
| Styled text creation and layout           | TextView       | Default          |   2 | 189.046265, 189.253378, 193.511231, 189.442261, 189.018677, 189.355428, 192.300415, 188.743124, 188.937703          |
| Styled text creation and layout           | TextView       | Default          |   3 | 189.833414, 189.820231, 189.438395, 194.681641, 190.093221, 190.083007, 190.068970, 192.680705, 190.062011          |
| Styled text creation and layout           | TextView       | Prepared         |   1 | 189.134400, 191.877441, 189.600342, 189.267497, 188.973674, 190.066854, 194.330078, 189.372477, 189.157715          |
| Styled text creation and layout           | TextView       | Prepared         |   2 | 190.114218, 190.035360, 191.220662, 190.668660, 190.410156, 190.208374, 192.364787, 190.968547, 190.651693          |
| Styled text creation and layout           | TextView       | Prepared         |   3 | 190.619100, 189.477051, 189.270101, 188.820882, 188.789632, 191.788412, 189.503051, 189.316976, 188.878174          |

</details>
