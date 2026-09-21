# RN Text benchmark results

Latest native layout, mounting, and drawing results for TextView, PreparedTextView, and React Native's `Text`, plus RN Text and TextView measurement results. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. Each ratio is the implementation’s time divided by RN Text time: 0.5× means half the time.

## iOS

September 21, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.3.1, Release build.

### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 69.784 ± 2.525 | 31.307 ± 0.330 | 31.311 ± 0.637 | 0.449× | 0.449× |
| Native layout, mount, and first draw | 512 | 283.552 ± 5.117 | 239.072 ± 2.552 | 238.189 ± 3.816 | 0.843× | 0.840× |

### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 8.675 ± 0.264 | 0.182 ± 0.003 | 0.021× |
| Short labels, natural line height | 512 | 11.681 ± 0.263 | 5.001 ± 0.113 | 0.428× |
| Plain text creation and layout | 512 | 68.200 ± 1.587 | 30.762 ± 0.795 | 0.451× |
| Manager queries, 768 keys | 98,304 | 31.694 ± 0.674 | 5.742 ± 0.032 | 0.181× |
| Manager queries, 768 keys, two-line limit | 98,304 | 31.978 ± 0.352 | 15.213 ± 0.246 | 0.476× |
| Styled text creation and layout | 384 | 67.252 ± 0.871 | 28.534 ± 0.514 | 0.424× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T03:56:02.781Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `5b013687b64ffc9f5d0c1f50bb262e9041568a00`
- Source checksum (SHA256): `e1833db743c0c9fc79988b418556eb0fbdbe9a1378fc76b8d05cc80018fbedb7`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | Run | Samples (ms) |
| --- | --- | ---: | --- |
| Chat list layout | RN Text | 1 | 65.557125, 65.631042, 66.006292, 65.714291, 66.214333, 65.570750, 65.973000, 66.165500, 66.426500 |
| Chat list layout | RN Text | 2 | 70.101667, 69.784500, 69.975583, 68.716708, 70.367250, 67.640209, 68.762792, 71.382000, 69.581333 |
| Chat list layout | RN Text | 3 | 73.976541, 72.096667, 72.158542, 71.115250, 72.638042, 72.309250, 73.460542, 74.820417, 71.896125 |
| Chat list layout | TextView | 1 | 28.797583, 29.139208, 29.200167, 29.275083, 29.313584, 29.228625, 29.152125, 28.775583, 28.830709 |
| Chat list layout | TextView | 2 | 31.279417, 30.943167, 31.737792, 30.722750, 32.016417, 31.307083, 33.757875, 31.266917, 32.210666 |
| Chat list layout | TextView | 3 | 32.721208, 31.029166, 31.952500, 31.485000, 32.136917, 31.637375, 31.488500, 32.759042, 31.342292 |
| Chat list layout | PreparedTextView | 1 | 28.783208, 29.291625, 28.967417, 28.857625, 29.373000, 28.744667, 29.437834, 28.788000, 28.921750 |
| Chat list layout | PreparedTextView | 2 | 31.272500, 31.061166, 31.861125, 30.932834, 31.436333, 31.586542, 32.402917, 31.311042, 30.515750 |
| Chat list layout | PreparedTextView | 3 | 32.750167, 31.580834, 32.428209, 31.622125, 31.947875, 31.338625, 32.088667, 33.036375, 31.500417 |
| Native layout, mount, and first draw | RN Text | 1 | 263.271292, 264.513584, 268.744125, 270.498417, 270.936041, 267.482542, 268.148083, 269.319500, 271.817292 |
| Native layout, mount, and first draw | RN Text | 2 | 280.460125, 281.375708, 283.596416, 283.122916, 283.551916, 285.410084, 285.944208, 282.289500, 284.198709 |
| Native layout, mount, and first draw | RN Text | 3 | 298.648083, 289.518291, 285.594542, 287.524166, 288.668958, 288.416958, 292.517333, 303.570750, 288.314916 |
| Native layout, mount, and first draw | TextView | 1 | 222.782459, 224.975250, 223.460875, 226.815667, 229.722875, 225.252375, 226.941042, 228.610875, 238.268208 |
| Native layout, mount, and first draw | TextView | 2 | 243.774959, 239.925500, 238.508125, 237.573416, 239.072000, 248.592542, 240.036917, 237.883417, 236.337833 |
| Native layout, mount, and first draw | TextView | 3 | 240.991250, 244.130708, 240.422708, 240.670792, 243.602667, 241.624000, 240.041792, 248.870542, 245.137375 |
| Native layout, mount, and first draw | PreparedTextView | 1 | 221.596959, 223.734083, 222.546208, 227.398000, 230.167625, 225.501958, 226.086250, 225.068375, 228.175250 |
| Native layout, mount, and first draw | PreparedTextView | 2 | 242.331667, 238.188791, 240.054250, 237.448125, 237.707084, 234.635291, 237.174125, 239.355833, 243.034167 |
| Native layout, mount, and first draw | PreparedTextView | 3 | 239.814125, 241.369583, 240.011667, 242.004667, 241.535292, 243.287625, 244.541167, 242.070458, 245.597000 |
| Retained paragraph measurement | RN Text | 1 | 8.279625, 8.828875, 8.410625, 8.564667, 8.327542, 8.409791, 8.558084, 8.349417, 8.534458 |
| Retained paragraph measurement | RN Text | 2 | 8.743375, 9.049083, 8.679834, 8.674834, 8.665625, 8.595000, 8.583667, 8.620917, 8.694000 |
| Retained paragraph measurement | RN Text | 3 | 9.096916, 8.997750, 9.013208, 9.026375, 8.875041, 9.186083, 8.925958, 8.679416, 8.582708 |
| Retained paragraph measurement | TextView | 1 | 0.166333, 0.166625, 0.176625, 0.176750, 0.182084, 0.178875, 0.180625, 0.179875, 0.180084 |
| Retained paragraph measurement | TextView | 2 | 0.179750, 0.181833, 0.180709, 0.175667, 0.174041, 0.188083, 0.188041, 0.189209, 0.187500 |
| Retained paragraph measurement | TextView | 3 | 0.200375, 0.200208, 0.200416, 0.201167, 0.201375, 0.200541, 0.189375, 0.190375, 0.190042 |
| Short labels, natural line height | RN Text | 1 | 11.468667, 11.486500, 11.431041, 11.459458, 11.417750, 11.323750, 11.256791, 11.267958, 11.248375 |
| Short labels, natural line height | RN Text | 2 | 11.861000, 11.951000, 12.164625, 11.544500, 11.647958, 11.681125, 11.683167, 11.534625, 11.661958 |
| Short labels, natural line height | RN Text | 3 | 12.080583, 12.254667, 11.888625, 11.963250, 12.150292, 11.913208, 12.228458, 12.095417, 12.050375 |
| Short labels, natural line height | TextView | 1 | 4.888291, 4.895875, 5.157125, 4.909458, 4.903084, 4.759542, 4.868000, 4.708917, 4.758708 |
| Short labels, natural line height | TextView | 2 | 5.145208, 4.886041, 4.955167, 5.001334, 4.886250, 5.025709, 5.045167, 4.998584, 5.146417 |
| Short labels, natural line height | TextView | 3 | 5.057417, 5.037125, 5.407000, 5.131917, 5.214209, 5.351875, 5.143292, 5.102459, 5.284250 |
| Plain text creation and layout | RN Text | 1 | 66.257417, 67.880334, 66.796125, 65.112833, 65.026042, 67.396959, 66.612708, 65.534667, 67.560834 |
| Plain text creation and layout | RN Text | 2 | 68.199667, 67.970042, 69.418834, 68.960375, 67.895084, 67.842417, 69.100666, 67.619250, 69.066625 |
| Plain text creation and layout | RN Text | 3 | 70.078167, 70.681292, 70.044792, 70.699041, 70.008333, 69.505791, 70.791083, 70.334000, 70.718500 |
| Plain text creation and layout | TextView | 1 | 29.270417, 29.427792, 29.229959, 29.349542, 31.740750, 30.176834, 29.266625, 29.371709, 29.988375 |
| Plain text creation and layout | TextView | 2 | 31.142083, 30.509625, 30.470666, 30.881792, 30.294209, 31.930708, 31.043250, 30.761917, 30.502666 |
| Plain text creation and layout | TextView | 3 | 31.664417, 31.441750, 31.556834, 31.250208, 31.645709, 31.571667, 31.676667, 31.543958, 31.532042 |
| Manager queries, 768 keys | RN Text | 1 | 31.019667, 30.997334, 30.971000, 30.814917, 31.316625, 32.314042, 32.098250, 30.899583, 31.057083 |
| Manager queries, 768 keys | RN Text | 2 | 31.338959, 31.693500, 31.652959, 31.509000, 32.262250, 32.278083, 33.107667, 31.756334, 31.626667 |
| Manager queries, 768 keys | RN Text | 3 | 32.997958, 33.359834, 32.899916, 33.314292, 32.597209, 33.151667, 32.659833, 33.311834, 32.614167 |
| Manager queries, 768 keys | TextView | 1 | 5.789666, 5.742167, 5.509958, 5.710708, 6.188167, 5.872916, 5.767792, 5.596916, 5.607750 |
| Manager queries, 768 keys | TextView | 2 | 5.701667, 5.710417, 5.849000, 5.744166, 5.646333, 5.693750, 5.748625, 5.714084, 5.652125 |
| Manager queries, 768 keys | TextView | 3 | 5.990125, 5.925250, 6.006208, 5.812500, 6.232875, 5.850792, 5.818500, 5.832459, 6.219417 |
| Manager queries, 768 keys, two-line limit | RN Text | 1 | 30.693375, 31.626000, 31.331167, 32.460208, 32.338750, 32.298083, 31.909166, 30.858333, 31.319583 |
| Manager queries, 768 keys, two-line limit | RN Text | 2 | 31.409459, 31.678625, 32.470791, 33.347458, 32.204167, 31.138167, 31.977584, 31.470709, 32.204833 |
| Manager queries, 768 keys, two-line limit | RN Text | 3 | 32.403041, 32.255667, 33.508542, 32.764750, 32.771750, 33.068208, 33.265916, 32.479000, 33.140542 |
| Manager queries, 768 keys, two-line limit | TextView | 1 | 14.670417, 14.498750, 14.419084, 15.639959, 15.034041, 15.282833, 14.712083, 14.526375, 14.767291 |
| Manager queries, 768 keys, two-line limit | TextView | 2 | 15.367792, 15.203875, 15.213083, 15.512792, 15.508000, 15.369166, 14.979667, 15.201583, 14.953500 |
| Manager queries, 768 keys, two-line limit | TextView | 3 | 15.766125, 15.094875, 15.485875, 15.523209, 15.483583, 14.984833, 15.087833, 15.458667, 15.448667 |
| Styled text creation and layout | RN Text | 1 | 63.307792, 66.964000, 66.403750, 64.473458, 66.052625, 68.639250, 66.702416, 64.887083, 64.562958 |
| Styled text creation and layout | RN Text | 2 | 67.768500, 67.776167, 66.663709, 66.818209, 67.524292, 67.251750, 66.786208, 67.668125, 66.804291 |
| Styled text creation and layout | RN Text | 3 | 67.887167, 68.519542, 67.986250, 68.123084, 67.691250, 69.972833, 68.421584, 69.371792, 67.416541 |
| Styled text creation and layout | TextView | 1 | 28.019875, 28.472792, 27.336208, 27.286500, 29.294417, 29.222250, 28.097958, 27.939500, 26.867459 |
| Styled text creation and layout | TextView | 2 | 28.227125, 28.560709, 28.254333, 28.533542, 28.890000, 28.321625, 28.434042, 28.893750, 29.031333 |
| Styled text creation and layout | TextView | 3 | 29.117375, 29.178083, 29.279084, 28.849541, 29.180917, 29.197958, 29.393291, 29.221709, 30.567834 |

