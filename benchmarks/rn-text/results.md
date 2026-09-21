# RN Text benchmark results

Latest native layout, mounting, and drawing results for TextView, PreparedTextView, and React Native's `Text`, plus RN Text and TextView measurement results. See the [benchmark guide](README.md) for workloads, measurement methods, and run instructions.

Times are milliseconds per sample. Each value is the median of three run medians; ± shows their median absolute deviation. Each ratio is the implementation’s time divided by RN Text time: 0.5× means half the time.

## iOS

September 21, 2026. iPhone18,1, iOS 26.6.2. React Native 0.87.1, Text Engine 0.3.1, Release build.

### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 68.718 ± 2.491 | 30.840 ± 0.774 | 30.908 ± 0.888 | 0.449× | 0.450× |
| Native layout, mount, and first draw | 512 | 280.161 ± 10.157 | 239.471 ± 5.390 | 240.010 ± 1.174 | 0.855× | 0.857× |

### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 8.722 ± 0.074 | 0.188 ± 0.001 | 0.022× |
| Short labels, natural line height | 512 | 11.835 ± 0.244 | 5.039 ± 0.194 | 0.426× |
| Plain text creation and layout | 512 | 69.011 ± 0.224 | 30.782 ± 0.607 | 0.446× |
| Manager queries, 200 keys | 25,600 | 8.147 ± 0.097 | 1.559 ± 0.006 | 0.191× |
| Manager queries, 200 keys, two-line limit | 25,600 | 8.216 ± 0.063 | 3.916 ± 0.055 | 0.477× |
| Manager queries, 768 keys | 98,304 | 31.712 ± 0.160 | 5.712 ± 0.059 | 0.180× |
| Manager queries, 768 keys, two-line limit | 98,304 | 31.427 ± 0.346 | 14.730 ± 0.024 | 0.469× |
| Styled text creation and layout | 384 | 67.556 ± 0.458 | 28.830 ± 0.334 | 0.427× |

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T04:31:00.744Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Toolchain: Xcode 26.3 / Build version 17C529; SDK iphoneos26.2; Node v22.21.1
- Git HEAD: `1f88ccf1292d2e7d1cb548100df7c34ca54ef5b8`
- Source checksum (SHA256): `a64d65c62d9d37715e752d267170c6d23937b2fd0c7059fb2d2431a09c98770d`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | Run | Samples (ms) |
| --- | --- | ---: | --- |
| Chat list layout | RN Text | 1 | 70.603167, 66.237167, 70.999625, 67.600709, 65.981416, 65.927708, 66.126292, 66.226542, 66.144250 |
| Chat list layout | RN Text | 2 | 68.607875, 67.894333, 69.086459, 68.717500, 68.486916, 69.536917, 68.518625, 70.474500, 68.836084 |
| Chat list layout | RN Text | 3 | 70.963833, 71.656125, 71.545541, 72.177292, 71.773000, 70.564209, 70.108167, 70.141500, 72.508292 |
| Chat list layout | TextView | 1 | 29.437166, 29.193125, 28.734916, 29.836417, 29.460375, 29.535791, 29.276625, 29.061875, 29.110458 |
| Chat list layout | TextView | 2 | 32.123417, 30.600750, 31.135875, 30.477917, 30.477084, 30.901833, 30.840292, 30.687208, 30.990958 |
| Chat list layout | TextView | 3 | 32.125708, 32.356833, 31.614625, 31.491250, 31.489625, 31.166500, 32.083417, 31.300458, 32.165959 |
| Chat list layout | PreparedTextView | 1 | 31.814875, 29.093792, 28.628916, 29.323584, 29.585166, 29.455833, 29.525625, 29.696417, 29.631208 |
| Chat list layout | PreparedTextView | 2 | 31.090125, 30.399333, 30.647208, 30.901833, 30.952333, 31.968166, 30.780417, 30.908291, 31.681000 |
| Chat list layout | PreparedTextView | 3 | 31.370584, 31.722583, 31.796084, 31.738250, 32.129125, 32.683334, 32.013125, 31.392917, 32.187666 |
| Native layout, mount, and first draw | RN Text | 1 | 266.986750, 266.916292, 267.084417, 267.080666, 264.977875, 266.562875, 272.016625, 272.350958, 269.645167 |
| Native layout, mount, and first draw | RN Text | 2 | 278.143166, 283.468542, 278.337625, 278.779917, 312.920292, 277.630125, 280.160833, 280.997541, 297.009708 |
| Native layout, mount, and first draw | RN Text | 3 | 286.175875, 286.524542, 291.472250, 286.374750, 286.302750, 291.034167, 290.317750, 294.193917, 291.295750 |
| Native layout, mount, and first draw | TextView | 1 | 224.407208, 224.396167, 222.809334, 233.144833, 223.831041, 225.103292, 233.047917, 227.070416, 248.853542 |
| Native layout, mount, and first draw | TextView | 2 | 238.253333, 235.618834, 239.612500, 239.470583, 238.701417, 236.378625, 245.944291, 241.137167, 253.118333 |
| Native layout, mount, and first draw | TextView | 3 | 247.166750, 241.579166, 244.860583, 245.177625, 240.656083, 245.077792, 240.277500, 242.951250, 249.134042 |
| Native layout, mount, and first draw | PreparedTextView | 1 | 225.073083, 223.540916, 223.849375, 225.130667, 224.338542, 223.877167, 225.960459, 244.134417, 235.916916 |
| Native layout, mount, and first draw | PreparedTextView | 2 | 238.835083, 235.152750, 235.489917, 243.437542, 246.094334, 245.039042, 240.960750, 240.009750, 237.503250 |
| Native layout, mount, and first draw | PreparedTextView | 3 | 237.401208, 246.599625, 241.567583, 243.221833, 240.297417, 242.851917, 241.183291, 240.701500, 238.808709 |
| Retained paragraph measurement | RN Text | 1 | 8.380875, 8.946500, 8.482542, 8.945375, 8.540834, 8.801917, 8.648083, 8.564917, 8.883083 |
| Retained paragraph measurement | RN Text | 2 | 8.642125, 8.817959, 8.770083, 8.646958, 8.512500, 8.908916, 8.721875, 8.731458, 8.720042 |
| Retained paragraph measurement | RN Text | 3 | 8.953625, 8.762042, 8.555291, 9.304459, 9.558125, 9.499542, 9.158125, 9.000416, 8.820167 |
| Retained paragraph measurement | TextView | 1 | 0.166000, 0.167542, 0.168917, 0.166083, 0.171125, 0.170334, 0.171375, 0.170542, 0.177083 |
| Retained paragraph measurement | TextView | 2 | 0.192417, 0.181542, 0.181375, 0.181208, 0.180708, 0.189583, 0.189166, 0.193500, 0.194834 |
| Retained paragraph measurement | TextView | 3 | 0.188125, 0.187959, 0.183167, 0.179959, 0.198375, 0.200792, 0.187667, 0.187625, 0.187959 |
| Short labels, natural line height | RN Text | 1 | 11.102541, 11.698250, 11.391334, 11.523791, 11.863375, 11.871250, 11.327042, 11.323875, 11.778583 |
| Short labels, natural line height | RN Text | 2 | 11.834583, 12.491958, 11.721166, 11.443834, 11.444167, 12.270084, 12.387584, 12.302000, 11.763333 |
| Short labels, natural line height | RN Text | 3 | 12.078167, 11.991375, 11.664708, 11.842000, 11.677375, 12.568917, 12.531750, 12.556500, 12.531791 |
| Short labels, natural line height | TextView | 1 | 5.153250, 4.754917, 4.753959, 5.023750, 4.656292, 4.717417, 5.076625, 4.844750, 4.856916 |
| Short labels, natural line height | TextView | 2 | 4.803791, 5.345166, 5.091625, 4.879833, 4.972583, 5.025750, 5.043167, 5.052125, 5.038583 |
| Short labels, natural line height | TextView | 3 | 5.214500, 5.123875, 5.239750, 5.074458, 5.693458, 5.460625, 5.322875, 5.290417, 5.308458 |
| Plain text creation and layout | RN Text | 1 | 67.281416, 70.421042, 71.022416, 67.335416, 66.805916, 66.939208, 66.591750, 66.483125, 66.954750 |
| Plain text creation and layout | RN Text | 2 | 68.497208, 68.549750, 69.591417, 70.758500, 69.444625, 68.789250, 69.235417, 68.568375, 71.112375 |
| Plain text creation and layout | RN Text | 3 | 68.786500, 71.615208, 70.359584, 69.573083, 68.740042, 69.696000, 68.975000, 69.011041, 68.736708 |
| Plain text creation and layout | TextView | 1 | 29.130208, 29.244541, 30.167459, 30.170167, 30.162542, 29.795375, 30.101708, 30.069833, 29.772125 |
| Plain text creation and layout | TextView | 2 | 30.584708, 30.574500, 30.684042, 31.740459, 30.993459, 31.158000, 30.781958, 30.995917, 30.567375 |
| Plain text creation and layout | TextView | 3 | 32.098959, 31.414917, 30.201167, 30.201959, 31.753208, 31.351042, 31.738250, 31.388833, 30.546625 |
| Manager queries, 200 keys | RN Text | 1 | 7.717125, 8.441000, 7.834583, 8.234375, 7.854917, 8.009834, 7.928958, 8.168333, 7.960625 |
| Manager queries, 200 keys | RN Text | 2 | 8.244208, 8.493625, 7.920500, 8.531458, 8.233584, 8.491750, 7.903708, 8.425292, 8.043875 |
| Manager queries, 200 keys | RN Text | 3 | 8.062917, 8.146750, 8.122708, 8.270917, 8.334750, 8.134417, 8.177250, 8.121958, 8.150875 |
| Manager queries, 200 keys | TextView | 1 | 1.491250, 1.519792, 1.478000, 1.530375, 1.447917, 1.450625, 1.466292, 1.471959, 1.496042 |
| Manager queries, 200 keys | TextView | 2 | 1.598125, 1.521625, 1.523333, 1.665209, 1.667292, 1.559708, 1.558833, 1.510542, 1.512833 |
| Manager queries, 200 keys | TextView | 3 | 1.564666, 1.550583, 1.576584, 1.572208, 1.530750, 1.519541, 1.565625, 1.528958, 1.576708 |
| Manager queries, 200 keys, two-line limit | RN Text | 1 | 7.846875, 8.219625, 7.718792, 7.925500, 7.850500, 7.619166, 8.040125, 7.749792, 8.196792 |
| Manager queries, 200 keys, two-line limit | RN Text | 2 | 9.485541, 8.957916, 8.952416, 8.834792, 8.216417, 7.983084, 7.947834, 7.869167, 8.058875 |
| Manager queries, 200 keys, two-line limit | RN Text | 3 | 8.952125, 8.641583, 8.630333, 8.279209, 8.154708, 8.150250, 8.170084, 8.292958, 8.163875 |
| Manager queries, 200 keys, two-line limit | TextView | 1 | 3.766833, 3.841708, 3.886667, 4.012250, 4.054375, 3.956792, 3.860958, 3.652458, 3.778541 |
| Manager queries, 200 keys, two-line limit | TextView | 2 | 4.853959, 4.187000, 4.181875, 3.854334, 3.850209, 3.758500, 3.755042, 3.916166, 3.916500 |
| Manager queries, 200 keys, two-line limit | TextView | 3 | 4.186042, 4.231833, 4.148917, 4.138584, 3.965250, 3.972292, 3.898584, 3.870625, 3.902167 |
| Manager queries, 768 keys | RN Text | 1 | 31.841208, 31.213500, 30.934542, 31.283250, 30.646792, 30.813792, 31.226542, 31.043583, 31.438500 |
| Manager queries, 768 keys | RN Text | 2 | 31.931500, 30.642500, 31.435459, 31.570792, 31.712292, 32.967875, 32.217209, 32.743667, 30.692417 |
| Manager queries, 768 keys | RN Text | 3 | 31.872084, 31.801208, 31.970708, 31.863750, 31.861833, 31.949500, 31.746750, 31.993375, 33.007375 |
| Manager queries, 768 keys | TextView | 1 | 5.515917, 5.731500, 5.386166, 5.487625, 5.790208, 5.561083, 5.487875, 5.769625, 5.488125 |
| Manager queries, 768 keys | TextView | 2 | 5.806709, 5.754625, 5.771625, 5.810542, 5.586541, 5.591625, 5.895875, 5.815416, 5.586916 |
| Manager queries, 768 keys | TextView | 3 | 5.670834, 5.795625, 5.712167, 6.019042, 5.662125, 5.765125, 5.688250, 5.681834, 5.890000 |
| Manager queries, 768 keys, two-line limit | RN Text | 1 | 31.425875, 31.069000, 30.814667, 30.710375, 31.326791, 31.208958, 31.111792, 30.973083, 31.081833 |
| Manager queries, 768 keys, two-line limit | RN Text | 2 | 31.700750, 31.065917, 32.183166, 32.194792, 31.094458, 31.427500, 31.192500, 31.272583, 33.080875 |
| Manager queries, 768 keys, two-line limit | RN Text | 3 | 31.928375, 30.996084, 31.582917, 32.029583, 32.110958, 32.426500, 32.134292, 31.719375, 31.758583 |
| Manager queries, 768 keys, two-line limit | TextView | 1 | 14.705625, 14.693584, 15.044750, 14.760958, 14.556917, 14.411166, 14.591167, 14.778791, 14.828167 |
| Manager queries, 768 keys, two-line limit | TextView | 2 | 14.917875, 14.729584, 16.782833, 15.381042, 15.211291, 14.645167, 14.517584, 14.359042, 14.720875 |
| Manager queries, 768 keys, two-line limit | TextView | 3 | 14.747166, 14.708417, 15.918625, 15.143208, 14.936667, 15.180667, 14.907500, 14.535500, 15.947833 |
| Styled text creation and layout | RN Text | 1 | 64.930958, 64.934667, 65.070875, 64.684084, 64.981250, 65.136208, 65.058125, 65.060750, 65.101292 |
| Styled text creation and layout | RN Text | 2 | 68.548709, 66.803750, 66.825209, 67.556375, 69.898625, 69.379708, 66.759750, 66.643792, 67.572084 |
| Styled text creation and layout | RN Text | 3 | 66.653834, 68.014666, 68.647750, 66.572292, 68.153584, 67.841916, 66.892125, 68.179084, 68.482875 |
| Styled text creation and layout | TextView | 1 | 27.589125, 27.542250, 27.874875, 27.574250, 27.585375, 27.682875, 27.639125, 27.920000, 28.165209 |
| Styled text creation and layout | TextView | 2 | 27.965458, 28.379375, 28.017167, 30.851208, 31.043666, 29.175458, 28.838625, 29.605959, 29.163833 |
| Styled text creation and layout | TextView | 3 | 28.216250, 29.192042, 28.791834, 28.541125, 29.149542, 28.870458, 28.320208, 29.157458, 28.829541 |

