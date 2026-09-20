# RN Text benchmark results

Latest native measurement, mounting, and drawing results for TextView and React Native's `Text`. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. The ratio is TextView time divided by RN Text time: 0.5× means half the time.

## iOS

September 20, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.2.0, Release build.

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 72.207 ± 0.444 | 31.897 ± 0.711 | 0.442× |
| Native layout, mount, and first draw | 512 | 284.807 ± 2.384 | 247.118 ± 1.528 | 0.868× |
| Retained paragraph measurement | 16,384 | 8.733 ± 0.090 | 0.180 ± 0.007 | 0.021× |
| Short labels, natural line height | 512 | 11.802 ± 0.061 | 5.049 ± 0.003 | 0.428× |
| Plain text creation and layout | 512 | 68.749 ± 2.283 | 30.836 ± 0.771 | 0.449× |
| Manager queries, 768 keys | 98,304 | 32.341 ± 0.553 | 5.965 ± 0.265 | 0.184× |
| Manager queries, 768 keys, two-line limit | 98,304 | 32.085 ± 0.098 | 15.211 ± 0.075 | 0.474× |
| Styled text creation and layout | 384 | 67.462 ± 1.252 | 28.605 ± 1.159 | 0.424× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T14:55:55.929Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `c1745f16c611856714b4e8f876aa89e907b0f9bc`
- Source checksum (SHA256): `41711f05e7709787b4e70c54d62f839bd2f78df926a47afa52f9b9c38e5ccdcb`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | Run | Samples (ms) |
| --- | --- | ---: | --- |
| Chat list layout | RN Text | 1 | 74.469708, 69.072208, 68.129375, 69.931125, 70.171625, 69.706000, 68.111166, 65.568667, 66.193958 |
| Chat list layout | RN Text | 2 | 80.340167, 75.076458, 72.207250, 71.585584, 72.340625, 71.948791, 71.937500, 72.127375, 72.356209 |
| Chat list layout | RN Text | 3 | 74.836125, 72.239708, 75.065708, 72.650875, 74.582792, 72.175042, 72.209041, 72.069167, 72.918792 |
| Chat list layout | TextView | 1 | 29.884250, 29.915125, 30.874791, 30.411042, 30.469750, 30.431000, 28.634916, 28.929708, 29.780833 |
| Chat list layout | TextView | 2 | 37.083583, 32.929791, 31.416250, 32.640292, 31.806125, 32.198917, 32.655500, 32.607250, 32.104667 |
| Chat list layout | TextView | 3 | 31.522583, 31.661917, 31.896666, 31.328750, 32.828917, 31.719375, 32.430042, 32.105083, 32.713333 |
| Native layout, mount, and first draw | RN Text | 1 | 266.064958, 266.241541, 266.271167, 266.016250, 267.644958, 266.535125, 268.337625, 266.259459, 267.571417 |
| Native layout, mount, and first draw | RN Text | 2 | 283.981250, 285.262458, 282.445417, 291.231666, 282.702375, 283.215084, 289.712250, 284.807000, 285.664292 |
| Native layout, mount, and first draw | RN Text | 3 | 292.984666, 288.650000, 284.490792, 286.177709, 283.559708, 287.191416, 286.376750, 288.357917, 288.851334 |
| Native layout, mount, and first draw | TextView | 1 | 230.240417, 230.615958, 228.753416, 229.669000, 232.475666, 230.775875, 231.790500, 233.165958, 235.655708 |
| Native layout, mount, and first draw | TextView | 2 | 246.801917, 246.088458, 244.994584, 249.967125, 243.821875, 250.270375, 254.220833, 247.118209, 249.064416 |
| Native layout, mount, and first draw | TextView | 3 | 248.645916, 247.663209, 250.519875, 247.956292, 248.663625, 247.100125, 250.754875, 246.083583, 249.854083 |
| Retained paragraph measurement | RN Text | 1 | 8.619958, 8.566292, 8.609916, 8.356500, 8.373333, 8.367833, 8.273791, 8.346541, 8.335667 |
| Retained paragraph measurement | RN Text | 2 | 9.259833, 8.834917, 8.927166, 8.732791, 8.447375, 8.573292, 8.756583, 8.675709, 8.628667 |
| Retained paragraph measurement | RN Text | 3 | 9.166750, 8.699209, 9.383000, 8.903125, 9.040334, 8.822875, 8.672833, 8.701875, 8.464000 |
| Retained paragraph measurement | TextView | 1 | 0.183708, 0.184083, 0.171417, 0.170959, 0.174666, 0.177000, 0.171042, 0.171375, 0.173542 |
| Retained paragraph measurement | TextView | 2 | 0.206791, 0.186916, 0.183167, 0.180292, 0.192500, 0.174125, 0.177542, 0.179917, 0.179833 |
| Retained paragraph measurement | TextView | 3 | 0.184667, 0.184500, 0.203750, 0.202667, 0.202875, 0.202917, 0.203792, 0.191708, 0.187000 |
| Short labels, natural line height | RN Text | 1 | 11.416333, 11.346792, 11.546250, 11.566792, 11.242917, 11.115541, 11.470125, 11.048500, 10.995166 |
| Short labels, natural line height | RN Text | 2 | 11.801667, 11.655792, 11.912000, 11.587042, 11.849167, 11.656042, 11.870917, 11.598084, 11.842416 |
| Short labels, natural line height | RN Text | 3 | 12.009333, 11.843666, 12.215041, 11.768208, 11.773459, 11.862500, 11.881667, 11.897000, 11.826583 |
| Short labels, natural line height | TextView | 1 | 4.698209, 4.907000, 4.685208, 4.723791, 5.017416, 4.938125, 4.725417, 4.656333, 4.723333 |
| Short labels, natural line height | TextView | 2 | 4.864125, 5.038000, 5.128292, 5.113625, 5.048667, 5.135708, 4.992416, 5.032375, 5.135375 |
| Short labels, natural line height | TextView | 3 | 5.161917, 5.346084, 4.969458, 4.907000, 5.109250, 4.999792, 5.051959, 5.133709, 5.013417 |
| Plain text creation and layout | RN Text | 1 | 65.795958, 62.798292, 63.330875, 65.320209, 63.301667, 63.641208, 65.273958, 63.352083, 63.551958 |
| Plain text creation and layout | RN Text | 2 | 68.339542, 68.859000, 68.842666, 68.841416, 68.667000, 69.462708, 68.569167, 68.749000, 68.731833 |
| Plain text creation and layout | RN Text | 3 | 70.544334, 71.148792, 70.844708, 71.235000, 70.353125, 71.269458, 71.140083, 70.490625, 71.032333 |
| Plain text creation and layout | TextView | 1 | 29.300750, 28.844500, 28.822958, 30.108083, 28.523125, 28.585833, 29.725500, 28.138583, 28.414583 |
| Plain text creation and layout | TextView | 2 | 31.995917, 30.866958, 30.596625, 30.823333, 30.963250, 31.546500, 30.681625, 30.798459, 30.836167 |
| Plain text creation and layout | TextView | 3 | 31.917834, 30.802084, 31.607583, 31.498459, 33.293291, 32.411625, 31.596541, 31.224167, 31.815459 |
| Manager queries, 768 keys | RN Text | 1 | 32.159542, 31.181958, 30.843125, 31.092458, 30.852333, 30.231458, 29.876166, 31.192459, 31.050167 |
| Manager queries, 768 keys | RN Text | 2 | 35.161000, 34.304459, 32.894250, 33.357375, 33.602125, 32.722959, 32.761208, 32.591917, 31.294916 |
| Manager queries, 768 keys | RN Text | 3 | 32.584291, 31.412167, 31.614708, 32.539541, 32.402292, 33.022917, 31.880417, 32.341083, 32.233875 |
| Manager queries, 768 keys | TextView | 1 | 5.924625, 5.849750, 5.478875, 5.431667, 5.633291, 5.541250, 5.282541, 5.895542, 5.439167 |
| Manager queries, 768 keys | TextView | 2 | 5.936917, 6.277125, 6.503958, 6.268500, 5.910709, 6.231875, 5.983250, 6.229958, 6.024334 |
| Manager queries, 768 keys | TextView | 3 | 6.046292, 6.119916, 5.920917, 5.964500, 5.943209, 5.702792, 6.071208, 5.825875, 6.173666 |
| Manager queries, 768 keys, two-line limit | RN Text | 1 | 30.047500, 29.849667, 29.985458, 30.325542, 31.272917, 30.574291, 30.838167, 29.566625, 29.913542 |
| Manager queries, 768 keys, two-line limit | RN Text | 2 | 33.040166, 33.544000, 32.469167, 31.939375, 30.949959, 31.339292, 31.450333, 32.891708, 32.084917 |
| Manager queries, 768 keys, two-line limit | RN Text | 3 | 30.700583, 31.075292, 33.522417, 32.182666, 32.411083, 32.358000, 30.870375, 31.410209, 33.121375 |
| Manager queries, 768 keys, two-line limit | TextView | 1 | 13.621958, 13.680208, 14.055333, 13.882750, 14.110833, 14.098042, 14.009250, 13.846042, 13.786333 |
| Manager queries, 768 keys, two-line limit | TextView | 2 | 15.174833, 15.808208, 15.549750, 15.609083, 14.644292, 14.808583, 14.839292, 15.285208, 15.817291 |
| Manager queries, 768 keys, two-line limit | TextView | 3 | 14.956000, 14.949917, 15.213958, 15.210625, 16.037958, 15.263708, 14.788250, 14.789291, 15.234750 |
| Styled text creation and layout | RN Text | 1 | 62.109667, 62.093750, 64.718584, 62.242166, 62.199250, 64.645292, 62.747708, 62.590166, 62.494167 |
| Styled text creation and layout | RN Text | 2 | 68.273833, 67.462292, 66.455125, 67.857833, 67.421625, 65.768333, 68.209958, 67.635625, 66.556500 |
| Styled text creation and layout | RN Text | 3 | 70.253000, 67.206875, 67.721584, 70.231625, 67.601250, 68.714125, 67.004833, 69.879375, 69.793625 |
| Styled text creation and layout | TextView | 1 | 26.854250, 26.936917, 27.874209, 26.585042, 27.013541, 27.375417, 27.047875, 26.893750, 27.403625 |
| Styled text creation and layout | TextView | 2 | 28.580000, 28.605333, 28.521750, 29.220000, 29.513542, 28.681875, 28.403167, 29.237458, 28.495291 |
| Styled text creation and layout | TextView | 3 | 29.910041, 29.494167, 28.703500, 28.620208, 29.686958, 29.764542, 32.113459, 30.563958, 29.822792 |

