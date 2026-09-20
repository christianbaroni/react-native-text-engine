# RN Text benchmark results

Latest native layout measurements for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 20, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.2.0, Release build.

| Test                            | Operations/sample |   RN Text (ms) |  TextView (ms) | TextView / RN |
| ------------------------------- | ----------------: | -------------: | -------------: | ------------: |
| Chat list layout                |               512 | 66.029 ± 0.772 | 29.424 ± 0.648 |        0.446× |
| Plain text creation and layout  |               512 | 63.934 ± 0.502 | 28.627 ± 0.546 |        0.448× |
| Cached layout                   |            98,304 | 29.678 ± 0.199 |  5.439 ± 0.176 |        0.183× |
| Cached layout, two-line limit   |            98,304 | 29.713 ± 0.162 | 14.005 ± 0.278 |        0.471× |
| Styled text creation and layout |               384 | 62.663 ± 0.578 | 27.600 ± 0.529 |        0.440× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T01:33:11.124Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `6a0896b92d03daf0f592e7317438dc5be2d0da34`
- Source checksum (SHA256): `47ff9fd6b241820c783dd528b950d8192ec4096143bc30e37a5cb0da819d2e1f`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                            | Implementation | Run | Samples (ms)                                                                                      |
| ------------------------------- | -------------- | --: | ------------------------------------------------------------------------------------------------- |
| Chat list layout                | RN Text        |   1 | 67.528375, 65.337209, 65.200458, 65.188750, 65.121667, 64.972000, 64.816458, 64.953416, 64.852959 |
| Chat list layout                | RN Text        |   2 | 65.085750, 66.029333, 65.637000, 65.597417, 66.214875, 66.081917, 66.114583, 65.747041, 66.908167 |
| Chat list layout                | RN Text        |   3 | 66.801084, 66.068125, 67.095958, 67.364709, 65.689042, 67.518084, 67.187125, 66.166458, 66.324041 |
| Chat list layout                | TextView       |   1 | 29.119667, 29.025625, 28.935500, 28.708750, 28.763959, 28.685125, 28.693792, 28.776875, 28.940084 |
| Chat list layout                | TextView       |   2 | 29.329333, 29.296875, 29.799208, 29.160375, 29.512375, 29.424375, 29.976791, 29.299708, 29.828875 |
| Chat list layout                | TextView       |   3 | 29.697917, 29.126625, 30.353000, 30.111291, 29.924875, 30.074375, 30.077792, 30.400833, 30.639667 |
| Plain text creation and layout  | RN Text        |   1 | 62.519542, 62.577500, 62.270542, 62.446667, 62.258541, 62.460500, 62.380000, 62.610833, 62.411250 |
| Plain text creation and layout  | RN Text        |   2 | 64.147291, 63.933958, 64.332292, 63.577792, 63.835542, 63.863458, 65.452709, 63.635250, 64.366750 |
| Plain text creation and layout  | RN Text        |   3 | 63.136667, 64.915834, 64.300458, 63.825458, 64.436125, 64.458375, 63.888750, 64.931708, 64.728000 |
| Plain text creation and layout  | TextView       |   1 | 27.526875, 27.454666, 27.556834, 27.622916, 27.498375, 27.445459, 27.682583, 27.661541, 27.616459 |
| Plain text creation and layout  | TextView       |   2 | 28.067959, 28.444625, 28.764333, 28.157166, 28.978875, 28.781125, 28.454584, 28.829833, 28.627042 |
| Plain text creation and layout  | TextView       |   3 | 29.215959, 29.145000, 29.173541, 28.352667, 29.466625, 28.972125, 27.974750, 29.982750, 29.998875 |
| Cached layout                   | RN Text        |   1 | 28.077167, 28.028625, 28.478833, 28.291208, 28.165125, 28.414125, 28.242333, 28.222666, 28.555667 |
| Cached layout                   | RN Text        |   2 | 30.343708, 30.011917, 29.877250, 29.767083, 29.852875, 29.877375, 29.922166, 29.878959, 29.873584 |
| Cached layout                   | RN Text        |   3 | 29.998292, 28.930167, 29.678125, 29.929625, 29.373958, 28.503708, 29.654833, 30.902500, 29.820000 |
| Cached layout                   | TextView       |   1 | 5.277625, 5.282625, 5.263833, 5.228750, 4.978709, 5.319417, 5.504333, 5.191875, 5.098083          |
| Cached layout                   | TextView       |   2 | 5.339875, 5.439416, 5.737334, 5.906542, 5.314000, 5.340750, 5.629750, 5.467666, 5.327875          |
| Cached layout                   | TextView       |   3 | 5.661541, 5.887167, 5.587375, 5.386708, 5.792750, 5.988583, 5.474625, 6.605042, 5.751334          |
| Cached layout, two-line limit   | RN Text        |   1 | 28.199208, 27.906708, 28.631791, 28.202750, 28.739167, 28.401625, 28.542833, 28.998209, 28.220542 |
| Cached layout, two-line limit   | RN Text        |   2 | 29.795000, 30.080333, 29.914333, 29.313583, 29.652250, 29.907125, 29.297459, 29.238750, 29.712625 |
| Cached layout, two-line limit   | RN Text        |   3 | 30.326250, 29.684250, 30.026625, 29.211709, 29.874750, 29.715375, 30.294833, 29.803000, 30.059542 |
| Cached layout, two-line limit   | TextView       |   1 | 13.726542, 13.844542, 13.328083, 13.824500, 13.208416, 13.575083, 13.741708, 13.358792, 13.772333 |
| Cached layout, two-line limit   | TextView       |   2 | 14.004958, 13.930250, 13.966542, 14.336583, 13.882042, 13.779041, 14.294917, 14.257792, 14.132250 |
| Cached layout, two-line limit   | TextView       |   3 | 14.870125, 14.328417, 14.557917, 14.679834, 14.675667, 14.692750, 14.853333, 14.800166, 15.097625 |
| Styled text creation and layout | RN Text        |   1 | 60.953041, 61.116709, 60.837375, 60.902334, 60.896334, 61.126542, 61.004542, 61.201792, 61.311084 |
| Styled text creation and layout | RN Text        |   2 | 62.211250, 62.977916, 62.903917, 61.836875, 62.986250, 62.859750, 62.602417, 62.110208, 62.663333 |
| Styled text creation and layout | RN Text        |   3 | 66.699041, 65.026500, 63.241084, 63.068834, 63.148208, 62.015166, 63.731750, 63.641583, 63.148917 |
| Styled text creation and layout | TextView       |   1 | 26.904291, 27.143750, 26.959458, 26.846417, 27.047084, 26.940708, 27.120250, 26.862542, 26.900000 |
| Styled text creation and layout | TextView       |   2 | 26.795458, 27.778958, 27.518875, 27.757125, 27.652083, 27.596208, 27.562458, 27.600250, 27.683750 |
| Styled text creation and layout | TextView       |   3 | 28.609500, 28.637541, 28.099959, 28.129000, 28.428417, 27.721250, 28.503209, 27.796667, 27.639584 |