</details>

## Android

September 21, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.3.1, Release build.

### RN Text with default layout

#### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 153.962 ± 0.469 | 109.014 ± 0.305 | 100.348 ± 0.060 | 0.708× | 0.652× |
| Native layout, mount, and first draw | 512 | 897.288 ± 3.688 | 420.534 ± 0.076 | 446.387 ± 0.458 | 0.469× | 0.497× |

#### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 19.369 ± 0.007 | 0.834 ± 0.002 | 0.043× |
| Short labels, natural line height | 512 | 53.834 ± 0.126 | 36.962 ± 0.011 | 0.687× |
| Plain text creation and layout | 512 | 141.471 ± 0.050 | 101.368 ± 0.275 | 0.717× |
| Manager queries, 768 keys | 6,144 | 3.957 ± 0.013 | 1.430 ± 0.037 | 0.361× |
| Manager queries, 768 keys, two-line limit | 6,144 | 3.970 ± 0.005 | 1.582 ± 0.019 | 0.398× |
| Styled text creation and layout | 384 | 317.545 ± 0.722 | 190.693 ± 1.164 | 0.601× |

### RN Text with prepared layout

#### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 158.831 ± 0.546 | 109.609 ± 0.020 | 100.592 ± 0.024 | 0.690× | 0.633× |
| Native layout, mount, and first draw | 512 | 453.244 ± 0.230 | 421.226 ± 0.120 | 445.704 ± 0.180 | 0.929× | 0.983× |

#### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 0.244 ± 0.004 | 0.816 ± 0.002 | 3.350× |
| Short labels, natural line height | 512 | 58.447 ± 0.101 | 37.017 ± 0.031 | 0.633× |
| Plain text creation and layout | 512 | 145.732 ± 0.308 | 101.316 ± 0.088 | 0.695× |
| Manager queries, 768 keys | 6,144 | 1751.462 ± 4.782 | 1.461 ± 0.008 | 0.001× |
| Manager queries, 768 keys, two-line limit | 6,144 | 1834.033 ± 4.748 | 1.586 ± 0.006 | 0.001× |
| Styled text creation and layout | 384 | 300.236 ± 0.036 | 189.811 ± 0.258 | 0.632× |

The manager-query rows miss RN’s 200-entry prepared-layout cache on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T03:55:55.384Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Each repeated-query workload visits 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `cfcc564954a65ecb233cd54fa6b63f75ffb56e2e0a7fa1552d09dfe49217607e`
- Git HEAD: `5b013687b64ffc9f5d0c1f50bb262e9041568a00`
- Source checksum (SHA256): `7eb29a694cf1ba48c6a9f093013475c9e60830453d10237939d6f0ca5ee4eef0`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | RN configuration | Run | Samples (ms) |
| --- | --- | --- | ---: | --- |
| Chat list layout | RN Text | Default | 1 | 153.861369, 153.788900, 155.529378, 153.807088, 157.557577, 154.693888, 154.087240, 153.668254, 153.961548 |
| Chat list layout | RN Text | Default | 2 | 155.775309, 153.449626, 153.343546, 153.457356, 155.968343, 156.233602, 155.916463, 153.336425, 155.933593 |
| Chat list layout | RN Text | Default | 3 | 153.492513, 153.500773, 153.328125, 153.465698, 155.944254, 154.032714, 153.343791, 152.919759, 156.548991 |
| Chat list layout | RN Text | Prepared | 1 | 157.752930, 161.176717, 157.213297, 158.987997, 158.285116, 159.735352, 161.064453, 158.112712, 157.671794 |
| Chat list layout | RN Text | Prepared | 2 | 159.091309, 160.525106, 159.487183, 159.188069, 159.164022, 159.690674, 160.014527, 159.536336, 159.538737 |
| Chat list layout | RN Text | Prepared | 3 | 157.530273, 160.645752, 157.391195, 158.831299, 158.698039, 158.711711, 161.378418, 159.320516, 159.808146 |
| Chat list layout | TextView | Default | 1 | 108.915975, 108.656169, 110.163167, 108.499633, 109.650594, 108.709228, 109.697347, 108.287639, 108.650187 |
| Chat list layout | TextView | Default | 2 | 108.440063, 109.149658, 110.575927, 108.801554, 112.871216, 110.104086, 109.615438, 109.678833, 108.636434 |
| Chat list layout | TextView | Default | 3 | 108.511027, 108.292073, 112.924642, 108.343547, 109.750325, 109.318725, 110.832438, 108.601075, 109.014160 |
| Chat list layout | TextView | Prepared | 1 | 108.554851, 109.623088, 109.355469, 110.291870, 109.016398, 111.833334, 109.268107, 109.429199, 110.847901 |
| Chat list layout | TextView | Prepared | 2 | 108.770834, 109.734131, 109.659709, 109.628499, 109.827149, 108.956869, 109.164103, 109.998332, 109.068969 |
| Chat list layout | TextView | Prepared | 3 | 109.351278, 109.608683, 111.374390, 110.371175, 109.040935, 110.300130, 108.632894, 109.816285, 109.515096 |
| Chat list layout | PreparedTextView | Default | 1 | 100.536540, 99.552165, 100.223754, 101.212524, 100.232910, 100.288167, 100.632609, 100.253255, 100.635010 |
| Chat list layout | PreparedTextView | Default | 2 | 100.208741, 100.656616, 100.163818, 101.213461, 100.209025, 100.547079, 100.592244, 102.013631, 102.730469 |
| Chat list layout | PreparedTextView | Default | 3 | 100.348267, 100.460083, 100.203939, 101.586385, 100.175781, 100.268961, 100.574300, 101.242147, 100.146892 |
| Chat list layout | PreparedTextView | Prepared | 1 | 100.591634, 100.352214, 102.236165, 100.611532, 100.816040, 100.502482, 100.430989, 100.857788, 100.541626 |
| Chat list layout | PreparedTextView | Prepared | 2 | 100.389527, 100.651245, 100.467244, 100.629436, 100.409464, 100.274617, 103.133993, 98.753500, 100.485921 |
| Chat list layout | PreparedTextView | Prepared | 3 | 100.446492, 100.531779, 100.615275, 100.616415, 100.667236, 100.572428, 102.966349, 99.035929, 100.917928 |
| Native layout, mount, and first draw | RN Text | Default | 1 | 841.792237, 839.302532, 860.624553, 927.840211, 881.275391, 902.866496, 931.132203, 956.186606, 983.548706 |
| Native layout, mount, and first draw | RN Text | Default | 2 | 820.994426, 847.359212, 867.521444, 895.518840, 938.600953, 897.288290, 942.098104, 945.843262, 1053.035563 |
| Native layout, mount, and first draw | RN Text | Default | 3 | 802.207724, 821.879069, 845.448609, 870.498577, 893.599976, 921.736369, 997.693726, 918.650717, 946.367432 |
| Native layout, mount, and first draw | RN Text | Prepared | 1 | 458.658732, 453.654826, 451.908610, 453.976644, 448.177653, 450.663778, 453.915121, 453.244059, 452.617229 |
| Native layout, mount, and first draw | RN Text | Prepared | 2 | 454.416707, 451.899781, 454.862590, 451.083415, 452.166138, 453.013917, 456.118774, 452.783773, 462.212972 |
| Native layout, mount, and first draw | RN Text | Prepared | 3 | 454.310059, 456.413534, 456.730876, 452.977864, 457.432577, 451.839030, 452.897950, 455.107382, 452.485067 |
| Native layout, mount, and first draw | TextView | Default | 1 | 422.351115, 424.745768, 428.151733, 424.671672, 425.646566, 422.756796, 427.558838, 422.747599, 427.318523 |
| Native layout, mount, and first draw | TextView | Default | 2 | 419.880086, 423.418376, 424.064575, 419.558797, 420.527019, 420.827311, 424.660645, 420.533529, 419.731568 |
| Native layout, mount, and first draw | TextView | Default | 3 | 424.834188, 419.432129, 420.421224, 420.258423, 421.214966, 423.843507, 418.527629, 420.457845, 421.979777 |
| Native layout, mount, and first draw | TextView | Prepared | 1 | 424.661703, 429.345418, 422.778198, 423.239543, 422.768392, 424.945394, 424.527629, 422.248251, 424.896241 |
| Native layout, mount, and first draw | TextView | Prepared | 2 | 419.986613, 420.456258, 421.306478, 421.225789, 430.294719, 420.569946, 421.312581, 421.844279, 421.122722 |
| Native layout, mount, and first draw | TextView | Prepared | 3 | 425.226075, 422.580119, 420.802654, 420.806315, 420.312948, 420.485840, 421.235189, 421.260620, 421.105672 |
| Native layout, mount, and first draw | PreparedTextView | Default | 1 | 446.387452, 445.952189, 454.872396, 446.004313, 445.898153, 446.839070, 450.204305, 446.119385, 447.818644 |
| Native layout, mount, and first draw | PreparedTextView | Default | 2 | 446.192302, 445.871745, 445.419353, 448.500203, 445.929077, 445.827759, 445.369548, 449.774170, 446.243083 |
| Native layout, mount, and first draw | PreparedTextView | Default | 3 | 453.065145, 448.657471, 448.136801, 454.002686, 455.027100, 448.697795, 448.157267, 448.868245, 450.647827 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 1 | 444.583700, 448.829468, 444.773763, 446.314372, 445.669515, 447.085979, 444.645834, 445.703898, 445.874309 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 2 | 445.596436, 446.739014, 444.846720, 444.968384, 445.416748, 448.519857, 445.523966, 447.331340, 445.215902 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 3 | 446.661011, 446.571615, 458.029297, 446.117187, 445.625814, 448.262329, 446.343710, 446.768229, 448.951986 |
| Retained paragraph measurement | RN Text | Default | 1 | 19.369751, 19.371541, 19.403280, 19.381103, 19.414185, 19.336914, 19.375773, 19.414876, 19.372193 |
| Retained paragraph measurement | RN Text | Default | 2 | 19.087972, 19.242065, 20.213745, 19.417195, 19.348959, 19.409221, 19.321248, 19.108724, 19.176962 |
| Retained paragraph measurement | RN Text | Default | 3 | 19.368245, 19.363607, 19.351725, 19.438884, 19.461995, 19.348755, 19.389119, 19.388021, 19.369141 |
| Retained paragraph measurement | RN Text | Prepared | 1 | 0.238200, 0.238485, 0.238321, 0.238322, 0.238118, 0.238363, 0.238159, 0.238200, 0.238119 |
| Retained paragraph measurement | RN Text | Prepared | 2 | 0.269857, 0.247396, 0.247395, 0.247151, 0.247152, 0.250325, 0.247355, 0.247315, 0.247477 |
| Retained paragraph measurement | RN Text | Prepared | 3 | 0.243612, 0.243530, 0.243449, 0.243571, 0.243693, 0.243490, 0.243693, 0.243530, 0.243774 |
| Retained paragraph measurement | TextView | Default | 1 | 0.850464, 0.853109, 0.860921, 0.832642, 0.832926, 0.833537, 0.833659, 0.865844, 0.832072 |
| Retained paragraph measurement | TextView | Default | 2 | 0.836833, 0.836792, 0.856405, 0.836751, 0.836385, 0.836263, 0.835734, 0.896240, 0.836752 |
| Retained paragraph measurement | TextView | Default | 3 | 0.868083, 0.831910, 0.832113, 0.832276, 0.832031, 0.863322, 0.832072, 0.833130, 0.831462 |
| Retained paragraph measurement | TextView | Prepared | 1 | 0.821126, 0.823080, 0.821004, 0.820882, 0.820638, 0.847738, 0.824219, 0.823812, 0.823975 |
| Retained paragraph measurement | TextView | Prepared | 2 | 0.816040, 0.815348, 0.843018, 0.814168, 0.813517, 0.814290, 0.813802, 0.928101, 0.814372 |
| Retained paragraph measurement | TextView | Prepared | 3 | 0.814819, 0.814983, 0.815144, 0.928508, 0.816244, 0.815674, 0.815877, 0.856242, 0.821004 |
| Short labels, natural line height | RN Text | Default | 1 | 52.940674, 53.856160, 53.782512, 53.671997, 53.777629, 53.530843, 56.197998, 52.496867, 53.269938 |
| Short labels, natural line height | RN Text | Default | 2 | 54.079346, 53.833863, 53.686849, 53.603597, 53.762248, 56.171509, 53.242961, 55.368938, 53.875692 |
| Short labels, natural line height | RN Text | Default | 3 | 54.017944, 53.992920, 53.754679, 53.822224, 53.614217, 57.520019, 54.040080, 53.959595, 53.751709 |
| Short labels, natural line height | RN Text | Prepared | 1 | 58.115316, 58.228963, 58.130127, 58.103190, 57.960896, 60.545695, 55.967203, 59.395141, 59.966552 |
| Short labels, natural line height | RN Text | Prepared | 2 | 58.470865, 58.548177, 58.451049, 58.680176, 60.410767, 56.475383, 58.695069, 58.507853, 58.583699 |
| Short labels, natural line height | RN Text | Prepared | 3 | 58.591675, 58.649496, 58.435587, 58.443522, 61.346964, 58.300700, 58.447185, 58.541951, 58.369181 |
| Short labels, natural line height | TextView | Default | 1 | 37.274943, 34.368123, 36.331177, 37.026448, 36.838216, 37.041789, 36.785767, 36.951090, 37.012166 |
| Short labels, natural line height | TextView | Default | 2 | 37.524699, 39.444458, 37.301636, 36.793905, 37.118082, 38.222208, 38.382528, 37.169067, 36.951253 |
| Short labels, natural line height | TextView | Default | 3 | 39.207927, 38.142985, 39.068970, 36.653890, 36.961670, 36.879232, 36.931437, 36.991008, 36.867635 |
| Short labels, natural line height | TextView | Prepared | 1 | 38.765585, 37.113933, 37.051758, 37.077311, 37.125366, 37.120443, 37.276856, 37.355631, 37.157877 |
| Short labels, natural line height | TextView | Prepared | 2 | 36.857097, 36.986694, 36.927938, 36.988403, 36.928752, 37.052653, 37.220255, 37.121704, 36.973226 |
| Short labels, natural line height | TextView | Prepared | 3 | 35.547323, 38.602906, 36.996298, 36.973307, 36.982828, 37.017212, 37.036865, 37.065795, 37.185465 |
| Plain text creation and layout | RN Text | Default | 1 | 140.914144, 141.471110, 141.459269, 141.417521, 143.956950, 142.120524, 141.641520, 141.627361, 141.350912 |
| Plain text creation and layout | RN Text | Default | 2 | 141.521200, 141.090577, 141.167766, 141.539877, 141.983806, 145.104615, 143.143921, 141.018514, 141.221232 |
| Plain text creation and layout | RN Text | Default | 3 | 141.316162, 141.103841, 140.671305, 141.053711, 143.929159, 141.504476, 141.116740, 140.673299, 143.763102 |
| Plain text creation and layout | RN Text | Prepared | 1 | 146.444865, 145.424113, 146.099894, 145.332886, 145.301229, 146.035279, 143.563029, 147.465455, 141.610799 |
| Plain text creation and layout | RN Text | Prepared | 2 | 146.572144, 146.470621, 145.982015, 145.932943, 146.808350, 144.768840, 146.354289, 146.142781, 146.225952 |
| Plain text creation and layout | RN Text | Prepared | 3 | 145.824626, 145.746908, 145.648600, 146.195394, 147.585734, 144.244385, 145.732015, 145.436076, 145.631144 |
| Plain text creation and layout | TextView | Default | 1 | 101.504028, 100.979777, 101.084961, 100.806437, 101.093425, 101.605103, 101.265096, 102.789022, 100.986735 |
| Plain text creation and layout | TextView | Default | 2 | 103.368408, 101.165242, 101.484253, 101.169108, 101.760050, 101.968384, 102.068238, 102.733602, 100.899089 |
| Plain text creation and layout | TextView | Default | 3 | 103.029785, 101.076741, 101.368449, 101.076620, 101.327393, 101.570800, 103.966512, 101.407104, 100.835693 |
| Plain text creation and layout | TextView | Prepared | 1 | 101.029297, 101.156006, 101.445679, 100.229085, 99.768717, 102.746378, 101.685547, 103.412639, 101.768921 |
| Plain text creation and layout | TextView | Prepared | 2 | 101.241903, 101.106120, 101.227906, 101.193889, 102.805949, 98.422323, 101.359335, 101.164225, 101.542684 |
| Plain text creation and layout | TextView | Prepared | 3 | 101.094320, 101.316081, 101.496623, 101.504883, 101.212931, 102.038004, 101.202026, 101.275513, 102.903239 |
| Manager queries, 768 keys | RN Text | Default | 1 | 3.943767, 3.990275, 3.952352, 3.954753, 3.956950, 3.984253, 3.957601, 3.949625, 3.961589 |
| Manager queries, 768 keys | RN Text | Default | 2 | 3.985922, 4.014811, 3.923869, 3.911540, 3.923950, 3.918335, 3.955485, 3.931722, 3.931234 |
| Manager queries, 768 keys | RN Text | Default | 3 | 3.965210, 3.972737, 3.976888, 3.964884, 3.967936, 3.971639, 3.982992, 3.970092, 3.962972 |
| Manager queries, 768 keys | RN Text | Prepared | 1 | 1761.331097, 1746.309816, 1760.959880, 1740.630698, 1742.832724, 1740.600993, 1736.723470, 1731.332683, 1735.382325 |
| Manager queries, 768 keys | RN Text | Prepared | 2 | 1761.121054, 1756.244182, 1758.826783, 1752.874960, 1758.475709, 1765.626384, 1744.845501, 1746.675375, 1747.683839 |
| Manager queries, 768 keys | RN Text | Prepared | 3 | 1751.856284, 1751.461793, 1762.968059, 1756.090780, 1750.602418, 1753.167278, 1742.161744, 1740.479575, 1738.918051 |
| Manager queries, 768 keys | TextView | Default | 1 | 1.446004, 1.608113, 1.478923, 1.481608, 1.475586, 1.462727, 1.499837, 1.475097, 1.460734 |
| Manager queries, 768 keys | TextView | Default | 2 | 1.388183, 1.556560, 1.392253, 1.378092, 1.410970, 1.393025, 1.388712, 1.426147, 1.384400 |
| Manager queries, 768 keys | TextView | Default | 3 | 1.429647, 1.496663, 1.421713, 1.415324, 1.440511, 1.430868, 1.421630, 1.444702, 1.426392 |
| Manager queries, 768 keys | TextView | Prepared | 1 | 1.473714, 1.440714, 1.455607, 1.575643, 1.446574, 1.461100, 1.467163, 1.460042, 1.467814 |
| Manager queries, 768 keys | TextView | Prepared | 2 | 1.462361, 1.452881, 1.475871, 1.460653, 1.556762, 1.473796, 1.457601, 1.484538, 1.469279 |
| Manager queries, 768 keys | TextView | Prepared | 3 | 1.441447, 1.430989, 1.451416, 1.438029, 1.435791, 1.470784, 1.446492, 1.453450, 1.491048 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 1 | 4.001587, 3.969890, 3.958658, 3.977377, 3.995728, 3.945842, 3.962361, 3.953370, 3.991048 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 2 | 3.925985, 3.974447, 3.948120, 4.001872, 4.003866, 3.989583, 3.989217, 3.943034, 3.929200 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 3 | 3.940145, 3.941772, 3.967895, 3.941650, 3.947876, 3.946980, 3.969075, 3.943278, 3.952312 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 1 | 1826.898601, 1829.387981, 1830.385825, 1823.562379, 1828.608400, 2333.257976, 1829.358888, 1821.766114, 1829.285238 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 2 | 1838.156861, 1842.709718, 1839.075766, 1835.236695, 1834.838258, 1846.258668, 1844.688436, 1840.389934, 1825.991781 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 3 | 1834.033285, 1841.351970, 1836.308106, 1835.261964, 2376.159425, 1830.920899, 1832.177491, 1833.115683, 1834.031780 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 1 | 1.568685, 1.589844, 1.565063, 1.726074, 1.671956, 1.546956, 1.581542, 1.571859, 1.664632 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 2 | 1.529704, 1.521322, 1.562053, 1.515178, 1.530965, 1.649699, 1.523804, 1.561686, 1.520345 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 3 | 1.592733, 1.613769, 1.600504, 1.600505, 1.586059, 1.592122, 2.139730, 1.599610, 1.604939 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 1 | 1.597371, 1.553385, 1.601033, 1.552816, 1.545288, 1.691528, 1.572469, 1.585978, 1.590251 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 2 | 1.600627, 1.579753, 1.579224, 1.717000, 1.549275, 1.579060, 1.564331, 1.682698, 1.663371 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 3 | 1.604858, 1.619262, 1.594686, 1.606283, 1.726196, 1.599325, 1.631795, 1.585815, 1.585896 |
| Styled text creation and layout | RN Text | Default | 1 | 319.068807, 316.317098, 317.067994, 316.760579, 317.890219, 319.342814, 318.719645, 320.236898, 322.041463 |
| Styled text creation and layout | RN Text | Default | 2 | 317.544759, 318.568238, 317.349162, 318.157674, 316.711019, 317.128540, 318.726399, 316.192220, 320.285645 |
| Styled text creation and layout | RN Text | Default | 3 | 315.806355, 316.822673, 315.813314, 318.657511, 316.090779, 317.329061, 318.775188, 315.063070, 317.532146 |
| Styled text creation and layout | RN Text | Prepared | 1 | 300.235515, 300.350912, 297.885987, 304.315633, 299.378541, 305.318686, 301.337077, 298.193318, 299.246215 |
| Styled text creation and layout | RN Text | Prepared | 2 | 301.687581, 301.673462, 298.997070, 300.271444, 298.596517, 300.298706, 299.618572, 296.895061, 300.692261 |
| Styled text creation and layout | RN Text | Prepared | 3 | 298.712118, 300.670451, 300.936279, 299.270508, 298.530111, 299.773153, 298.408082, 299.303793, 300.090048 |
| Styled text creation and layout | TextView | Default | 1 | 189.927857, 189.681112, 189.529012, 189.029419, 190.337931, 188.708130, 188.486695, 188.871216, 189.878418 |
| Styled text creation and layout | TextView | Default | 2 | 191.688477, 190.693278, 191.755005, 190.165527, 192.972127, 188.879924, 190.356039, 189.907959, 192.125325 |
| Styled text creation and layout | TextView | Default | 3 | 401.197226, 475.341878, 463.217407, 469.372518, 378.199545, 188.613200, 188.745483, 187.764201, 187.773478 |
| Styled text creation and layout | TextView | Prepared | 1 | 190.083292, 190.019938, 189.619304, 191.581869, 189.811483, 189.570069, 189.604248, 189.217082, 190.057414 |
| Styled text creation and layout | TextView | Prepared | 2 | 188.371785, 188.416382, 188.102458, 190.599081, 193.992920, 189.553792, 189.506592, 189.745850, 192.154297 |
| Styled text creation and layout | TextView | Prepared | 3 | 190.308268, 190.588054, 189.630981, 191.076091, 447.187460, 467.086466, 464.603841, 471.831503, 252.242269 |

</details>