</details>

### Memory

2026-09-21T05:54:08.761Z. iPhone18,1, iOS 26.6.2 (scale 3). Release build; React Native 0.87.1, Text Engine 0.3.1.

Changes from each pass’s baseline, in KiB: median of three process medians ± median absolute deviation. Each process records five passes after two warm-ups. “Released” is the change remaining after dropping the workload and collecting/draining it; it includes allocator and platform caches and is not a leak measurement.

| Workload | Counter | State | RN Text | TextView | PreparedTextView |
| --- | --- | --- | ---: | ---: | ---: |
| 128 laid-out paragraphs | Native heap | Held | 2163.0 ± 0.0 | 1792.3 ± 0.0 | 1662.5 ± 0.0 |
| 128 laid-out paragraphs | Native heap | Released | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 |
| 128 laid-out paragraphs | Process footprint | Held | 0.0 ± 0.0 | 0.0 ± 0.0 | 32.0 ± 0.0 |
| 128 laid-out paragraphs | Process footprint | Released | 0.0 ± 0.0 | 0.0 ± 0.0 | 32.0 ± 0.0 |
| 128 drawn views and their paragraphs | Native heap | Held | 2669.6 ± 2.3 | 4257.3 ± 1.3 | 4086.6 ± 2.7 |
| 128 drawn views and their paragraphs | Native heap | Released | 16.2 ± 0.2 | 15.7 ± 0.0 | 18.3 ± 0.1 |
| 128 drawn views and their paragraphs | Process footprint | Held | 67152.0 ± 0.0 | 59808.0 ± 0.0 | 59840.0 ± 0.0 |
| 128 drawn views and their paragraphs | Process footprint | Released | 0.0 ± 0.0 | 16.0 ± 0.0 | 48.0 ± 0.0 |

Native heap counts malloc allocations in use. Process footprint also reflects non-heap costs such as drawing backing stores; the counters overlap and must not be added.

<details>
<summary>Memory snapshots (bytes)</summary>

- Git HEAD: `d3920ecf94b3fdd460ec5af2d74c60aea9d7e647`
- Source checksum (SHA256): `e4117320c3604119f0056a2488e5dcc9295200a9f68c030cbd6321cad0278597`