</details>

## Android

September 20, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.2.0, Release build.

### RN Text with default layout

| Test                                     | Operations/sample |    RN Text (ms) |   TextView (ms) | TextView / RN |
| ---------------------------------------- | ----------------: | --------------: | --------------: | ------------: |
| Chat list layout                         |               512 | 153.988 ± 0.150 | 102.212 ± 0.025 |        0.664× |
| Plain text creation and layout           |               512 | 141.053 ± 0.231 |  95.206 ± 0.421 |        0.675× |
| Repeated manager queries                 |             6,144 |   3.914 ± 0.021 |   1.501 ± 0.013 |        0.383× |
| Repeated manager queries, two-line limit |             6,144 |   3.927 ± 0.020 |   1.713 ± 0.090 |        0.436× |
| Styled text creation and layout          |               384 | 317.635 ± 0.718 | 190.156 ± 0.137 |        0.599× |

### RN Text with prepared layout

| Test                                     | Operations/sample |     RN Text (ms) |   TextView (ms) | TextView / RN |
| ---------------------------------------- | ----------------: | ---------------: | --------------: | ------------: |
| Chat list layout                         |               512 |  157.801 ± 0.126 | 102.159 ± 0.069 |        0.647× |
| Plain text creation and layout           |               512 |  145.035 ± 0.153 |  95.307 ± 0.079 |        0.657× |
| Repeated manager queries                 |             6,144 | 1742.709 ± 1.084 |   1.469 ± 0.001 |        0.001× |
| Repeated manager queries, two-line limit |             6,144 | 1828.632 ± 2.282 |   1.632 ± 0.002 |        0.001× |
| Styled text creation and layout          |               384 |  298.379 ± 0.126 | 177.608 ± 0.198 |        0.595× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T01:46:08.639Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `7dd7923f84e8e4a3fcad713e35a49785db764f1425f8252f5f6e974db2009130`
- Git HEAD: `efe0398c2aff25108098328482746e54c4a5373a`
- Source checksum (SHA256): `f8c83d04b61e23c7a99b12cf03584dcf372897fc9649eeb8999678114cb0fa43`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test                                     | Implementation | RN configuration | Run | Samples (ms)                                                                                                        |
| ---------------------------------------- | -------------- | ---------------- | --: | ------------------------------------------------------------------------------------------------------------------- |
| Chat list layout                         | RN Text        | Default          |   1 | 156.132324, 153.803182, 152.978556, 154.569824, 153.532553, 153.988119, 154.356975, 153.440715, 155.017008          |
| Chat list layout                         | RN Text        | Default          |   2 | 158.004516, 152.464641, 153.036540, 159.652832, 152.888916, 153.214559, 155.026977, 152.847249, 154.780843          |
| Chat list layout                         | RN Text        | Default          |   3 | 155.175171, 154.190552, 153.276896, 156.857625, 153.326131, 154.138224, 154.377808, 153.709758, 153.290731          |
| Chat list layout                         | RN Text        | Prepared         |   1 | 157.675293, 159.287842, 156.822266, 157.504964, 157.227051, 158.586589, 157.411051, 158.648030, 159.590129          |
| Chat list layout                         | RN Text        | Prepared         |   2 | 156.806722, 156.698283, 159.358358, 158.247721, 157.217733, 159.850546, 159.319906, 158.262573, 160.434895          |
| Chat list layout                         | RN Text        | Prepared         |   3 | 157.159221, 158.327799, 157.126140, 159.459879, 157.800822, 157.040650, 155.804688, 158.437053, 158.352539          |
| Chat list layout                         | TextView       | Default          |   1 | 102.510050, 101.939046, 102.392618, 102.211751, 101.969686, 101.929403, 104.203125, 102.182658, 102.303060          |
| Chat list layout                         | TextView       | Default          |   2 | 103.492024, 102.284302, 101.611736, 101.569173, 102.177327, 102.186971, 102.639974, 101.015055, 102.307902          |
| Chat list layout                         | TextView       | Default          |   3 | 101.855997, 102.378743, 102.835286, 102.761271, 102.248007, 102.187419, 104.591715, 102.270915, 102.285929          |
| Chat list layout                         | TextView       | Prepared         |   1 | 101.927287, 102.095581, 102.159139, 102.101196, 102.538411, 102.427897, 102.387044, 101.927490, 102.195964          |
| Chat list layout                         | TextView       | Prepared         |   2 | 101.826782, 102.416179, 102.581543, 102.612020, 102.126058, 102.263834, 102.259644, 102.408976, 102.689250          |
| Chat list layout                         | TextView       | Prepared         |   3 | 101.347494, 101.816324, 101.754598, 104.533854, 102.218221, 102.874593, 102.145874, 101.622070, 102.089641          |
| Plain text creation and layout           | RN Text        | Default          |   1 | 140.892334, 141.027547, 140.943645, 142.604777, 141.942667, 143.718547, 142.354370, 141.052857, 140.830078          |
| Plain text creation and layout           | RN Text        | Default          |   2 | 140.434855, 136.440023, 137.299724, 141.019653, 139.066121, 141.496541, 141.629191, 140.822143, 141.607422          |
| Plain text creation and layout           | RN Text        | Default          |   3 | 141.513794, 141.353719, 141.422770, 142.763876, 142.028117, 141.318400, 141.109334, 137.943685, 141.143270          |
| Plain text creation and layout           | RN Text        | Prepared         |   1 | 143.872436, 148.045532, 144.054810, 145.442709, 144.881714, 145.378581, 144.750692, 145.100749, 144.820557          |
| Plain text creation and layout           | RN Text        | Prepared         |   2 | 145.704834, 145.198934, 145.349406, 145.521606, 145.493490, 147.565714, 145.784545, 145.494344, 148.778850          |
| Plain text creation and layout           | RN Text        | Prepared         |   3 | 143.995035, 145.467204, 146.136556, 145.034791, 144.815877, 144.611776, 144.713054, 145.097371, 147.148926          |
| Plain text creation and layout           | TextView       | Default          |   1 | 96.907796, 95.114176, 96.737223, 95.206177, 95.192789, 95.248576, 94.819499, 95.928386, 95.065105                   |
| Plain text creation and layout           | TextView       | Default          |   2 | 91.479289, 91.260661, 91.728068, 90.901977, 91.754435, 95.351074, 97.312175, 95.314127, 95.491252                   |
| Plain text creation and layout           | TextView       | Default          |   3 | 94.740316, 95.664632, 95.578654, 95.630493, 95.690877, 95.502197, 95.627523, 96.450236, 95.411621                   |
| Plain text creation and layout           | TextView       | Prepared         |   1 | 95.221150, 95.407715, 95.201457, 95.311076, 96.596110, 92.942017, 95.163167, 95.306641, 95.402507                   |
| Plain text creation and layout           | TextView       | Prepared         |   2 | 95.385457, 95.302938, 95.551961, 95.373128, 95.598632, 93.131225, 95.680908, 92.066406, 95.824341                   |
| Plain text creation and layout           | TextView       | Prepared         |   3 | 95.059489, 95.198039, 95.093303, 95.030436, 95.022787, 96.042603, 95.081625, 95.097860, 94.897380                   |
| Repeated manager queries                 | RN Text        | Default          |   1 | 3.785075, 3.794922, 3.701172, 3.853109, 3.861898, 3.966268, 3.968059, 3.968506, 3.949382                            |
| Repeated manager queries                 | RN Text        | Default          |   2 | 4.129395, 3.879110, 4.467488, 3.889323, 3.898518, 4.400594, 3.914103, 3.891601, 3.930502                            |
| Repeated manager queries                 | RN Text        | Default          |   3 | 3.898234, 4.000366, 3.908447, 3.963663, 3.935181, 3.963501, 3.913655, 4.007365, 3.905721                            |
| Repeated manager queries                 | RN Text        | Prepared         |   1 | 1751.483480, 1740.691529, 1734.430664, 1740.497966, 1731.681682, 1735.404461, 1724.817668, 1724.485027, 1722.172730 |
| Repeated manager queries                 | RN Text        | Prepared         |   2 | 1757.306682, 1751.522055, 1742.193645, 1745.481649, 1745.804078, 1743.793173, 1733.685670, 1730.348674, 1728.974081 |
| Repeated manager queries                 | RN Text        | Prepared         |   3 | 1752.982545, 1745.314006, 1742.172527, 1742.732015, 1742.708863, 1744.161703, 1722.740845, 1724.304445, 1721.895713 |
| Repeated manager queries                 | TextView       | Default          |   1 | 1.487671, 1.486003, 1.486003, 1.464356, 1.526571, 1.474406, 1.492188, 1.489991, 1.491211                            |
| Repeated manager queries                 | TextView       | Default          |   2 | 1.508911, 1.514689, 1.470744, 1.500895, 1.464477, 1.518189, 1.493164, 1.487834, 1.529663                            |
| Repeated manager queries                 | TextView       | Default          |   3 | 1.668010, 1.670817, 1.679077, 1.689005, 1.655477, 1.620361, 1.680867, 1.652507, 1.701701                            |
| Repeated manager queries                 | TextView       | Prepared         |   1 | 1.472046, 1.502197, 1.461507, 1.439657, 1.470459, 1.492269, 1.483887, 1.445801, 1.446574                            |
| Repeated manager queries                 | TextView       | Prepared         |   2 | 1.468872, 1.494914, 1.464355, 1.469238, 1.455892, 1.507893, 1.461792, 1.472046, 1.479858                            |
| Repeated manager queries                 | TextView       | Prepared         |   3 | 1.449504, 1.439575, 1.481811, 1.443482, 1.478719, 1.449219, 1.469523, 1.443441, 1.461874                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   1 | 3.900309, 3.988648, 3.911784, 3.960124, 3.940592, 3.960002, 3.901408, 4.012818, 3.982829                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   2 | 3.966919, 3.882405, 3.927246, 3.924398, 3.953369, 3.891276, 3.960327, 3.887126, 3.940755                            |
| Repeated manager queries, two-line limit | RN Text        | Default          |   3 | 3.887126, 3.927409, 3.907186, 3.933675, 3.882121, 3.973592, 3.877034, 3.971069, 3.888387                            |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   1 | 1837.406170, 1822.710653, 1827.909547, 1835.609539, 1837.784506, 1842.108033, 1829.028240, 1830.913575, 1827.229086 |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   2 | 1838.437908, 1828.541423, 1817.035198, 1819.527304, 1830.959880, 1812.241985, 1822.652345, 1798.530234, 1819.771770 |
| Repeated manager queries, two-line limit | RN Text        | Prepared         |   3 | 1830.891602, 1834.860271, 1834.656942, 1829.078858, 1818.856243, 1814.834921, 1828.632040, 1811.831828, 1813.116049 |
| Repeated manager queries, two-line limit | TextView       | Default          |   1 | 1.749878, 1.656087, 1.748413, 1.653686, 1.722494, 1.703532, 1.712931, 1.728556, 1.709961                            |
| Repeated manager queries, two-line limit | TextView       | Default          |   2 | 1.599324, 1.645508, 1.624430, 1.614625, 1.663208, 1.622762, 1.600016, 1.659342, 1.598308                            |
| Repeated manager queries, two-line limit | TextView       | Default          |   3 | 1.950196, 1.827148, 1.925497, 1.848510, 1.886433, 1.894043, 1.898763, 1.849650, 1.912150                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   1 | 1.683553, 1.621013, 1.644613, 1.646647, 2.016683, 1.630411, 1.738728, 1.635417, 1.643066                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   2 | 1.610433, 1.638143, 1.614828, 1.637696, 1.629069, 1.655110, 1.599121, 1.649129, 1.610473                            |
| Repeated manager queries, two-line limit | TextView       | Prepared         |   3 | 1.723063, 1.613444, 1.631551, 1.630493, 1.643595, 1.608805, 1.668091, 1.605062, 1.641439                            |
| Styled text creation and layout          | RN Text        | Default          |   1 | 313.505981, 315.272135, 319.828532, 314.998901, 317.522013, 318.475789, 314.108440, 315.220581, 317.319173          |
| Styled text creation and layout          | RN Text        | Default          |   2 | 320.691569, 316.956828, 317.634969, 318.514568, 320.512411, 315.229533, 323.649821, 315.617880, 316.527751          |
| Styled text creation and layout          | RN Text        | Default          |   3 | 327.170492, 322.585449, 316.295858, 318.658163, 318.088501, 318.331502, 318.352540, 318.861816, 317.903320          |
| Styled text creation and layout          | RN Text        | Prepared         |   1 | 296.613160, 297.885783, 301.357585, 299.397055, 299.663697, 298.025716, 298.253418, 300.423136, 297.450155          |
| Styled text creation and layout          | RN Text        | Prepared         |   2 | 300.384400, 298.381470, 298.685384, 298.580566, 299.052287, 301.976522, 297.308960, 299.805135, 298.500652          |
| Styled text creation and layout          | RN Text        | Prepared         |   3 | 298.944621, 299.310262, 298.348308, 298.378947, 298.375204, 300.383179, 298.699056, 296.741943, 294.401490          |
| Styled text creation and layout          | TextView       | Default          |   1 | 192.402221, 189.357422, 189.772461, 191.359049, 189.886678, 190.155924, 191.073893, 190.637370, 189.645914          |
| Styled text creation and layout          | TextView       | Default          |   2 | 189.940877, 191.714559, 190.218546, 190.000122, 189.439698, 190.881103, 189.819580, 189.547241, 192.997966          |
| Styled text creation and layout          | TextView       | Default          |   3 | 190.039754, 189.863770, 191.838256, 190.120809, 190.120443, 190.292561, 190.577719, 190.540243, 191.746460          |
| Styled text creation and layout          | TextView       | Prepared         |   1 | 177.451050, 180.774902, 177.568359, 177.468587, 177.806153, 177.990438, 178.327311, 177.054932, 177.921916          |
| Styled text creation and layout          | TextView       | Prepared         |   2 | 177.844361, 177.573812, 177.544149, 178.948690, 177.883830, 177.608480, 179.654052, 176.729371, 175.673299          |
| Styled text creation and layout          | TextView       | Prepared         |   3 | 174.967611, 176.743775, 176.260132, 178.025065, 175.087077, 176.669190, 175.511475, 174.471232, 174.695149          |

</details>