</details>

## Android

September 20, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.2.0, Release build.

### RN Text with default layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 153.469 ± 0.079 | 105.434 ± 0.030 | 0.687× |
| Native layout, mount, and first draw | 512 | 904.485 ± 3.481 | 436.308 ± 0.109 | 0.482× |
| Retained paragraph measurement | 16,384 | 18.985 ± 0.004 | 0.831 ± 0.004 | 0.044× |
| Short labels, natural line height | 512 | 53.756 ± 0.147 | 37.239 ± 0.068 | 0.693× |
| Plain text creation and layout | 512 | 141.296 ± 0.077 | 97.726 ± 0.032 | 0.692× |
| Manager queries, 768 keys | 6,144 | 3.892 ± 0.005 | 1.458 ± 0.002 | 0.375× |
| Manager queries, 768 keys, two-line limit | 6,144 | 3.902 ± 0.022 | 1.597 ± 0.001 | 0.409× |
| Styled text creation and layout | 384 | 316.464 ± 0.358 | 189.785 ± 0.778 | 0.600× |

### RN Text with prepared layout

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 160.230 ± 0.304 | 105.751 ± 0.305 | 0.660× |
| Native layout, mount, and first draw | 512 | 449.736 ± 1.029 | 433.348 ± 0.203 | 0.964× |
| Retained paragraph measurement | 16,384 | 0.244 ± 0.002 | 0.819 ± 0.000 | 3.359× |
| Short labels, natural line height | 512 | 58.120 ± 0.085 | 37.249 ± 0.039 | 0.641× |
| Plain text creation and layout | 512 | 145.805 ± 0.068 | 98.039 ± 0.222 | 0.672× |
| Manager queries, 768 keys | 6,144 | 1751.748 ± 0.404 | 1.461 ± 0.006 | 0.001× |
| Manager queries, 768 keys, two-line limit | 6,144 | 1840.737 ± 7.573 | 1.581 ± 0.015 | 0.001× |
| Styled text creation and layout | 384 | 297.951 ± 0.357 | 189.157 ± 0.055 | 0.635× |