| Workload | Implementation | RN configuration | Run | Counter | Baseline | Held | Released |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| laid_out_chat | RN Text | — | 1 | Native heap | 3377216, 3377024, 3377024, 3377024, 3377024 | 5591952, 5591952, 5591952, 5591952, 5608320 | 3377024, 3377024, 3377024, 3377024, 3393392 |
| laid_out_chat | RN Text | — | 1 | Process footprint | 22774512, 22774512, 22774512, 22774512, 22774512 | 22774512, 22774512, 22774512, 22774512, 22774512 | 22774512, 22774512, 22774512, 22774512, 22774512 |
| mounted_chat | RN Text | — | 1 | Native heap | 3684576, 3720080, 3736448, 3736448, 3736448 | 6448400, 6453744, 6453504, 6453504, 6499872 | 3720080, 3736448, 3736448, 3736448, 3785536 |
| mounted_chat | RN Text | — | 1 | Process footprint | 24232712, 24249096, 24249096, 24249096, 24249096 | 93012768, 93012768, 93012768, 93012768, 93061920 | 24249096, 24249096, 24249096, 24249096, 24298248 |
| laid_out_chat | RN Text | — | 2 | Native heap | 3353232, 3353232, 3353232, 3353232, 3353232 | 5568160, 5568160, 5568160, 5568160, 5584528 | 3353232, 3353232, 3353232, 3353232, 3369600 |
| laid_out_chat | RN Text | — | 2 | Process footprint | 22676232, 22676232, 22676232, 22676232, 22676232 | 22676232, 22676232, 22676232, 22676232, 22676232 | 22676232, 22676232, 22676232, 22676232, 22676232 |
| mounted_chat | RN Text | — | 2 | Native heap | 3656320, 3692048, 3708224, 3724800, 3724608 | 6422144, 6419008, 6435728, 6431040, 6461280 | 3692048, 3708224, 3724800, 3724608, 3757504 |
| mounted_chat | RN Text | — | 2 | Process footprint | 24101640, 24134408, 24134408, 24150792, 24150792 | 92914488, 92914488, 92930872, 92930872, 92930872 | 24134408, 24134408, 24150792, 24150792, 24150792 |
| laid_out_chat | RN Text | — | 3 | Native heap | 3359408, 3359408, 3359408, 3359408, 3359408 | 5574336, 5574336, 5574336, 5574336, 5590704 | 3359408, 3359408, 3359408, 3359408, 3375776 |
| laid_out_chat | RN Text | — | 3 | Process footprint | 22790896, 22790896, 22790896, 22790896, 22790896 | 22790896, 22790896, 22790896, 22790896, 22790896 | 22790896, 22790896, 22790896, 22790896, 22790896 |
| mounted_chat | RN Text | — | 3 | Native heap | 3663264, 3695600, 3714912, 3714912, 3747680 | 6423648, 6431600, 6430848, 6463616, 6475008 | 3695600, 3714912, 3714912, 3747680, 3764000 |
| mounted_chat | RN Text | — | 3 | Process footprint | 24232712, 24249096, 24249096, 24249096, 24265480 | 93012768, 93012768, 93012768, 93029152, 93029152 | 24249096, 24249096, 24249096, 24265480, 24265480 |
| laid_out_chat | TextView | — | 1 | Native heap | 3436864, 3436672, 3436672, 3438240, 3438240 | 5271952, 5271952, 5273520, 5273520, 5273520 | 3436672, 3436672, 3438240, 3438240, 3438240 |
| laid_out_chat | TextView | — | 1 | Process footprint | 22332120, 22332120, 22332120, 22348504, 22348504 | 22332120, 22332120, 22348504, 22348504, 22348504 | 22332120, 22332120, 22348504, 22348504, 22348504 |
| mounted_chat | TextView | — | 1 | Native heap | 3767136, 3767328, 3816112, 3832192, 3849248 | 8133936, 8169392, 8175568, 8190128, 8190352 | 3767328, 3816112, 3832192, 3849248, 3865344 |
| mounted_chat | TextView | — | 1 | Process footprint | 25723632, 25723632, 25756400, 25756400, 25789168 | 86950664, 86983432, 86983432, 87016200, 87032584 | 25723632, 25756400, 25756400, 25789168, 25805552 |
| laid_out_chat | TextView | — | 2 | Native heap | 3444640, 3444448, 3444448, 3444448, 3444448 | 5279728, 5279728, 5279728, 5279728, 5279728 | 3444448, 3444448, 3444448, 3444448, 3444448 |
| laid_out_chat | TextView | — | 2 | Process footprint | 22479576, 22479576, 22479576, 22479576, 22479576 | 22479576, 22479576, 22479576, 22479576, 22479576 | 22479576, 22479576, 22479576, 22479576, 22479576 |
| mounted_chat | TextView | — | 2 | Native heap | 3773536, 3773728, 3838880, 3838592, 3855648 | 8140560, 8191968, 8182144, 8196704, 8196448 | 3773728, 3838880, 3838592, 3855648, 3871744 |
| mounted_chat | TextView | — | 2 | Process footprint | 25854728, 25854728, 25903880, 25903880, 25936648 | 87081760, 87130912, 87130912, 87163680, 87180064 | 25854728, 25903880, 25903880, 25936648, 25953032 |
| laid_out_chat | TextView | — | 3 | Native heap | 3439088, 3439088, 3438896, 3438896, 3438896 | 5274368, 5274176, 5274176, 5274176, 5274176 | 3439088, 3438896, 3438896, 3438896, 3438896 |
| laid_out_chat | TextView | — | 3 | Process footprint | 22446880, 22446880, 22446880, 22446880, 22446880 | 22446880, 22446880, 22446880, 22446880, 22446880 | 22446880, 22446880, 22446880, 22446880, 22446880 |
| mounted_chat | TextView | — | 3 | Native heap | 3767984, 3768176, 3816960, 3833040, 3850096 | 8142384, 8177616, 8184160, 8198720, 8198560 | 3768176, 3816960, 3833040, 3850096, 3866192 |
| mounted_chat | TextView | — | 3 | Process footprint | 25821984, 25821984, 25854752, 25854752, 25887520 | 87049016, 87081784, 87081784, 87114552, 87130936 | 25821984, 25854752, 25854752, 25887520, 25903904 |
| laid_out_chat | PreparedTextView | — | 1 | Native heap | 3448080, 3448080, 3446544, 3446544, 3446544 | 5150496, 5148960, 5148960, 5148960, 5148960 | 3448080, 3446544, 3446544, 3446544, 3446544 |
| laid_out_chat | PreparedTextView | — | 1 | Process footprint | 22364912, 22397680, 22430448, 22463216, 22512368 | 22397680, 22430448, 22463216, 22512368, 22545136 | 22397680, 22430448, 22463216, 22512368, 22545136 |
| mounted_chat | PreparedTextView | — | 1 | Native heap | 3775104, 3775296, 3794032, 3840640, 3873600 | 7955616, 7962720, 8005968, 8029712, 8004976 | 3775296, 3794032, 3840640, 3873600, 3857728 |
| mounted_chat | PreparedTextView | — | 1 | Process footprint | 25887496, 25920264, 25953032, 26018568, 26067720 | 87147296, 87180064, 87245600, 87294752, 87343904 | 25920264, 25953032, 26018568, 26067720, 26116872 |
| laid_out_chat | PreparedTextView | — | 2 | Native heap | 3451312, 3450992, 3450992, 3450992, 3450992 | 5153408, 5153408, 5153408, 5153408, 5153408 | 3450992, 3450992, 3450992, 3450992, 3450992 |
| laid_out_chat | PreparedTextView | — | 2 | Process footprint | 22315760, 22348528, 22381296, 22414064, 22463216 | 22348528, 22381296, 22414064, 22463216, 22495984 | 22348528, 22381296, 22414064, 22463216, 22495984 |
| mounted_chat | PreparedTextView | — | 2 | Native heap | 3779360, 3779360, 3795760, 3844320, 3877088 | 7954400, 7959328, 8004480, 8028416, 8003520 | 3779360, 3795760, 3844320, 3877088, 3861120 |
| mounted_chat | PreparedTextView | — | 2 | Process footprint | 25887472, 25920240, 25953008, 26018544, 26067696 | 87163680, 87196448, 87261984, 87311136, 87360288 | 25920240, 25953008, 26018544, 26067696, 26116848 |
| laid_out_chat | PreparedTextView | — | 3 | Native heap | 3451904, 3451904, 3451904, 3451904, 3451904 | 5154320, 5154320, 5154320, 5154320, 5154320 | 3451904, 3451904, 3451904, 3451904, 3451904 |
| laid_out_chat | PreparedTextView | — | 3 | Process footprint | 22299376, 22332144, 22364912, 22397680, 22446832 | 22332144, 22364912, 22397680, 22446832, 22479600 | 22332144, 22364912, 22397680, 22446832, 22479600 |
| mounted_chat | PreparedTextView | — | 3 | Native heap | 3780528, 3780720, 3799552, 3829696, 3879024 | 7958384, 7965408, 7992432, 8032576, 8022256 | 3780720, 3799552, 3829696, 3879024, 3879520 |
| mounted_chat | PreparedTextView | — | 3 | Process footprint | 25887496, 25920264, 25953032, 26018568, 26067720 | 87147296, 87180064, 87245600, 87294752, 87360288 | 25920264, 25953032, 26018568, 26067720, 26133256 |

</details>

## Android

September 21, 2026. Pixel 6, Android 14 (API 34). React Native 0.87.1, Text Engine 0.3.1, Release build.

### RN Text with default layout

#### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 153.747 ± 0.076 | 109.545 ± 0.040 | 100.782 ± 0.127 | 0.713× | 0.656× |
| Native layout, mount, and first draw | 512 | 894.156 ± 12.048 | 421.735 ± 0.507 | 446.371 ± 1.968 | 0.472× | 0.499× |

#### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 19.196 ± 0.128 | 0.833 ± 0.002 | 0.043× |
| Short labels, natural line height | 512 | 53.665 ± 0.023 | 37.099 ± 0.005 | 0.691× |
| Plain text creation and layout | 512 | 141.817 ± 0.153 | 101.740 ± 0.125 | 0.717× |
| Manager queries, 200 keys | 1,600 | 0.947 ± 0.001 | 0.364 ± 0.001 | 0.385× |
| Manager queries, 200 keys, two-line limit | 1,600 | 0.945 ± 0.002 | 0.380 ± 0.000 | 0.402× |
| Manager queries, 768 keys | 6,144 | 3.910 ± 0.009 | 1.417 ± 0.041 | 0.362× |
| Manager queries, 768 keys, two-line limit | 6,144 | 3.916 ± 0.008 | 1.517 ± 0.001 | 0.388× |
| Styled text creation and layout | 384 | 318.768 ± 0.116 | 189.623 ± 0.481 | 0.595× |

### RN Text with prepared layout

#### Component lifecycle

| Test | Operations/sample | RN Text (ms) | TextView (ms) | PreparedTextView (ms) | TextView / RN | PreparedTextView / RN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chat list layout | 512 | 159.314 ± 0.003 | 109.631 ± 0.169 | 100.586 ± 0.002 | 0.688× | 0.631× |
| Native layout, mount, and first draw | 512 | 450.797 ± 0.029 | 421.789 ± 0.126 | 446.977 ± 0.291 | 0.936× | 0.992× |

#### Measurement

| Test | Operations/sample | RN Text (ms) | TextView (ms) | TextView / RN |
| --- | ---: | ---: | ---: | ---: |
| Retained paragraph measurement | 16,384 | 0.242 ± 0.001 | 0.828 ± 0.012 | 3.418× |
| Short labels, natural line height | 512 | 58.260 ± 0.023 | 37.173 ± 0.016 | 0.638× |
| Plain text creation and layout | 512 | 145.742 ± 0.135 | 101.657 ± 0.157 | 0.698× |
| Manager queries, 200 keys | 1,600 | 6.462 ± 0.100 | 0.348 ± 0.002 | 0.054× |
| Manager queries, 200 keys, two-line limit | 1,600 | 6.642 ± 0.144 | 0.384 ± 0.007 | 0.058× |
| Manager queries, 768 keys | 6,144 | 1745.542 ± 2.258 | 1.460 ± 0.008 | 0.001× |
| Manager queries, 768 keys, two-line limit | 6,144 | 1833.660 ± 5.475 | 1.499 ± 0.014 | 0.001× |
| Styled text creation and layout | 384 | 299.337 ± 0.383 | 189.159 ± 0.313 | 0.632× |

The 200-key manager-query rows hit RN’s prepared-layout cache after warm-up; the 768-key rows miss on every query. The retained-paragraph row measures repeated calls on the same paragraph nodes at unchanged constraints.

<details>
<summary>Run details and samples</summary>

- Started: 2026-09-21T04:30:53.538Z
- Host: Apple M3 Max, Darwin 24.6.0, arm64
- Device: arm64-v8a, density 2.625; ART compilation: speed
- RN defaults: measurement cache 1,024 entries; prepared layout cache 200 entries. Repeated-query workloads visit either 200 or 768 text/width combinations.
- Toolchain: openjdk 17.0.11 2024-04-16 LTS; Gradle 9.4.1; Node v22.21.1
- APK SHA256: `da5680346c73bdfa2e39c8a56bac3868695c6a54805d39a72c5b7f018128745e`
- Git HEAD: `1f88ccf1292d2e7d1cb548100df7c34ca54ef5b8`
- Source checksum (SHA256): `0b0ae332dd054402cb6bb0ae944d69c68ddaba643928ccad21130149df8b1838`

Each row lists nine samples from one app process, in measurement order. All samples are included.

| Test | Implementation | RN configuration | Run | Samples (ms) |
| --- | --- | --- | ---: | --- |
| Chat list layout | RN Text | Default | 1 | 153.424601, 153.461629, 157.399129, 153.741374, 153.747030, 154.031128, 156.451579, 152.040242, 154.194010 |
| Chat list layout | RN Text | Default | 2 | 153.684773, 153.576945, 153.602905, 153.680461, 156.489909, 153.188191, 153.671102, 153.432618, 153.954468 |
| Chat list layout | RN Text | Default | 3 | 153.839274, 153.821859, 153.943074, 153.725423, 155.522420, 154.936401, 154.092733, 153.641114, 154.352295 |
| Chat list layout | RN Text | Prepared | 1 | 162.296061, 163.270834, 159.025472, 159.316365, 159.048136, 159.823364, 160.622762, 158.576823, 157.915487 |
| Chat list layout | RN Text | Prepared | 2 | 157.017578, 160.705811, 158.089721, 158.535767, 159.025594, 158.691894, 160.873820, 160.718790, 159.493530 |
| Chat list layout | RN Text | Prepared | 3 | 159.319539, 160.641357, 156.902506, 162.242472, 157.822062, 157.383179, 160.069702, 159.169678, 159.313680 |
| Chat list layout | TextView | Default | 1 | 108.600464, 108.671875, 109.713745, 109.557455, 109.505249, 109.417399, 110.349284, 108.765381, 109.900554 |
| Chat list layout | TextView | Default | 2 | 108.723796, 109.247599, 109.544922, 109.670573, 108.642131, 109.825155, 109.468587, 109.772054, 111.443359 |
| Chat list layout | TextView | Default | 3 | 108.804606, 108.878134, 109.870891, 109.854492, 109.502279, 110.185466, 110.343343, 109.067057, 110.779581 |
| Chat list layout | TextView | Prepared | 1 | 108.821574, 109.800048, 109.825195, 109.928182, 109.099447, 116.590780, 112.652791, 109.614462, 109.364787 |
| Chat list layout | TextView | Prepared | 2 | 109.148926, 109.705241, 109.630860, 109.685873, 110.059326, 108.395019, 109.285279, 109.684326, 109.327840 |
| Chat list layout | TextView | Prepared | 3 | 109.255737, 109.010417, 109.517741, 109.684814, 108.851318, 109.701213, 109.061442, 109.120931, 108.921753 |
| Chat list layout | PreparedTextView | Default | 1 | 100.508951, 100.782430, 101.521444, 100.763753, 100.966471, 100.734253, 102.219238, 101.051188, 100.456949 |
| Chat list layout | PreparedTextView | Default | 2 | 102.935873, 98.686402, 100.390055, 100.936157, 100.380250, 100.205566, 100.388550, 100.339315, 100.623698 |
| Chat list layout | PreparedTextView | Default | 3 | 101.341593, 100.579020, 100.872925, 101.209513, 100.908936, 100.491943, 100.857218, 101.153483, 104.585409 |
| Chat list layout | PreparedTextView | Prepared | 1 | 100.618002, 100.675496, 101.003825, 100.978638, 101.042277, 100.809082, 103.580445, 102.234334, 101.240519 |
| Chat list layout | PreparedTextView | Prepared | 2 | 100.529907, 100.418172, 100.583944, 100.810751, 100.802368, 100.610393, 102.886515, 99.147623, 100.524210 |
| Chat list layout | PreparedTextView | Prepared | 3 | 100.567382, 100.217815, 100.730143, 100.100871, 100.722941, 100.024007, 100.585897, 102.464803, 100.722860 |
| Native layout, mount, and first draw | RN Text | Default | 1 | 815.897584, 836.516602, 861.918824, 882.903646, 906.603720, 994.998861, 927.396078, 948.797039, 972.260987 |
| Native layout, mount, and first draw | RN Text | Default | 2 | 806.061239, 826.849244, 882.107707, 865.165935, 879.976359, 898.635661, 920.632854, 945.114095, 970.603760 |
| Native layout, mount, and first draw | RN Text | Default | 3 | 814.710938, 894.156128, 846.137818, 863.125936, 892.755779, 915.860840, 944.685547, 964.714355, 1063.695190 |
| Native layout, mount, and first draw | RN Text | Prepared | 1 | 453.035238, 450.797486, 451.380534, 450.519003, 448.802409, 449.824504, 450.556885, 453.020711, 450.818441 |
| Native layout, mount, and first draw | RN Text | Prepared | 2 | 450.125123, 451.476197, 450.596557, 455.698487, 451.312012, 451.030884, 452.083985, 449.566814, 451.522664 |
| Native layout, mount, and first draw | RN Text | Prepared | 3 | 449.991008, 450.768270, 454.529175, 452.133708, 452.275839, 450.245361, 453.472982, 450.187419, 450.728475 |
| Native layout, mount, and first draw | TextView | Default | 1 | 421.662232, 425.809937, 428.779053, 421.943726, 423.103313, 422.327922, 427.661418, 426.229330, 421.128500 |
| Native layout, mount, and first draw | TextView | Default | 2 | 420.239218, 421.411743, 423.724244, 420.261637, 419.345785, 420.204264, 421.944458, 424.974772, 421.228150 |
| Native layout, mount, and first draw | TextView | Default | 3 | 421.989624, 420.542563, 421.735474, 422.189739, 424.926474, 421.251018, 420.619059, 421.923869, 420.617554 |
| Native layout, mount, and first draw | TextView | Prepared | 1 | 419.282756, 421.103353, 422.058310, 419.788696, 420.335897, 420.105428, 423.081503, 421.789388, 421.004842 |
| Native layout, mount, and first draw | TextView | Prepared | 2 | 422.968262, 421.945597, 421.789185, 420.299764, 420.460938, 420.108765, 423.378093, 421.824951, 420.907308 |
| Native layout, mount, and first draw | TextView | Prepared | 3 | 420.670492, 421.176758, 420.813152, 421.668783, 423.832275, 421.915487, 424.186158, 422.871582, 425.255371 |
| Native layout, mount, and first draw | PreparedTextView | Default | 1 | 444.462647, 448.630127, 444.632243, 444.359660, 444.336141, 444.799398, 444.352336, 444.140218, 444.403240 |
| Native layout, mount, and first draw | PreparedTextView | Default | 2 | 447.207276, 444.710246, 446.321329, 446.371216, 449.201619, 445.338623, 446.346598, 446.386028, 449.434490 |
| Native layout, mount, and first draw | PreparedTextView | Default | 3 | 450.563355, 452.298747, 448.350098, 448.024129, 446.692586, 450.392660, 447.132365, 451.398845, 448.504639 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 1 | 445.898316, 446.506674, 450.222331, 446.686524, 446.243164, 446.321289, 449.179973, 447.677125, 447.204834 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 2 | 446.115316, 447.217937, 445.636353, 447.334798, 446.150716, 447.688233, 446.013997, 446.977296, 449.926432 |
| Native layout, mount, and first draw | PreparedTextView | Prepared | 3 | 450.598674, 448.024862, 446.570109, 446.279704, 451.012044, 448.056152, 447.448934, 446.631674, 448.729696 |
| Retained paragraph measurement | RN Text | Default | 1 | 19.275268, 19.576538, 19.215210, 19.262533, 19.616170, 19.324096, 19.225748, 20.155802, 19.539184 |
| Retained paragraph measurement | RN Text | Default | 2 | 19.117920, 19.196493, 19.219930, 19.312907, 19.288248, 19.213786, 19.140137, 19.151936, 19.153930 |
| Retained paragraph measurement | RN Text | Default | 3 | 19.068034, 19.022950, 19.028239, 19.020386, 19.056966, 19.077108, 19.048299, 19.032796, 19.005575 |
| Retained paragraph measurement | RN Text | Prepared | 1 | 0.242798, 0.242513, 0.242351, 0.242513, 0.241903, 0.242106, 0.264242, 0.241902, 0.242106 |
| Retained paragraph measurement | RN Text | Prepared | 2 | 0.241333, 0.241374, 0.282389, 0.241577, 0.241455, 0.241414, 0.241374, 0.241659, 0.241211 |
| Retained paragraph measurement | RN Text | Prepared | 3 | 0.246622, 0.246501, 0.246664, 0.246338, 0.246460, 0.246542, 0.246378, 0.246704, 0.246338 |
| Retained paragraph measurement | TextView | Default | 1 | 0.832520, 0.831625, 0.832438, 0.831868, 0.864380, 0.837687, 0.836752, 0.839844, 0.837117 |
| Retained paragraph measurement | TextView | Default | 2 | 0.830159, 0.970215, 0.830607, 0.830119, 0.829671, 0.831095, 0.875447, 0.830159, 0.831584 |
| Retained paragraph measurement | TextView | Default | 3 | 0.830892, 0.830363, 0.832967, 0.869629, 0.835124, 0.833049, 0.832316, 0.832926, 0.846802 |
| Retained paragraph measurement | TextView | Prepared | 1 | 0.942586, 0.836141, 0.835693, 0.835123, 0.836792, 1.252523, 0.840494, 0.839844, 0.839803 |
| Retained paragraph measurement | TextView | Prepared | 2 | 0.849650, 0.826661, 0.827189, 0.826416, 0.840495, 0.828328, 0.828206, 0.829183, 0.828288 |
| Retained paragraph measurement | TextView | Prepared | 3 | 0.813274, 0.813355, 0.847616, 0.814006, 0.812826, 0.813477, 0.812989, 0.845093, 0.812907 |
| Short labels, natural line height | RN Text | Default | 1 | 53.657552, 53.660726, 53.664754, 57.247193, 53.650635, 53.914429, 53.705282, 54.029745, 53.606852 |
| Short labels, natural line height | RN Text | Default | 2 | 53.437216, 53.724528, 53.933472, 53.687988, 53.592937, 53.609050, 53.714925, 56.059937, 50.417724 |
| Short labels, natural line height | RN Text | Default | 3 | 52.114502, 56.207967, 53.737182, 53.624634, 53.399007, 53.309286, 56.532511, 50.600342, 52.858399 |
| Short labels, natural line height | RN Text | Prepared | 1 | 57.767903, 58.236939, 58.185587, 58.475260, 58.741821, 57.263468, 58.452108, 58.232747, 58.254395 |
| Short labels, natural line height | RN Text | Prepared | 2 | 60.730591, 59.966350, 58.101441, 58.087118, 60.640747, 54.984253, 58.267252, 58.260376, 58.197103 |
| Short labels, natural line height | RN Text | Prepared | 3 | 58.308187, 58.333984, 58.285848, 58.127238, 61.178914, 58.102011, 58.303630, 58.389608, 58.292196 |
| Short labels, natural line height | TextView | Default | 1 | 37.337321, 37.301636, 37.417929, 38.783162, 34.403321, 35.668335, 37.090617, 37.104371, 37.056193 |
| Short labels, natural line height | TextView | Default | 2 | 37.141846, 37.284017, 37.420857, 39.682739, 35.433797, 35.189982, 36.718669, 37.062745, 37.027873 |
| Short labels, natural line height | TextView | Default | 3 | 37.640991, 37.071370, 37.357585, 39.835694, 34.398112, 35.379435, 37.260132, 37.081991, 37.099243 |
| Short labels, natural line height | TextView | Prepared | 1 | 36.670573, 37.209351, 37.104615, 37.096924, 37.086833, 37.189249, 37.201742, 37.313843, 37.352580 |
| Short labels, natural line height | TextView | Prepared | 2 | 37.021444, 37.059977, 37.031576, 37.027140, 37.176880, 37.172811, 37.250773, 37.179891, 37.247192 |
| Short labels, natural line height | TextView | Prepared | 3 | 35.842448, 37.038086, 37.015259, 36.977417, 36.853719, 37.008667, 37.031617, 37.255738, 36.951945 |
| Plain text creation and layout | RN Text | Default | 1 | 142.652263, 141.813192, 141.693196, 141.937378, 141.969889, 143.108724, 141.386638, 146.177612, 144.315958 |
| Plain text creation and layout | RN Text | Default | 2 | 139.226563, 141.411621, 141.474976, 141.564209, 144.093018, 142.011638, 141.800171, 141.466471, 141.330770 |
| Plain text creation and layout | RN Text | Default | 3 | 141.816813, 143.215902, 141.730835, 141.305949, 148.386068, 142.995768, 141.721843, 142.528768, 141.402588 |
| Plain text creation and layout | RN Text | Prepared | 1 | 150.785970, 146.845418, 145.415202, 142.799764, 145.656250, 144.767660, 142.876953, 145.607259, 145.682536 |
| Plain text creation and layout | RN Text | Prepared | 2 | 151.027059, 145.741781, 145.382325, 145.369466, 148.690348, 145.626262, 145.813233, 144.664795, 145.866455 |
| Plain text creation and layout | RN Text | Prepared | 3 | 146.218913, 146.091756, 145.912475, 145.860229, 147.959676, 143.523316, 147.687622, 146.020386, 145.627685 |
| Plain text creation and layout | TextView | Default | 1 | 101.833984, 101.525309, 101.482015, 101.462403, 101.386475, 101.987508, 102.017090, 101.740072, 102.497803 |
| Plain text creation and layout | TextView | Default | 2 | 100.518514, 104.875569, 101.668701, 101.428304, 101.609131, 101.982910, 102.226399, 101.587606, 101.598592 |
| Plain text creation and layout | TextView | Default | 3 | 101.902425, 101.865357, 101.504028, 101.653565, 101.417277, 101.852010, 101.966838, 102.229288, 103.331706 |
| Plain text creation and layout | TextView | Prepared | 1 | 101.751384, 102.107097, 103.946818, 101.967041, 101.822266, 101.016520, 101.838785, 102.351278, 102.341187 |
| Plain text creation and layout | TextView | Prepared | 2 | 101.499268, 101.757894, 101.572144, 101.472371, 102.441447, 99.231527, 101.449259, 101.555501, 101.448975 |
| Plain text creation and layout | TextView | Prepared | 3 | 101.594564, 101.680461, 101.981852, 101.528076, 101.397014, 100.474406, 101.762533, 101.656697, 101.740886 |
| Manager queries, 200 keys | RN Text | Default | 1 | 0.956096, 0.945963, 0.971110, 0.944255, 0.949218, 0.946411, 0.966023, 0.948974, 0.948812 |
| Manager queries, 200 keys | RN Text | Default | 2 | 0.946085, 0.948405, 0.945516, 0.971354, 0.944987, 0.944255, 0.943970, 0.964071, 0.948039 |
| Manager queries, 200 keys | RN Text | Default | 3 | 0.959595, 0.947998, 0.946208, 0.947102, 0.944906, 0.995647, 0.946492, 0.948364, 0.944987 |
| Manager queries, 200 keys | RN Text | Prepared | 1 | 6.545532, 6.569825, 6.591471, 6.770345, 6.662476, 6.820679, 8.484578, 6.864258, 6.599976 |
| Manager queries, 200 keys | RN Text | Prepared | 2 | 6.352457, 6.425537, 6.362752, 6.346273, 6.457275, 6.334391, 6.371460, 6.317708, 6.366496 |
| Manager queries, 200 keys | RN Text | Prepared | 3 | 6.488200, 6.462362, 6.534302, 6.442993, 6.443563, 6.470947, 6.460490, 6.535767, 6.425781 |
| Manager queries, 200 keys | TextView | Default | 1 | 0.372151, 0.372437, 0.367269, 0.351359, 0.357666, 0.362752, 0.364746, 0.362671, 0.364257 |
| Manager queries, 200 keys | TextView | Default | 2 | 0.365193, 0.357503, 0.369588, 0.369141, 0.361246, 0.361287, 0.363688, 0.365357, 0.369955 |
| Manager queries, 200 keys | TextView | Default | 3 | 0.359131, 0.365601, 0.362183, 0.361206, 0.365926, 0.349121, 0.393554, 0.365966, 0.362549 |
| Manager queries, 200 keys | TextView | Prepared | 1 | 0.478638, 0.367391, 0.381511, 0.481730, 0.347168, 0.347208, 0.347697, 0.345581, 0.348267 |
| Manager queries, 200 keys | TextView | Prepared | 2 | 0.347738, 0.394694, 0.350260, 0.376831, 0.345296, 0.346436, 0.341960, 0.345012, 0.345784 |
| Manager queries, 200 keys | TextView | Prepared | 3 | 0.384522, 0.380208, 0.388509, 0.378215, 0.381958, 0.378418, 0.386108, 0.379598, 0.376709 |
| Manager queries, 200 keys, two-line limit | RN Text | Default | 1 | 0.952718, 0.984904, 0.938680, 0.898152, 0.898560, 0.899821, 0.929972, 0.900879, 0.898194 |
| Manager queries, 200 keys, two-line limit | RN Text | Default | 2 | 0.942627, 0.943074, 0.999145, 0.946167, 0.944865, 0.944539, 0.978719, 0.945923, 0.943155 |
| Manager queries, 200 keys, two-line limit | RN Text | Default | 3 | 0.944540, 0.950887, 0.947266, 0.972412, 0.946900, 0.946005, 0.943441, 0.947265, 1.046509 |
| Manager queries, 200 keys, two-line limit | RN Text | Prepared | 1 | 6.882853, 6.788940, 6.902344, 6.773315, 6.747681, 6.864746, 6.795532, 6.805949, 6.783162 |
| Manager queries, 200 keys, two-line limit | RN Text | Prepared | 2 | 6.497640, 6.459391, 6.583659, 6.491618, 6.576620, 6.520142, 6.451945, 6.525554, 6.487223 |
| Manager queries, 200 keys, two-line limit | RN Text | Prepared | 3 | 6.629964, 6.662150, 6.581258, 6.667684, 6.627930, 6.594482, 6.698364, 6.641887, 6.666545 |
| Manager queries, 200 keys, two-line limit | TextView | Default | 1 | 0.381633, 0.383870, 0.371134, 0.376343, 0.381266, 0.390543, 0.375528, 0.377563, 0.379761 |
| Manager queries, 200 keys, two-line limit | TextView | Default | 2 | 0.396566, 0.376994, 0.377482, 0.393798, 0.387126, 0.378906, 0.380656, 0.378662, 0.379761 |
| Manager queries, 200 keys, two-line limit | TextView | Default | 3 | 0.391968, 0.377238, 0.377808, 0.364340, 0.382568, 0.375529, 0.372518, 0.374308, 0.393554 |
| Manager queries, 200 keys, two-line limit | TextView | Prepared | 1 | 0.362467, 0.361572, 0.358398, 0.359904, 0.369466, 0.420491, 0.360921, 0.359130, 0.361613 |
| Manager queries, 200 keys, two-line limit | TextView | Prepared | 2 | 0.386719, 0.391845, 0.378215, 0.374430, 0.384115, 0.376709, 0.383667, 0.380615, 0.384400 |
| Manager queries, 200 keys, two-line limit | TextView | Prepared | 3 | 0.390177, 0.418050, 0.389526, 0.392049, 0.410197, 0.393555, 0.388306, 0.385294, 0.386149 |
| Manager queries, 768 keys | RN Text | Default | 1 | 3.934571, 3.918701, 3.920898, 3.927897, 3.937622, 3.911784, 3.915161, 3.903605, 3.917522 |
| Manager queries, 768 keys | RN Text | Default | 2 | 3.914999, 3.906413, 3.898112, 3.935344, 3.909872, 3.910441, 3.907877, 3.929403, 3.899414 |
| Manager queries, 768 keys | RN Text | Default | 3 | 3.919230, 3.882609, 3.901530, 3.890055, 3.938314, 3.895549, 3.897746, 3.885336, 3.905396 |
| Manager queries, 768 keys | RN Text | Prepared | 1 | 1751.448691, 1748.875204, 1745.661907, 1745.542441, 1752.191204, 1738.280274, 1733.623943, 1737.840333, 1735.161622 |
| Manager queries, 768 keys | RN Text | Prepared | 2 | 1747.782513, 1750.091472, 1742.838420, 2583.933676, 1750.426189, 1743.284588, 1738.165446, 1736.285808, 1730.402019 |
| Manager queries, 768 keys | RN Text | Prepared | 3 | 1754.781617, 1749.720948, 1757.200970, 1759.081015, 1751.312460, 1759.043620, 1737.227540, 1737.235475, 1738.033611 |
| Manager queries, 768 keys | TextView | Default | 1 | 1.424561, 1.397095, 1.407268, 1.537312, 1.414184, 1.425496, 1.401571, 1.416951, 1.436605 |
| Manager queries, 768 keys | TextView | Default | 2 | 1.461466, 1.548381, 1.468587, 1.433797, 1.438802, 1.726522, 1.440389, 3.326823, 1.373861 |
| Manager queries, 768 keys | TextView | Default | 3 | 1.364014, 1.375488, 1.360718, 1.357178, 1.414225, 1.364706, 1.376139, 1.415202, 1.389812 |
| Manager queries, 768 keys | TextView | Prepared | 1 | 1.446127, 1.446696, 1.467448, 1.457113, 1.441447, 1.479899, 1.448568, 1.472453, 1.452189 |
| Manager queries, 768 keys | TextView | Prepared | 2 | 1.455730, 1.482544, 1.444417, 1.450846, 1.589152, 1.459716, 1.483033, 1.476847, 1.455241 |
| Manager queries, 768 keys | TextView | Prepared | 3 | 1.514485, 1.537394, 1.530193, 1.642334, 1.529826, 1.528727, 1.562460, 1.538411, 1.539714 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 1 | 3.914836, 3.921793, 3.915650, 3.945394, 3.923340, 3.910237, 3.915772, 3.936808, 3.915120 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 2 | 3.918864, 3.923787, 3.915894, 3.956543, 3.916830, 3.924683, 3.928304, 3.954631, 3.912231 |
| Manager queries, 768 keys, two-line limit | RN Text | Default | 3 | 3.920858, 3.883016, 3.885294, 3.881470, 3.917928, 3.885701, 3.861043, 3.884847, 3.888754 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 1 | 1822.992636, 1838.757081, 1843.244467, 1831.149170, 1847.169720, 1833.659669, 1829.974447, 2319.728558, 1821.470826 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 2 | 1839.599000, 1829.757976, 1842.454021, 1822.099692, 1828.184286, 1831.362021, 1827.656739, 1827.243124, 1821.544271 |
| Manager queries, 768 keys, two-line limit | RN Text | Prepared | 3 | 1831.316570, 1859.952312, 1849.943726, 1832.786988, 1838.496095, 1842.766562, 1834.999919, 1844.099570, 2008.095622 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 1 | 1.518107, 1.533854, 1.517334, 1.511475, 1.536540, 1.518067, 1.502400, 1.558024, 1.511027 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 2 | 1.512329, 1.514892, 1.622030, 1.512248, 1.527588, 1.534261, 1.508667, 1.562093, 1.508341 |
| Manager queries, 768 keys, two-line limit | TextView | Default | 3 | 1.508667, 1.517415, 1.529419, 1.513591, 1.530599, 1.507568, 1.514282, 2.063558, 1.540569 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 1 | 1.485717, 1.492595, 1.608683, 1.488119, 1.498942, 1.508179, 1.501506, 1.511230, 1.486857 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 2 | 1.484375, 1.492717, 1.473918, 1.484660, 1.495118, 1.481486, 1.467652, 1.604452, 1.496013 |
| Manager queries, 768 keys, two-line limit | TextView | Prepared | 3 | 1.569010, 1.555053, 1.546468, 1.591268, 1.542155, 1.668497, 1.558594, 1.544678, 1.578165 |
| Styled text creation and layout | RN Text | Default | 1 | 318.767944, 317.014568, 317.877767, 319.859416, 317.206299, 321.607707, 318.332032, 323.815389, 319.423136 |
| Styled text creation and layout | RN Text | Default | 2 | 316.661377, 320.646119, 318.885742, 318.044149, 318.175741, 318.651571, 318.396281, 330.415934, 319.262695 |
| Styled text creation and layout | RN Text | Default | 3 | 317.728027, 320.365682, 319.115234, 319.102580, 316.749024, 319.153850, 318.814657, 320.384115, 316.383545 |
| Styled text creation and layout | RN Text | Prepared | 1 | 300.676066, 305.440104, 299.376465, 296.760539, 299.336670, 296.313477, 297.330810, 299.600383, 296.083130 |
| Styled text creation and layout | RN Text | Prepared | 2 | 300.392619, 297.981120, 301.736654, 299.334554, 297.161052, 297.979696, 298.048014, 296.918091, 299.164714 |
| Styled text creation and layout | RN Text | Prepared | 3 | 304.113322, 298.225424, 304.103516, 297.490642, 300.039999, 299.548136, 299.719239, 305.252238, 297.097128 |
| Styled text creation and layout | TextView | Default | 1 | 189.569743, 189.622721, 189.357422, 188.779093, 195.746013, 190.029012, 189.283366, 191.181884, 193.179646 |
| Styled text creation and layout | TextView | Default | 2 | 189.017293, 190.109660, 189.476074, 189.371216, 192.232911, 190.742798, 190.829874, 190.566528, 190.744100 |
| Styled text creation and layout | TextView | Default | 3 | 188.672851, 189.016032, 189.914470, 188.592692, 195.806275, 189.493165, 189.141887, 188.919230, 190.891032 |
| Styled text creation and layout | TextView | Prepared | 1 | 189.469360, 189.472208, 193.652425, 189.593140, 190.039876, 189.241170, 189.139323, 190.840251, 188.534302 |
| Styled text creation and layout | TextView | Prepared | 2 | 188.534587, 189.732178, 192.754029, 188.457072, 188.145101, 188.307495, 188.441976, 193.216675, 189.723226 |
| Styled text creation and layout | TextView | Prepared | 3 | 188.573690, 188.389852, 197.674235, 188.606486, 190.339803, 188.533732, 192.284261, 190.241618, 189.159017 |