The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-20T15:01:33.647Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `583b41067534f85ba5b14fd05bd12175c8939f96c36c73c61847da3b95509d3c`
- Git HEAD: `c1745f16c611856714b4e8f876aa89e907b0f9bc`
- Source checksum (SHA256): `07a65c953b3f7eb07d2bf0d3209adad95bcae56be49d13e73460fe1de748d84b`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | RN configuration | Run | Samples (ms) |
| --- | --- | --- | ---: | --- |
| Chat list layout | RN Text | Default | 1 | 153.002075, 153.469320, 153.257649, 153.398235, 156.994914, 154.402954, 153.485637, 152.970826, 153.931600 |
| Chat list layout | RN Text | Default | 2 | 153.103841, 153.038330, 152.910604, 152.763550, 154.253377, 153.655314, 153.390462, 153.473064, 154.640136 |
| Chat list layout | RN Text | Default | 3 | 155.041707, 153.178101, 152.968872, 153.280355, 155.093059, 153.555502, 153.624349, 153.107829, 156.678427 |
| Chat list layout | RN Text | Prepared | 1 | 159.926636, 160.685262, 161.766358, 160.697185, 159.128459, 158.787435, 162.381755, 158.300049, 157.627726 |
| Chat list layout | RN Text | Prepared | 2 | 160.533162, 160.642456, 164.765218, 161.047974, 160.496989, 160.731202, 160.772583, 162.880615, 159.264974 |
| Chat list layout | RN Text | Prepared | 3 | 160.460734, 166.008463, 159.793539, 162.249471, 160.230144, 159.633585, 162.254842, 158.182577, 159.189372 |
| Chat list layout | TextView | Default | 1 | 110.151286, 106.530273, 106.146444, 105.551799, 105.815145, 105.817952, 106.284424, 105.620890, 106.229900 |
| Chat list layout | TextView | Default | 2 | 108.323323, 103.545817, 104.976807, 105.583741, 105.354289, 105.404541, 105.302572, 105.895915, 105.696412 |
| Chat list layout | TextView | Default | 3 | 107.266561, 105.181356, 105.368856, 105.847371, 105.410523, 105.434082, 105.840657, 105.375732, 106.203817 |
| Chat list layout | TextView | Prepared | 1 | 107.121135, 105.696329, 106.056762, 108.360718, 105.717733, 108.539225, 108.433756, 105.912598, 105.694133 |
| Chat list layout | TextView | Prepared | 2 | 105.977254, 105.001302, 105.751424, 105.684204, 105.990845, 105.196086, 106.167765, 108.125854, 105.577677 |
| Chat list layout | TextView | Prepared | 3 | 105.194133, 105.287272, 105.584228, 105.445597, 106.345866, 104.912516, 105.483520, 105.856853, 105.122436 |
| Native layout, mount, and first draw | RN Text | Default | 1 | 813.571615, 871.957886, 908.559977, 907.870646, 897.093629, 914.298056, 939.792848, 968.414145, 1038.452718 |
| Native layout, mount, and first draw | RN Text | Default | 2 | 810.294027, 831.998129, 859.868897, 876.254233, 904.485433, 1008.260743, 912.238647, 931.356242, 960.974773 |
| Native layout, mount, and first draw | RN Text | Default | 3 | 819.667481, 844.804281, 901.003947, 865.515463, 909.802735, 898.715658, 990.104411, 901.958456, 932.175456 |
| Native layout, mount, and first draw | RN Text | Prepared | 1 | 450.610677, 457.577678, 451.155477, 454.889852, 453.507487, 450.765096, 449.032268, 447.305827, 447.449707 |
| Native layout, mount, and first draw | RN Text | Prepared | 2 | 453.358928, 451.226807, 448.740926, 453.504842, 449.735799, 449.423625, 449.286418, 448.662557, 450.929443 |
| Native layout, mount, and first draw | RN Text | Prepared | 3 | 442.046468, 444.946330, 446.689941, 442.780192, 445.649659, 446.348470, 445.165935, 444.034831, 442.916708 |
| Native layout, mount, and first draw | TextView | Default | 1 | 434.948201, 435.662964, 436.330607, 436.307739, 439.619832, 435.717286, 436.070068, 436.461263, 437.807699 |
| Native layout, mount, and first draw | TextView | Default | 2 | 436.626383, 445.265870, 440.298462, 435.104614, 435.028727, 435.628011, 435.999634, 441.581746, 436.416748 |
| Native layout, mount, and first draw | TextView | Default | 3 | 433.365031, 433.533366, 433.416626, 433.539633, 437.675334, 433.815186, 432.829346, 433.725382, 434.843913 |
| Native layout, mount, and first draw | TextView | Prepared | 1 | 433.279379, 432.188680, 438.771729, 433.707153, 440.646648, 432.765666, 432.232503, 433.551474, 434.417196 |
| Native layout, mount, and first draw | TextView | Prepared | 2 | 433.807781, 433.348470, 438.115275, 431.080200, 431.851278, 432.460775, 434.013346, 434.250041, 429.776205 |
| Native layout, mount, and first draw | TextView | Prepared | 3 | 432.697999, 429.752807, 431.085124, 431.584432, 432.489462, 429.485840, 430.194499, 431.277669, 431.648967 |
| Retained paragraph measurement | RN Text | Default | 1 | 19.040039, 19.001993, 19.024252, 19.022990, 19.053141, 19.060873, 19.043050, 19.158406, 19.098470 |
| Retained paragraph measurement | RN Text | Default | 2 | 18.966024, 18.980713, 18.966187, 19.002930, 18.985474, 19.009562, 18.866415, 19.039673, 19.028361 |
| Retained paragraph measurement | RN Text | Default | 3 | 18.915812, 18.943603, 18.930502, 18.981771, 18.961670, 19.013835, 18.991618, 19.044434, 19.000732 |
| Retained paragraph measurement | RN Text | Prepared | 1 | 0.251017, 0.251099, 0.250896, 0.251099, 0.251058, 0.251139, 0.266154, 0.251383, 0.250976 |
| Retained paragraph measurement | RN Text | Prepared | 2 | 0.243775, 0.243693, 0.264567, 0.243774, 0.243490, 0.243815, 0.243694, 0.243653, 0.243775 |
| Retained paragraph measurement | RN Text | Prepared | 3 | 0.241659, 0.241374, 0.241618, 0.241699, 0.241902, 0.241659, 0.241537, 0.241658, 0.241537 |
| Retained paragraph measurement | TextView | Default | 1 | 0.833089, 0.834513, 0.857015, 0.835571, 0.834431, 0.834147, 0.933715, 0.834554, 0.834757 |
| Retained paragraph measurement | TextView | Default | 2 | 0.821858, 0.822143, 0.949544, 0.824463, 0.823690, 0.824096, 0.825032, 0.864298, 0.849773 |
| Retained paragraph measurement | TextView | Default | 3 | 0.831258, 0.838623, 0.830567, 0.831014, 0.831054, 0.935588, 0.830730, 0.831462, 0.830648 |
| Retained paragraph measurement | TextView | Prepared | 1 | 0.840169, 0.812907, 0.812662, 0.812988, 0.812297, 0.903605, 0.812866, 0.812297, 0.812216 |
| Retained paragraph measurement | TextView | Prepared | 2 | 0.819173, 0.818848, 0.833211, 0.819132, 0.818929, 0.819133, 0.849366, 0.819336, 0.818970 |
| Retained paragraph measurement | TextView | Prepared | 3 | 0.819662, 0.818848, 0.818725, 0.828206, 0.837728, 0.814168, 0.814453, 0.815755, 0.930867 |
| Short labels, natural line height | RN Text | Default | 1 | 54.687662, 53.608805, 53.414103, 53.256755, 53.208089, 53.827311, 55.259277, 53.244873, 53.705648 |
| Short labels, natural line height | RN Text | Default | 2 | 54.013509, 53.993083, 53.820190, 53.825968, 53.855265, 59.163330, 53.277344, 53.972697, 53.991170 |
| Short labels, natural line height | RN Text | Default | 3 | 53.755656, 53.804769, 53.706299, 53.578165, 53.908569, 55.613444, 51.359985, 53.625163, 53.843466 |
| Short labels, natural line height | RN Text | Prepared | 1 | 57.960165, 58.088379, 57.825847, 57.838908, 60.031168, 59.636882, 57.891643, 58.064250, 57.953979 |
| Short labels, natural line height | RN Text | Prepared | 2 | 61.591105, 54.933065, 58.160766, 58.146322, 58.120036, 57.948893, 57.881062, 60.984009, 55.075521 |
| Short labels, natural line height | RN Text | Prepared | 3 | 58.205404, 58.335002, 61.041342, 57.085978, 58.217774, 58.135498, 58.068929, 58.127156, 62.220012 |
| Short labels, natural line height | TextView | Default | 1 | 37.149211, 37.245077, 37.177897, 37.239217, 37.347860, 37.232951, 37.339355, 37.210815, 39.534302 |
| Short labels, natural line height | TextView | Default | 2 | 37.098714, 37.034546, 37.165934, 37.113891, 37.192790, 37.098022, 37.231934, 37.127726, 39.628052 |
| Short labels, natural line height | TextView | Default | 3 | 37.320760, 37.307292, 37.254761, 37.330403, 37.321736, 37.208334, 39.834920, 35.842041, 35.096151 |
| Short labels, natural line height | TextView | Prepared | 1 | 39.498413, 40.029134, 36.732951, 35.175537, 36.720174, 37.454996, 37.441895, 37.435302, 37.474691 |
| Short labels, natural line height | TextView | Prepared | 2 | 37.671427, 37.602295, 41.937500, 36.826539, 37.392293, 37.249390, 37.098470, 37.092895, 37.208374 |
| Short labels, natural line height | TextView | Prepared | 3 | 37.322795, 37.261434, 39.839763, 35.833781, 36.559937, 37.112671, 37.210734, 37.087565, 37.291871 |
| Plain text creation and layout | RN Text | Default | 1 | 141.253011, 141.295776, 141.296427, 141.131551, 142.524373, 141.605550, 141.463013, 141.244344, 141.468506 |
| Plain text creation and layout | RN Text | Default | 2 | 141.067139, 141.148031, 141.185263, 141.219767, 143.079468, 141.519124, 141.065715, 141.275716, 144.239706 |
| Plain text creation and layout | RN Text | Default | 3 | 141.475098, 141.452596, 141.558675, 141.896077, 141.693645, 141.806966, 141.718018, 141.709594, 143.877604 |
| Plain text creation and layout | RN Text | Prepared | 1 | 146.264568, 145.330932, 145.872680, 145.101359, 145.291667, 142.455403, 145.960653, 142.816895, 145.534708 |
| Plain text creation and layout | RN Text | Prepared | 2 | 145.804525, 148.932658, 145.942546, 145.853149, 145.672730, 145.916992, 145.746907, 145.777629, 145.608887 |
| Plain text creation and layout | RN Text | Prepared | 3 | 149.819011, 146.221679, 145.554118, 144.992717, 144.785156, 145.787232, 145.872396, 147.409750, 148.109701 |
| Plain text creation and layout | TextView | Default | 1 | 97.783366, 97.692708, 99.293091, 95.154541, 98.091228, 97.588379, 97.694865, 97.593302, 97.630086 |
| Plain text creation and layout | TextView | Default | 2 | 97.589518, 97.525513, 98.500000, 95.682210, 97.818848, 97.716675, 97.757690, 97.809815, 97.771688 |
| Plain text creation and layout | TextView | Default | 3 | 97.725830, 97.708618, 97.070598, 98.083293, 98.166748, 97.711182, 97.785929, 97.669271, 98.044759 |
| Plain text creation and layout | TextView | Prepared | 1 | 98.480550, 98.349447, 99.221314, 98.649862, 98.781453, 99.035848, 99.705974, 99.516764, 97.667277 |
| Plain text creation and layout | TextView | Prepared | 2 | 98.038777, 97.771688, 97.739258, 99.102946, 101.437785, 98.295532, 98.965861, 97.800131, 96.987102 |
| Plain text creation and layout | TextView | Prepared | 3 | 97.816285, 97.552490, 97.538696, 97.778443, 100.910970, 99.067830, 98.838827, 97.754517, 98.617961 |
| Manager queries, 768 keys | RN Text | Default | 1 | 3.879028, 3.887329, 3.877808, 3.910034, 4.010905, 3.879110, 3.879313, 3.915039, 3.887003 |
| Manager queries, 768 keys | RN Text | Default | 2 | 3.903971, 3.906209, 3.918742, 3.942383, 3.906656, 3.908732, 3.909912, 3.935018, 3.898803 |
| Manager queries, 768 keys | RN Text | Default | 3 | 3.894817, 3.923421, 3.892375, 3.890422, 3.878377, 3.873616, 3.920939, 3.899943, 3.889770 |
| Manager queries, 768 keys | RN Text | Prepared | 1 | 1757.373048, 1748.969890, 1755.999594, 1751.343628, 1758.430543, 1747.670858, 1754.513714, 1741.013266, 1735.787802 |
| Manager queries, 768 keys | RN Text | Prepared | 2 | 1752.723756, 1747.710694, 1747.605348, 1756.278932, 1752.278646, 1753.619508, 1754.152914, 2633.193646, 1733.945232 |
| Manager queries, 768 keys | RN Text | Prepared | 3 | 1765.537069, 1752.985433, 1751.256349, 1751.748007, 1761.284831, 1747.701783, 1754.992514, 1740.610067, 1736.268027 |
| Manager queries, 768 keys | TextView | Default | 1 | 1.562866, 1.469279, 1.446329, 1.475749, 1.458496, 1.439290, 1.491089, 1.444621, 1.479004 |
| Manager queries, 768 keys | TextView | Default | 2 | 1.448568, 1.442301, 1.473389, 1.458130, 1.440878, 1.481771, 1.455119, 1.566284, 1.471273 |
| Manager queries, 768 keys | TextView | Default | 3 | 1.454183, 1.471354, 1.459554, 1.437581, 1.463948, 1.456543, 1.440470, 1.577433, 1.449341 |
| Manager queries, 768 keys | TextView | Prepared | 1 | 1.562134, 1.433187, 1.445842, 1.472330, 1.437867, 1.458415, 1.467000, 1.605388, 1.477865 |
| Manager queries, 768 keys | TextView | Prepared | 2 | 1.435791, 1.565104, 1.445109, 1.457316, 1.468018, 1.448202, 1.455281, 1.455363, 1.650960 |
| Manager queries, 768 keys | TextView | Prepared | 3 | 1.441040, 1.574015, 1.461385, 1.436768, 1.559733, 1.540446, 1.458985, 1.763753, 1.443766 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 1 | 3.875244, 3.869914, 3.880778, 3.910686, 3.880574, 3.876098, 3.866089, 3.922038, 3.900961 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 2 | 3.931844, 3.916342, 3.926595, 3.944743, 3.906983, 3.927979, 3.932821, 3.959879, 3.919881 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 3 | 3.900961, 3.898112, 3.933390, 3.906006, 3.905802, 3.902344, 3.934245, 3.887166, 3.897705 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 1 | 1825.911052, 1831.164878, 1827.494752, 1833.168051, 1827.882040, 1841.147828, 1828.781536, 1842.290406, 1820.238771 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 2 | 1827.929201, 1869.550782, 1834.858684, 1856.172934, 1857.439943, 1846.687908, 1848.310792, 2381.409059, 1826.354371 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 3 | 1840.829876, 1860.398927, 1840.737387, 1834.746665, 1838.367961, 1847.883627, 1841.045615, 1832.902792, 1829.265626 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 1 | 1.583944, 1.596802, 1.565471, 1.696330, 1.591919, 1.599244, 1.600219, 1.577718, 1.609659 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 2 | 1.568441, 1.712484, 1.571126, 1.562419, 1.597494, 1.585938, 1.603393, 1.592936, 1.602742 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 3 | 1.719034, 3.600301, 1.572021, 1.597697, 1.579549, 1.626953, 1.588379, 1.594563, 1.645223 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 1 | 1.576050, 1.565755, 1.578125, 1.680176, 1.576741, 1.641235, 1.581217, 1.584392, 1.595988 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 2 | 1.596599, 1.578410, 1.587972, 1.742716, 1.598511, 1.607666, 1.573283, 1.593954, 1.607137 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 3 | 1.515218, 1.525106, 1.542074, 1.525269, 1.553793, 1.525675, 1.530314, 1.643921, 1.520874 |
| Styled text creation and layout | RN Text | Default | 1 | 315.498129, 319.639730, 316.198202, 319.495809, 317.249268, 315.723022, 319.431030, 315.597982, 316.821534 |
| Styled text creation and layout | RN Text | Default | 2 | 317.783284, 316.496948, 315.696614, 319.028972, 316.107626, 314.881267, 317.641154, 315.352742, 316.463745 |
| Styled text creation and layout | RN Text | Default | 3 | 316.883423, 314.683756, 316.040771, 316.642456, 317.601115, 314.872803, 316.190348, 314.917684, 315.769938 |
| Styled text creation and layout | RN Text | Prepared | 1 | 300.036865, 296.576457, 298.235393, 299.711467, 296.409261, 303.736247, 296.728353, 303.512858, 300.358154 |
| Styled text creation and layout | RN Text | Prepared | 2 | 298.778483, 297.675253, 296.030030, 297.594157, 295.424113, 297.217611, 297.883871, 296.324137, 298.293661 |
| Styled text creation and layout | RN Text | Prepared | 3 | 300.572998, 297.524414, 295.993489, 299.764893, 296.602987, 298.408691, 299.120158, 295.473673, 297.951498 |
| Styled text creation and layout | TextView | Default | 1 | 190.926514, 190.798218, 190.864055, 190.169922, 194.363932, 190.803060, 190.651367, 192.517863, 191.463460 |
| Styled text creation and layout | TextView | Default | 2 | 189.795980, 188.828573, 189.349895, 191.645996, 189.240519, 189.786417, 189.474731, 192.289998, 189.784912 |
| Styled text creation and layout | TextView | Default | 3 | 188.881470, 188.491496, 188.624878, 194.572348, 188.827881, 189.006633, 189.097534, 192.835165, 191.296102 |
| Styled text creation and layout | TextView | Prepared | 1 | 188.822510, 193.427083, 189.807089, 191.206503, 189.352213, 189.472982, 189.872600, 191.302856, 189.035197 |
| Styled text creation and layout | TextView | Prepared | 2 | 188.756876, 190.838908, 189.063111, 189.157308, 189.079387, 190.530884, 193.228720, 189.292277, 188.850952 |
| Styled text creation and layout | TextView | Prepared | 3 | 189.562418, 189.102458, 189.113566, 188.741130, 189.720866, 189.380209, 189.047811, 188.955404, 188.724813 |

</details>