</details>

### Memory

2026-09-21T06:09:55.455Z. Pixel 6, Android 14 (API 34, arm64-v8a, density 2.625). Release build; React Native 0.87.1, Text Engine 0.3.1.

Changes from each pass’s baseline, in KiB: median of three process medians ± median absolute deviation. Each process records five passes after two warm-ups. “Released” is the change remaining after dropping the workload and collecting/draining it; it includes allocator and platform caches and is not a leak measurement.

#### RN default layout

| Workload | Counter | State | RN Text | TextView | PreparedTextView |
| --- | --- | --- | ---: | ---: | ---: |
| 128 laid-out paragraphs | Native heap | Held | 1582.2 ± 0.0 | 994.6 ± 0.0 | 769.6 ± 0.0 |
| 128 laid-out paragraphs | Native heap | Released | 1.1 ± 0.0 | 1.1 ± 0.0 | 1.1 ± 0.0 |
| 128 laid-out paragraphs | Managed heap | Held | 8.0 ± 8.0 | 252.0 ± 0.0 | 108.0 ± 0.0 |
| 128 laid-out paragraphs | Managed heap | Released | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 |
| 128 drawn views and their paragraphs | Native heap | Held | 1890.1 ± 0.0 | 1434.5 ± 0.0 | 1267.6 ± 0.0 |
| 128 drawn views and their paragraphs | Native heap | Released | 1.1 ± 0.0 | 1.1 ± 0.0 | 1.1 ± 0.0 |
| 128 drawn views and their paragraphs | Managed heap | Held | 708.0 ± 0.0 | 588.0 ± 0.0 | 524.0 ± 0.0 |
| 128 drawn views and their paragraphs | Managed heap | Released | 8.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 |

#### RN prepared layout

| Workload | Counter | State | RN Text | TextView | PreparedTextView |
| --- | --- | --- | ---: | ---: | ---: |
| 128 laid-out paragraphs | Native heap | Held | 1644.1 ± 0.0 | 994.6 ± 0.0 | 769.6 ± 0.0 |
| 128 laid-out paragraphs | Native heap | Released | 1.1 ± 0.0 | 1.1 ± 0.0 | 1.1 ± 0.0 |
| 128 laid-out paragraphs | Managed heap | Held | 360.0 ± 12.0 | 252.0 ± 0.0 | 112.0 ± 0.0 |
| 128 laid-out paragraphs | Managed heap | Released | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 |
| 128 drawn views and their paragraphs | Native heap | Held | 1856.1 ± 0.0 | 1434.5 ± 0.0 | 1267.6 ± 0.0 |
| 128 drawn views and their paragraphs | Native heap | Released | 1.1 ± 0.0 | 1.1 ± 0.0 | 1.1 ± 0.0 |
| 128 drawn views and their paragraphs | Managed heap | Held | 548.0 ± 0.0 | 592.0 ± 0.0 | 520.0 ± 0.0 |
| 128 drawn views and their paragraphs | Managed heap | Released | 0.0 ± 0.0 | 0.0 ± 0.0 | 0.0 ± 0.0 |

Managed heap is sampled after explicit garbage collection, with collection progress checked. Native heap uses the allocator’s allocated-byte counter. The common software canvas is allocated before the baseline; this benchmark does not create per-view GPU surfaces.

<details>
<summary>Memory snapshots (bytes)</summary>

- Git HEAD: `d3920ecf94b3fdd460ec5af2d74c60aea9d7e647`
- Source checksum (SHA256): `92a2556f00a3f3a1ac4c37303b3515e97991c54694d6f3711840701fa0c2dd93`

| Workload | Implementation | RN configuration | Run | Counter | Baseline | Held | Released |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| laid_out_chat | RN Text | Default | 1 | Native heap | 9244032, 9244512, 9244912, 9244960, 9245856 | 10864240, 10864672, 10865072, 10865120, 10865968 | 9245232, 9245664, 9246064, 9246112, 9246960 |
| laid_out_chat | RN Text | Default | 1 | Managed heap | 2461280, 2461280, 2461280, 2461280, 2461280 | 2506336, 2461280, 2461280, 2461280, 2473568 | 2461280, 2461280, 2461280, 2461280, 2461280 |
| mounted_chat | RN Text | Default | 1 | Native heap | 9676192, 9676336, 9676384, 9682208, 9682208 | 11611776, 11611824, 11616176, 11617648, 11617648 | 9677440, 9677488, 9681840, 9683312, 9683312 |
| mounted_chat | RN Text | Default | 1 | Managed heap | 2584352, 2592544, 2600736, 2608928, 2621216 | 3305248, 3317536, 3338016, 3333920, 3342112 | 2592544, 2600736, 2608928, 2621216, 2629408 |
| laid_out_chat | RN Text | Default | 2 | Native heap | 9244048, 9244528, 9244928, 9244976, 9245872 | 10864256, 10864688, 10865088, 10865136, 10865984 | 9245248, 9245680, 9246080, 9246128, 9246976 |
| laid_out_chat | RN Text | Default | 2 | Managed heap | 2461280, 2461280, 2461280, 2461280, 2461280 | 2522720, 2461280, 2481760, 2461280, 2481760 | 2461280, 2461280, 2461280, 2461280, 2461280 |
| mounted_chat | RN Text | Default | 2 | Native heap | 9676176, 9676320, 9676368, 9682192, 9682192 | 11611760, 11611808, 11616160, 11617632, 11617632 | 9677424, 9677472, 9681824, 9683296, 9683296 |
| mounted_chat | RN Text | Default | 2 | Managed heap | 2584352, 2658080, 2600736, 2608928, 2621216 | 3305248, 3317536, 3325728, 3333920, 3342112 | 2592544, 2600736, 2608928, 2621216, 2629408 |
| laid_out_chat | RN Text | Default | 3 | Native heap | 9234704, 9235184, 9235584, 9235632, 9236528 | 10854912, 10855344, 10855744, 10855792, 10856640 | 9235904, 9236336, 9236736, 9236784, 9237632 |
| laid_out_chat | RN Text | Default | 3 | Managed heap | 2453088, 2453088, 2453088, 2453088, 2453088 | 2489952, 2461280, 2469472, 2453088, 2453088 | 2453088, 2453088, 2453088, 2453088, 2453088 |
| mounted_chat | RN Text | Default | 3 | Native heap | 9666688, 9666832, 9666832, 9672656, 9672704 | 11602272, 11602272, 11606624, 11608144, 11608144 | 9667936, 9667936, 9672288, 9673808, 9673808 |
| mounted_chat | RN Text | Default | 3 | Managed heap | 2576160, 2588448, 2596640, 2604832, 2617120 | 3301152, 3309344, 3419936, 3329824, 3338016 | 2588448, 2596640, 2604832, 2617120, 2625312 |
| laid_out_chat | TextView | Default | 1 | Native heap | 9228240, 9228672, 9229024, 9229072, 9229920 | 10246688, 10247072, 10247472, 10247472, 10248368 | 9229392, 9229776, 9230176, 9230176, 9231072 |
| laid_out_chat | TextView | Default | 1 | Managed heap | 2440768, 2440768, 2440768, 2440768, 2440768 | 2702912, 2702912, 2702912, 2702912, 2702912 | 2440768, 2440768, 2440768, 2440768, 2440768 |
| mounted_chat | TextView | Default | 1 | Native heap | 9667728, 9667776, 9667824, 9669344, 9669392 | 11136672, 11136720, 11136768, 11138320, 11138320 | 9668880, 9668928, 9668976, 9670496, 9670496 |
| mounted_chat | TextView | Default | 1 | Managed heap | 2486000, 2486000, 2486000, 2486000, 2486000 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2486000, 2486000, 2486000, 2486000, 2486000 |
| laid_out_chat | TextView | Default | 2 | Native heap | 9237344, 9237776, 9238128, 9238176, 9239024 | 10255792, 10256176, 10256576, 10256576, 10257472 | 9238496, 9238880, 9239280, 9239280, 9240176 |
| laid_out_chat | TextView | Default | 2 | Managed heap | 2444864, 2444864, 2444864, 2444864, 2444864 | 2702912, 2702912, 2702912, 2702912, 2702912 | 2444864, 2444864, 2444864, 2444864, 2444864 |
| mounted_chat | TextView | Default | 2 | Native heap | 9677072, 9677120, 9677168, 9678688, 9678736 | 11146016, 11146096, 11146112, 11147632, 11147664 | 9678224, 9678272, 9678320, 9679840, 9679872 |
| mounted_chat | TextView | Default | 2 | Managed heap | 2490096, 2490096, 2490096, 2490096, 2490096 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2490096, 2490096, 2490096, 2490096, 2490096 |
| laid_out_chat | TextView | Default | 3 | Native heap | 9237472, 9237904, 9238256, 9238304, 9239152 | 10255920, 10256304, 10256704, 10256704, 10257600 | 9238624, 9239008, 9239408, 9239408, 9240304 |
| laid_out_chat | TextView | Default | 3 | Managed heap | 2444864, 2444864, 2444864, 2444864, 2444864 | 2702912, 2702912, 2702912, 2702912, 2702912 | 2444864, 2444864, 2444864, 2444864, 2444864 |
| mounted_chat | TextView | Default | 3 | Native heap | 9677136, 9677184, 9677232, 9678752, 9678800 | 11146080, 11146128, 11146176, 11147728, 11147696 | 9678288, 9678336, 9678384, 9679936, 9679936 |
| mounted_chat | TextView | Default | 3 | Managed heap | 2490096, 2490096, 2490096, 2490096, 2490096 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2490096, 2490096, 2490096, 2490096, 2490096 |
| laid_out_chat | PreparedTextView | Default | 1 | Native heap | 9236656, 9237088, 9237440, 9237440, 9238336 | 10022560, 10025056, 10023424, 10025376, 10026416 | 9237808, 9238192, 9238544, 9238592, 9239440 |
| laid_out_chat | PreparedTextView | Default | 1 | Managed heap | 2440768, 2440768, 2440768, 2440768, 2440768 | 2551360, 2551360, 2551360, 2551360, 2551360 | 2440768, 2440768, 2440768, 2440768, 2440768 |
| mounted_chat | PreparedTextView | Default | 1 | Native heap | 9662064, 9662112, 9662704, 9664224, 9664272 | 10959936, 10960560, 10960672, 10961136, 10962176 | 9663216, 9663808, 9663856, 9665376, 9665424 |
| mounted_chat | PreparedTextView | Default | 1 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3014096, 3014096, 3014096, 3014096, 3014096 | 2477520, 2477520, 2477520, 2477520, 2477520 |
| laid_out_chat | PreparedTextView | Default | 2 | Native heap | 9236912, 9237344, 9237696, 9237696, 9238592 | 10025040, 10025424, 10025776, 10025824, 10026672 | 9238064, 9238448, 9238800, 9238848, 9239696 |
| laid_out_chat | PreparedTextView | Default | 2 | Managed heap | 2440768, 2440768, 2440768, 2440768, 2440768 | 2551360, 2551360, 2551360, 2551360, 2551360 | 2440768, 2440768, 2440768, 2440768, 2440768 |
| mounted_chat | PreparedTextView | Default | 2 | Native heap | 9662224, 9662272, 9662320, 9663840, 9663888 | 10960272, 10960320, 10960336, 10961856, 10961904 | 9663376, 9663424, 9663472, 9664992, 9665040 |
| mounted_chat | PreparedTextView | Default | 2 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3014096, 3014096, 3014096, 3014096, 3014096 | 2477520, 2477520, 2477520, 2477520, 2477520 |
| laid_out_chat | PreparedTextView | Default | 3 | Native heap | 9236848, 9237280, 9237632, 9237632, 9238528 | 10024976, 10025360, 10025712, 10025760, 10026608 | 9238000, 9238384, 9238736, 9238784, 9239632 |
| laid_out_chat | PreparedTextView | Default | 3 | Managed heap | 2440768, 2440768, 2440768, 2440768, 2440768 | 2551360, 2551360, 2551360, 2551360, 2551360 | 2440768, 2440768, 2440768, 2440768, 2440768 |
| mounted_chat | PreparedTextView | Default | 3 | Native heap | 9662256, 9662304, 9662352, 9663872, 9663920 | 10960272, 10960352, 10960400, 10961920, 10961936 | 9663408, 9663456, 9663504, 9665024, 9665072 |
| mounted_chat | PreparedTextView | Default | 3 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3014096, 3014096, 3014096, 3014096, 3014096 | 2477520, 2477520, 2477520, 2477520, 2477520 |
| laid_out_chat | RN Text | Prepared | 1 | Native heap | 9234592, 9235072, 9235472, 9235520, 9236416 | 10918224, 10918656, 10919056, 10919104, 10919952 | 9235792, 9236224, 9236624, 9236672, 9237520 |
| laid_out_chat | RN Text | Prepared | 1 | Managed heap | 2444896, 2444896, 2444896, 2444896, 2444896 | 2829920, 2788960, 2788960, 2821728, 2813536 | 2444896, 2444896, 2444896, 2444896, 2444896 |
| mounted_chat | RN Text | Prepared | 1 | Native heap | 9652528, 9652624, 9652672, 9654192, 9654240 | 11553248, 11553296, 11553344, 11554864, 11554896 | 9653728, 9653776, 9653824, 9655344, 9655344 |
| mounted_chat | RN Text | Prepared | 1 | Managed heap | 2522544, 2522544, 2522544, 2522544, 2522544 | 3087792, 3079600, 3079600, 3079600, 3079600 | 2522544, 2522544, 2522544, 2522544, 2522544 |
| laid_out_chat | RN Text | Prepared | 2 | Native heap | 9244064, 9244544, 9244944, 9244992, 9245888 | 10927696, 10928128, 10928528, 10928576, 10929424 | 9245264, 9245696, 9246096, 9246144, 9246992 |
| laid_out_chat | RN Text | Prepared | 2 | Managed heap | 2444896, 2444896, 2444896, 2444896, 2444896 | 2842208, 2838112, 2788960, 2788960, 2801248 | 2444896, 2444896, 2444896, 2444896, 2444896 |
| mounted_chat | RN Text | Prepared | 2 | Native heap | 9661392, 9661488, 9661536, 9663056, 9663104 | 11562112, 11562192, 11562208, 11563760, 11563728 | 9662592, 9662640, 9662688, 9664208, 9664208 |
| mounted_chat | RN Text | Prepared | 2 | Managed heap | 2522544, 2522544, 2522544, 2522544, 2522544 | 3083696, 3083696, 3083696, 3083696, 3083696 | 2522544, 2522544, 2522544, 2522544, 2522544 |
| laid_out_chat | RN Text | Prepared | 3 | Native heap | 9244064, 9244544, 9244944, 9244992, 9245888 | 10927696, 10928128, 10928528, 10928576, 10929424 | 9245264, 9245696, 9246096, 9246144, 9246992 |
| laid_out_chat | RN Text | Prepared | 3 | Managed heap | 2444896, 2444896, 2444896, 2444896, 2444896 | 2809440, 2842208, 2842208, 2825824, 2809440 | 2444896, 2444896, 2444896, 2444896, 2444896 |
| mounted_chat | RN Text | Prepared | 3 | Native heap | 9661696, 9661792, 9661840, 9663360, 9663408 | 11562416, 11562464, 11562512, 11564032, 11564032 | 9662896, 9662944, 9662992, 9664544, 9664512 |
| mounted_chat | RN Text | Prepared | 3 | Managed heap | 2522544, 2522544, 2522544, 2522544, 2522544 | 3083696, 3083696, 3083696, 3083696, 3083696 | 2522544, 2526640, 2522544, 2526640, 2522544 |
| laid_out_chat | TextView | Prepared | 1 | Native heap | 9228240, 9228672, 9229024, 9229072, 9229920 | 10246688, 10247072, 10247472, 10247472, 10248368 | 9229392, 9229776, 9230176, 9230176, 9231072 |
| laid_out_chat | TextView | Prepared | 1 | Managed heap | 2428480, 2428480, 2428480, 2428480, 2428480 | 2686528, 2686528, 2686528, 2686528, 2686528 | 2428480, 2428480, 2428480, 2428480, 2428480 |
| mounted_chat | TextView | Prepared | 1 | Native heap | 9667664, 9667712, 9667760, 9669280, 9669328 | 11136608, 11136688, 11136736, 11138256, 11138224 | 9668816, 9668864, 9668912, 9670432, 9670432 |
| mounted_chat | TextView | Prepared | 1 | Managed heap | 2486000, 2486000, 2486000, 2486000, 2486000 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2486000, 2486000, 2486000, 2486000, 2486000 |
| laid_out_chat | TextView | Prepared | 2 | Native heap | 9237472, 9237904, 9238256, 9238304, 9239152 | 10255920, 10256304, 10256704, 10256704, 10257600 | 9238624, 9239008, 9239408, 9239408, 9240304 |
| laid_out_chat | TextView | Prepared | 2 | Managed heap | 2428480, 2428480, 2428480, 2428480, 2428480 | 2686528, 2686528, 2686528, 2686528, 2686528 | 2428480, 2428480, 2428480, 2428480, 2428480 |
| mounted_chat | TextView | Prepared | 2 | Native heap | 9677136, 9677184, 9677232, 9678752, 9678800 | 11146080, 11146128, 11146176, 11147696, 11147728 | 9678288, 9678336, 9678384, 9679904, 9679904 |
| mounted_chat | TextView | Prepared | 2 | Managed heap | 2486000, 2486000, 2486000, 2486000, 2486000 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2486000, 2486000, 2486000, 2486000, 2486000 |
| laid_out_chat | TextView | Prepared | 3 | Native heap | 9237472, 9237904, 9238256, 9238304, 9239152 | 10255920, 10256304, 10256704, 10256704, 10257600 | 9238624, 9239008, 9239408, 9239408, 9240304 |
| laid_out_chat | TextView | Prepared | 3 | Managed heap | 2428480, 2428480, 2428480, 2428480, 2428480 | 2686528, 2686528, 2686528, 2686528, 2686528 | 2428480, 2428480, 2428480, 2428480, 2428480 |
| mounted_chat | TextView | Prepared | 3 | Native heap | 9677200, 9677248, 9677296, 9678816, 9678864 | 11146144, 11146192, 11146240, 11147760, 11147760 | 9678352, 9678400, 9678448, 9680000, 9679968 |
| mounted_chat | TextView | Prepared | 3 | Managed heap | 2486000, 2486000, 2486000, 2486000, 2486000 | 3092208, 3092208, 3092208, 3092208, 3092208 | 2486000, 2486000, 2486000, 2486000, 2486000 |
| laid_out_chat | PreparedTextView | Prepared | 1 | Native heap | 9236720, 9237152, 9237504, 9237504, 9238400 | 10024848, 10025232, 10025584, 10025632, 10026480 | 9237872, 9238256, 9238608, 9238656, 9239504 |
| laid_out_chat | PreparedTextView | Prepared | 1 | Managed heap | 2424384, 2424384, 2424384, 2424384, 2424384 | 2539072, 2539072, 2539072, 2539072, 2539072 | 2424384, 2424384, 2424384, 2424384, 2424384 |
| mounted_chat | PreparedTextView | Prepared | 1 | Native heap | 9662128, 9662176, 9662224, 9663744, 9663792 | 10960176, 10960224, 10960240, 10961760, 10961840 | 9663280, 9663328, 9663376, 9664896, 9664944 |
| mounted_chat | PreparedTextView | Prepared | 1 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3010000, 3010000, 3010000, 3010000, 3010000 | 2477520, 2477520, 2477520, 2477520, 2477520 |
| laid_out_chat | PreparedTextView | Prepared | 2 | Native heap | 9236736, 9237168, 9237520, 9237520, 9238416 | 10024864, 10025248, 10025600, 10025648, 10026496 | 9237888, 9238272, 9238624, 9238672, 9239520 |
| laid_out_chat | PreparedTextView | Prepared | 2 | Managed heap | 2424384, 2424384, 2424384, 2424384, 2424384 | 2539072, 2539072, 2539072, 2539072, 2539072 | 2424384, 2424384, 2424384, 2424384, 2424384 |
| mounted_chat | PreparedTextView | Prepared | 2 | Native heap | 9662144, 9662192, 9662240, 9663760, 9664352 | 10960192, 10960240, 10960288, 10962352, 10962400 | 9663296, 9663344, 9663392, 9665456, 9665504 |
| mounted_chat | PreparedTextView | Prepared | 2 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3010000, 3010000, 3010000, 3010000, 3010000 | 2477520, 2477520, 2477520, 2477520, 2477520 |
| laid_out_chat | PreparedTextView | Prepared | 3 | Native heap | 9236720, 9237152, 9237504, 9237504, 9238400 | 10024848, 10025232, 10025584, 10025632, 10026480 | 9237872, 9238256, 9238608, 9238656, 9239504 |
| laid_out_chat | PreparedTextView | Prepared | 3 | Managed heap | 2424384, 2424384, 2424384, 2424384, 2424384 | 2539072, 2539072, 2539072, 2539072, 2539072 | 2424384, 2424384, 2424384, 2424384, 2424384 |
| mounted_chat | PreparedTextView | Prepared | 3 | Native heap | 9662032, 9662080, 9662128, 9663648, 9663696 | 10960048, 10960128, 10960176, 10961696, 10961712 | 9663184, 9663232, 9663280, 9664800, 9664848 |
| mounted_chat | PreparedTextView | Prepared | 3 | Managed heap | 2477520, 2477520, 2477520, 2477520, 2477520 | 3010000, 3010000, 3010000, 3010000, 3010000 | 2477520, 2477520, 2477520, 2477520, 2477520 |

</details>
