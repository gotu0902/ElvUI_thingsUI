local _, ns = ...
local TUI = ns.TUI
local E = ns.E

local PI = E and E.PluginInstaller
if not PI then return end

local function Store()
    _G.thingsUIGlobalDB = _G.thingsUIGlobalDB or {}
    return _G.thingsUIGlobalDB
end

local PRESETS = {
    { key = "NHT", label = "|cFFff0000NHT|r ", str = [==[!TUI1!S35w3TjUwC8VoN5HolqC)XCXP1RMGZX25025bMa2KewXbYa4jn9H8z)ijadiecCIj1UDV6dPHWfH0(3)9fechzN5oZwSojn6HpghT(XeYVh6)90XN6yll5m72ITAt31Bw57NgeE7XrXl9JNLghDVVZXLB)c3479JjB5UGL()LFC0j35gFRFs1Dk7GhhM4N6yJVgUHlUlk(Sy3h8DMnA1)E1z)9LRCFgFEyVEb)WN0qYpIlJcctDMnFYLNp6S5fB9BtU5g6z(diNzjlIE0Fc5yZUfMD7Qip3vo24)2IvUjjo2k496r)foPKF6UaFXOBlyruy21trZzMFOR3k)LK7IqAZ8KOWK1p4N8Y1UHlF56P4d0DvIZS)zT7QG0NppR5F8Opn2(0nBDttdLDnP92intYpcs9FG870MH)Qvz)FY)kAZv2jBKQmYcr2uLwgUplAD64WL(F3XwZjLUBksMI2nL8DdzkC3uj7MMMSWlP8MlPQODdLDxv7UeBjfeEVFAYLrjbPbrHydbshxWs6Owk2IKAPgTom9SOW0ClbuLnHpIV)ySFsYtUpNV5n93YKneTAz0tHNeTkIymm7wNZm1nTqwM66sk4FQl5CZh0Wd9EeRssl8UONoHCEi3cBUotwNUkieBcm5Q5Np2EuX(LD6Z21S)FU95jJSNpAA(ziFBhpz(8jxmD8h)08Y9N)zV6FT29ykLoFk9oNzBorRw)qi2M2i362NAHD60RW4SaBSzF5OPthpzAh2Hz81u)vUPb)RFT7Kmam3mpdwj9e5By2c3v4HlP)uFZM(6gkvMLY3mc5sh48Y4wYHB6mlM8tuzR5RvgIdcxSA9s)55MsoEu7X3MSLhJytTbobcxneEYvBYjFQetoxN2q5cXk)qSWY7v9Qlt1uBO6aNTHHQqwuN2fPRHqYDt2wYwIpBuXenldTEOmzAAk1LkHnssZsTBDjtltH7LrHfCLDyJ(RHCR9EYYMskMD1XqpZgO2plMQk6Q96SG00fYPYzkRCVm6Ykk697QO3QhhBfestYONNgR2VNrivdPEDAKLu2f3tT7f1wUZ7hBznKPE3oTOxQQQScCBH6WTvlQ6ICtG)dBeh3ilktffLZAzm(4OEYe4PR8aBXBzLgTA5wRVNT6xK(NQj0xZJAVDBMT5nNiPU9yYlKGkUlBXBvvxMJoA(N(SnTJVnZknzjXcD6zbnHuu60(t10qC4Ck57LQsNYHQw4b5ofGXNlXCEHfFxbhGfPrY6MDQLBzOQ39TicBF2pDJzF6OloYUDOxYez0TtnzlZCbOo7hU4OposGRcvuNci2QAQkDhNnsrtvtQBhTAkQD7OvwwYsZQ7yau0uKv6vh)LthpAw7yHQHMPwN97ADl3IhBqIv)vkAstN8XRAFSrH4nQZRMgYWOZ(Czl9(5p6Ij2FwGXIgsQFD2y478jN8zrM5QY6DBMlPAy0pZ8thHB7F6kQ4BRxvltCqx9aU0nKn71v9YJo)Oth3ooRl2u3ilArvjXxokrOiBQ1PeJTUyvBZmLwZoblSpxX4xMPUec1llDH5YzJqM9ifDzKUSPE)e)h9)M8zbgckgQiuNNjBfDfl5(boDz5zQJtxPBovYQJQqKLsJUQHIwpJ7JB6VZNCzE4zz1f6u)B8dtW)9xU(KttE56)twcHVC9vN9h8lNfQ9cJTlYl(dTLySIOeJztChtFBxQXj4ZqS)yCwSKtxLE3NIDF80aCgYNo5l21sH(eAziDMLL87xcwIdvZgNWjtn1W94VLiRBzZB6CJRexThtC1vUqM9PetIoxFRw4SBrm0TeMmB00mfV6vfdnNb2krrF1L9KjoEn(Q(Y1F4LRNgC7DPzJVFYN()XsdnRjuxM(5g7Bm(l6B5y63fALx5hVwl(BzZJTCZSf1vQsrfW65V2e5zZYuklDsfEyCLuwAVgQ1ZZXRvvOTRw5Il8uk)QAvRGzhF00zJMF1L)nHOjEthgbPSbRDMEK5wPhP9oMPpNDQZS6rODGI0Esw9I0JYmcA4Ioxz6)m3n8()4TRl1txYOEllD8oxwABLDufbT1LFAI79qJy7eDAr5QrLCARSC8IdsBhi74v9W8yvB8AZhwMTs5dC61llvXEOpYskDklvDy8Tfxtv6PnXHVYEqLg19pSnPYM0zMKmC0uS0v1W5FHmj17uJAVL6U4(KnnsTofOQlMxk151B9kopWqAJOwhdDlLxlRIn1OuUz2oNPQHiPXjPBzOJ0YkORv5nyZURSTxTFTCpB0cB(OfBtyTqu9iVOcb1xUMy4N8UfMN02iN6vFIe8Eg0hh1vTgQMQATQYvtS1J5oL5jeUvQQnKp5ef1weWxlH3P)RGo7Ev6ODStVUhPZVKPJwn8VYSrp3)M3VKrr7jQuCuHS4f72(Oiu2n3Buic)N)7hcUn2n1F5fRxLgGVyKKNdEWpU(0FZWz2QGK0nt(n8f(P5p)i(u(yW39x5mlRTwCNpE5kFHn80ySd3QqbtVUC1rxn8zDPFcEiWLgblXxbPbm13D5ZJXS)dEUPm5YMpBPwUoMEmhTonIAnToaFBsVIKZqt73QIhsIk1z(aazoboJm6UzW4nRaEwCWpE56)7A3L42U7lxpF(RSWC6hofMZBhRespZNoNyitUq3heUeBbJDJXlKjH(QrfM7Nf7)pR9dx8mvKtJddq3WDblUp0pF(nvy(HXBPnmcQcJWwNMIEkYP6C)WBjoAjZ9068IxdErk7q(YD(4e8CxqmvzyMSji1t2KNxtN0d5V3spuzSam9XuItAlm)B1o)NBDGYWMDwDG8EFQdeNoZuwpKKrvwlMMLTrITpJRcyrJM43H4HiFEZYvqKveoJgjhzN04vJVehvB4Mh8eXfzG7QJDZ8pvMVb1hi(UnRtNyT7LVp4FsF(o0C8(wJl0frlREDMfeENFCqkni3g7m7nF2(MhYePCYChMkU)Zp6ClApCZH0BfUS6yaDIHsgf(ZIYNvexL8gF720UMsGn3e7y8jCzC0Jf)(mAsTu0Kygue4KCExr9GFVPHhP7YdeePYBuQ2TELT7L3i2I7PBQ1qirM(n2YbW0Vx0HwdpP6snHF6fVS(J0txJYnCe9(Zz24tMyxP7P5qztzxX0rfJjYWsrdVuRqnB0zuP27nelFIGFQRZSlgD64RWzC(uwoxiL8aSoTWXsUxuQjr(i9FfH1NZ6KX3jPRtW0YCSO8648PM74xU(4vUH3N1zxnSCYVNFlKfFZ6e)tiXNM1VEC70jbZK3hXm2HG9EcQRXSThxymWyiLAjTPxge47lP0WYJlQ0Q6smJ6IxP6YoeN4P7WIqcK1BVrUvygcWmaZamBiXS8qNtkIQmd5WT4pIdzMA2YIF0nim1d2c2IZodBbsQ9cjRTXH5zT51sXB9Qu8248At0yWtQAsEIqWsKJS)Jdtcw6xwUQDrIb3vPoInPsUjuxfQQpdQkS)Rd(8StAMdohnK799F8isUdPtjNaoLzKrKR4MQjTvVoF8fHBuOab8CXfwOP0pkzf2C6koEXN96Dhv3A9EyrunzGLfQzRckBzmAk2XKACRfdPpzisrvzavbufq1dbuvbqvavbuDphvZs6CtDvPZyxTdHYT2iLMToFHFdtIThLwD)it2xroQ8RCrJuI3LPYYuta2SyzRAYwvhiDaZamdWSHgZqaMbygGzdnMbp8q4PAapvJb)HhAcEZaVzG3SH2BMgGzaMby2qJzgaMbygGzdEUzYaNbCgWzdnNzbygGzaMn4UZGs6dCgWzdpNjbCgWzaNn0CMkGzaMby2qIzSVqqgWuxgM6YWuxgEHGaufqvav3rOQAduLPnY2M4Ej3s4K3QIy0)6hhJXk6hcusSEfKLy6K9MLhFYXKExZIn5O2TI7MkBSqtwtcI1iGD56BBI)KznZRMQmVLPm(c5v7EQyU)JMZeRV2c7XVpPDUR59gx2RnCx49yJ1vW20zBx(QhlYDTizYrRvi)cVM8GRwWv7bHRwDavbufq1dZxtEiQyiQyiQ4dGOIB(UZN)XXgwPsHvQuyLk9N2kvQoGzaMby2qJziaZamdWSbFD3wg4mGZaoBO5mtaZamdWSHgZ0amdWmaZgAmZaWmaZam73YpksVvmBuyS7T(1(Kbwd2o(3OLaTbcQO920V9QMQk6iEuwVaPxH2Z28gACMgYWqxtttXuYqrxwX5Mpq(YqVJxy0ekOCi(o2dU9a3E)s72tc4mGZaoBW5m4zSbCgWzdoNPcygGzaMnKy2b2hDtotPBXZdAoZB09TxvHMZZ3gZr6MtJAEOeh5bUZEC(cO8MU0Tp7EBFYsZoZZRlP1Rxmb2PN8wmHP3tFzfAPCtmZy9gICC9EDi)I3d8lWVa)E4(55e4xGFb(TVV3r6QcFVJ2hxGVp4(4l9A(ad9713JP6LVOZNu7VCF9LuamdWmaZgAmdbygGzaMnKyg3I12R3D)oYIS9x3)xDwK8wllg6SiFhwqlgMfxg(lnjSlgW721ZIV2PkDJmPQuwIkPewj3S(NjyFwyl61sxrFshSwU88YGTrIGnwBJ6Xkxr31LfqvavbuDFhvvaufqvav3Zr1MvBvwsHPCRY7JlZtqcQqcQ)kxhiyzEcM0EWK273LL5P(6nBAWJT)MlUBzizZ9ohA)8(Gtv(gnkzyXdPAyf(6(iI1HTF)XUD472yZpbwdZB34b2ZXFQ79(al(tLf10mqiGgheAewWOG4pH4pHfmkaZamdwWOamdWmaZGvZxGZaoBpGZGfckaZamdwiOaod4myHGc4mGZaodwiOamdWS9Tfckd4Bvn8TQEk)jXl8LQ(v)LQUn9N3Y3QAlavbufq1dbu9n8UfjCvdAx((e9k)IZV)82e1cL9gzxUd(nJgDW(i0ZAVkqeOQz)(83D()p7D)0BAddghh)LZonjI)tIZoYHCCTsfTDRdOIs5q7MYup0l8AVmGc1jHGPeNAZ(EHRee5J)94i)8eRqRJ2Iro8w4Vw2r17vo3EdutulrTe1gdrTjjyvSkwnkSQfvhw)Q0HIFh27nt)OfZNv(L)UCCXZLVy1rfUul8UgBDDD23(DDxxB8U2nqlsY61sLDQX79uLYdpWTW1w3)9xGbDrYoTDXoO65g33x3pEnsjwMyzILJHyzfufQcvJbQk4blZdwMhSC0(GL3EIDjRLSwYAd8SwdufQcvJIhSSaRIvXQbUvTgMRRpM3cTU13Dws6ia6ia6iaF34nmmxHzWS)xgMRWmygt5hCgodNDooJrWkmdMXiyfMbZyeScZGzWSy5TObmdMXeyfMbZGzmbwXz4mMaR4mCgtGvygmdM1FtGvo6YC0L5OlhHZVgOkufQgYtGvOkufQglneKCtdbzOHGydQSbvAiOAmR6FbbVGo2)zNoxQCdwfPS1g7SI1SaQ3KsT78AKkhC1LYkRUmD)QlDiNAADNQeQLL1p8fjne0pM84FwuU4ULJh97NV7bRjMQfnh2P0mXeCHBTR13Y1kmIuTsoqzw9PsMAU9(VQv73ZWzQ3DZhwPkF)0YQJ1CtCQfUwOfzzPATwAgKjttKR(jRuTa4P2awip9aXQPh2qD65EQ1(3xEXVgnPC(mhX6Mnm9jJ1BEyYQTgTC8pxTtGVTC81tw8uyc2(ol9TTpxKMPs1PMCJrKRt2Ot5(921v6uBYRzZehl78dSywnw7zT6sEBJRdn6QRpMvTOxa3Asu)k1VEzv)QgMbZGz(MzzWmygmZ3mlmNBe4mC2LLZYHzWmyM3JZe4mCgoZ7oBaodNHZ8TZuWmygmZNmRAVj5W7vHM9Nf0EL9o)6Tn1bdJ)vY2yBGlpCKAvLMoRADBQxTtiR0UOMLmrA6rNDr(SpinjfSn(peiyqV3mnTUTKa(37ZloVpp(0S(Dzp3E90txSEAMPRvprCY1fMvA1hvynpM06((RnEOA105oM2)rvMy6kJVS9dlTnN)ywFcJzAIPRnR4QMWFPAD9XrlwmGQaQcO6yavduEkEQY5isDpmKMwYzs2SVLUuNMNkDZtBGxlnAL4QMgmR09UX1QkfPUOUUYavKi8hJjjQv1xotsH4IwuLbQQGQkOQoguvXyGvbwfy1rbRwdvtoF75N0AI9kEaHeIqr4GGaolKFya)N)TRyCgU4pGGiXrmAiP8Ne6kzF76)llF3SBw942nL3xeDxHMgKtSNX)8hV9Tn28eKRCxHpz3amcXhSoMpDPpmgtiOIl(8auXVzV3ky7V0tzemHJr84IR)SI3QhV0BijaiAwu3C)WVF9UAbaJ1)uD63pcccaQ5kfYoB62LP)Fw()(3PBEjjnxPvMEBbOShweRxRnDau(QDOQriiWdc8Ga)yqGNcOkGQaQogqvppakDOh7dMy(UFSiB5dU0ODNdWV3NDOpTT02hJwU3888g2K2Pw3ZC36E2G0My9t5kSULqLiq3f0DbD3XGUBeGQaQcO6yav5aQcOkGQEoQwlnz3hrOyevinzJ8)0KfSuayPGPLZD8K0KTEu9o2OmpkXkh2KyUvrEO6sTogBLEEOnd(9guZa1S(3V3wMfSItmXWGCj1qUBYxV6XT5DyeVgPnIx5DIcNMvxNfmoVJGXK)6t2fYR4yckc3LkEnFPrjaBS4MMuGLhgJyrbuwzw4IyyvPa78Mtbwl5xdsGZTCCH8NmGf66e66Ck31jdWmaZamRVXSqaZamdWS(gZ8LmGf4mGZMYCwmGzaMbywVlNHaod4mGZ6DoJaCgWzaN13CgfWmaZamRpXmXmGnC8BpW7kUdxqcREA3SpTon3rNb(2s3RlwN8RV9pb9NtbjSGW4yDJlT8i9kn3TYJeDtdoTf2fSYN8pU)Qr5hFZEiuYgGTlz7ePdR8iO4Gl)B5V957h2uU7EnPCNZH5NLPENtEimwz6uQA80fVdDznbX6xZYZli19RplllE0cQJflqOW(cDGPieR1wVaxdlbpXUM9JQc6v7IKgkulPIuHtCaATXHd6HCR9)Wr9pJEFqdVkwA8YLUSk5xX7bIV98b)lD328xx8A6YYi0AZllw99x2uta3sEUMkoT3uX54GY)g(QLNAfE3wlpj1049QfMhwRnPQcJiIlk0jH8Qv(6d6MnDZo6cGz1VxK9qrx6zpLTk7WB9ZOB9(JZjKikzCfThDvB5sp(xfmxfm5xHmT33(TfXy7GsYIf0o3iG3Y13Je)hlxTX(m3Xq0WuNpBwXX2ErNwzUtxfq8UXQDtR2rDwy222MSVoDz5RW33n76TP5pSiDLZ9yNiO9YodTxKETxCqikYTnkRrC3UnmtENWOnTurCpMRhoTo1aUQNxxzxDQrWJ0tDn4QPUSN2UTl12m(ei1vFK4gLjnC87)hDviItPf)cJheXqeA5pN2bjgI33oEsw(MS8N9ZDlNHccO(9ELJH9kFY3SoD6(04jP5pV55f(7ZFJHN)gE(7UhPnhhU(4UK)HTRsZ3nljl9NN9UJ3FQ2eefX5dCN7d5EMBsMwvtSQ)IXAmcD9TTo3QKrBG2mDlIlxyV2G9Ad2RnpyV2IMUTA)L8nf3q3n7RlEADUF2VDqyi8fEbnC3kW(pS3zZUPnquu4NOk5XJTXSL2TvTsevLLK0qfO2eKQbf1n8SxGksXJNFyWEC8aFlZsS139m(M5CoUeHtregryeHh4IW1sx3dpQsZLkPRRSw66Iv6dPzncvOOfDjuyDJy0IeolsZJqjygygywOXmC4lygywqXmvRhME5xVk3RDULFXi1YINR0XRBkLWtwtZQCU35uAD7h64kiUYAEfnFzTJ7f1LuO)GQGQGQdDuvcQcQcQoWr1ARBvU)phju22AgDzgT)cT)YnzxMbMbMDnJz0LzGzGzHVlZeWzWzWzHMZkbZaZaZcnMLdMbMbMfAmBeygygy27FrtpSWS9)OQQ2uTD20NFOArhwY0wPU9vq9nh1DILQltkl8gd7kQRbo32gKogaZXO)H(h6Fbx)J)jaWzWzHNZsGZGZGZcnNLbMbMbM1NoisKszgDdxMr2tInhzbdTAKMuzZwoigIeAJYid(f(nE5xj87Tl)QXrr2jAiyR9kOYmV(GFZHFr)f93Ov)viaGbGbGJxa2z4O2VCQxv37R7OZd1U)Uxel)582xCV5HRAcksmxQyHHTT3cbwyx3hZULWT2e0((yHQpl1oN4UkCBuGQRj(cuSrXgf7OvX2JobRL5C(KEVPcMU5PNM)Y2zFA(dRx4ttf0FTdAEAMC0zt8TT6cA881qFr(2Rrd9nP(cnq)aDLkfvPjzTmMyYf0GGQ0HHcd0uRIEojH(fmw4KQn155Ku6IOoiI012gSUlvm00zn4Sg8OCn4JGF5m5CM8O9m5LWVWVWVX7wWtaGbGbGJraUzXHjssvIY2r(gLTRx(RLR)ZX38FB58x39g)SCnXDF5RQwMyIFwMWYvy)rLRW(VF7kSFc5F3QnFFX2zRxmF7SpUQ65vvMTk)GSSwm)R0FZxyUZUBUh0)7sG0U0c9z5jYIMBd6dPgMU(VHGNRNmuCxIv)XNiZeIXzJlZLjLYu)9hVlZXO6gJAU)zItJwOL6gu5I7vA9i1LeND7ofiyZt7oDrJy1pTw3aMU00t(ICnMA8UMlUhNL1kpe2wbXpVA1l)y5(hD9JmOOazWMYGIISsrAduTW0hzC4GuDVgy9mIjXLg4J9TgyyZOPbbpoDd44WahZBGJcOXbFm7YHqRby)T9U2AQT11c)Z5Cop0ZyB5RN3iKWUDgkLPKoL(cGtWuYudHX2ztZ5H(BFljlBR7wMCHaJEPxITKLLwFFRLws6Z2GqFNfeAGfMzHzwy2UgMfzHzwyMfMTRHzhkFduS4mlo79molXcZSWmlmBN7oZXIZS4mloBNJZ8S4mloZIZ214mFlmZcZSWSDjmJx1CJy0CKr63t1tklH1YI0C(nJ5gEuL3uXhzuoSRel(iF6X7wvIA50RNTSn5Q2tSmW8TFnXaXqLhX3lXpYFVCILvEeJzB48l5CuSWHowyFxB0jAuYP1t)Ul3CnhXOD59(CpzZ7Xs6Hr2Ow9Lk1mgXdISNQTRTtxTFsSl0Iloikoj0jkb2HE3hcacBHBva7HRmV6L5a1QZs35fypZDCGE2m2gNed5ekx2x0sB1tKXL9giNalb1jCGc8trjOhYoucaJp2f0Ef79Oxidqlx8MyvsJTIi8YOHyCTC(U7xz43K55lEQm7p38VpD1JPf)NdyzdZpoWD)QAygbx5bHBpfjqoEvGI3ihdh2hQk5hknDctGr6Q2GH2Io5Dnr0EFbAg4gc73uXfACrw6dWP3SQOSAiAl0mZdeAgvGqnsQ0wHgaaqNxhnUTzTp3KG45z2KqikZB9LAoXFYDcX51wjVLwbRAG6iKr6M1EuGHc73n)aIfYi1fs0TXwtHFTbIBde3gi(RxG4U9LyTxvbaK3Sxu9)QslEol9VZk(xL)5MVNw80lxca7CtVBYQgibK43RhzwtqPAallg1CDauEsw6gn5JTdNHrEkaUSUPtTcmj5BgL3w9KB)yh5hxpvHjE571pUjb0ZZ1j69MnTOYsFQYSSAwI1gY3SoRdDRdDRd9xph6(VzZS2flZp8ZSwKnZA2mRTpZSgWeD89GnaEJuWB2y4ZUBZt1gyVMQnCG9(dlWELSdMfGVegogsWeJdC)YbtmOqGBfHhVJdmxbZO(WZvrG3x05BI0dAdh3goUnC8xVWXJn)tVXM53E7S4yV5fl0DJ7wddMq26MizQwniz1l5wFbMRkRBSAykfW1a3VQcbFp5T9h7aVTky84616)tFLUWR1oD6T7EmT3SH)LNZ)1Ih)ZnquXJ))1dBZLotEeKgZ)TzHq7ge55TF31k9TZtznp(H6iPFXB8u1(FfzfSB70(O7KolqLEC6ruGbxr(PcK57X3NkEagMF7dFQzlQND7Ik044PlN)luBjRjF6Ol24tf3eiBQ(6ZPXz(W6Pc5LfEBZrp5UMAc6xQnQehSW3BxF6)nO7Mf6ipjomoXljom0ba)76pVtaQuoqkiZg6av)DNVexrJ8Msjm9XsTJK4kwjWTuIJB2XyuX7FcpLSDn1)M(NQQGPrwdJOgCKmoOO44QMTpS9PjDiMyIgYWBtFdIpKMRYcmqKiflFU6(XlkG0B4Zzq9LMm(6pwBaISuPz)4KjnNee5C3bbcFymopR4RqNG4VXvOFGCqLWwX5T1hSvJGsRU7oe8qgaGJr1JT2a(mqe0)LULOaU46AoE5dUAGlSwRCqJ6ssJnCmdAOZ(PtU8QpKmCWi2anL(XAlsmFJdgPeO1AwUDkherNLQwKgluXrePeRYuxnVbnMhReHDGQkoZ1xeArTKhYGJAxq2jDZwIbm1PVPC6TPy0smEUgD0xVyY0VD(1ONjSy3dbyhb9t(fiylh2dmQ7N6I4yvTCzRYRule0tQc1tbkd4FTgPezgF44iZ6hBJ9J5QfCYLrA5qw9efmWuAI)TgiTvqBLIt746bsC7XYB0dev9UQa2kQkw84VYQkpE8NXrqsTGhlqtiO2xWpRNmMh5FD(YYf1V8toBm0yjhosKVOeb7GtHY3fskJ73EOE)085rtgpEYy0HWDE(QBZopTSKm5Z2iuVG6PLwbhAVhwWlG1)0pD0PWqVx)y6dlMp9EOTY9W3cCuleAe6IED1QftRFL(8IFIMUl(Dbgrn6TRJAyaEDLzMkZmtfKwHzhRBztIUIIqPn0kUtMOuUBf2D8QzDqc5GxJFJWjePXS3tWg7dUaxTZHPDcl8h58cyDMM3yVDBgXQXdefhhqpLLZ8c9sIy(fGRNpkclQFYhecql6fD5CGZIN9xccc9zQQkzMuU183Otgm0GbpHyoibeXHNOvy9YDMVeE)xm54VC24J(6pqfo0xXfCDakUcSXPSm4ARgfD2hvCt(rkR5Wyv1SFyKYhQI3nKnx6tyiYZCJP)UVd6nPV(ysxlQVCDhvEf1iZNrbeGAaRXF(rG1nUwFI12LHDoDv1YlYQoA1TlwcT4E8XS8AVB5WPINv0qwHSKzhoj8hO5hCE6T32WWNoN4hQG8z9OvlO)l07VNtBjPTDGTry8oze0Wu(2iS6rnI08Zxc5EhvZhrL6ACxRptxjD3cFBKQP3ele01rvAXpZQMI)tjTJMXVQM7uEBLu3Oi4UlF5ZTJtonf740YkU3GUkN9nGMj4OYrTAmaHugoSb9RWwppH6GgNHCbKDBtOGOo9s0nxIzlWwOeWyLO9yDGMtRhvqvhMcRbyJZiZ87rVk4)hkeb4Be6FJ8zTOPh1P7DATGiJl5lEZvx8x5lNL2(LKA6sseR)MrVjQ)yov3SMoOCbtvVn3OoKifVbv37AgdSMx8TBdXD4ne0Oj0o))18LdqARzTqioBwFHYuU3zD86pc1y1Q3jFtSE5)93o56ZXmr0TMMBEtBnudtEgnm9SufNHUd6Lpmvjkk(gg47z1n(kAsgmSSJJWn(QkbK8GjwymRX7jq6oWZc3cupn8GNHcXyekyNy0FH8JJPZRPM8(Znxms)4Va1e1qGUYPqBHwBOodHl3jflFGOSnZymdeTxudA74Yu1YDpmB5ugfGRmX2xEZYqWTydBdPI3LyCwQydSip5drOjaeK47aIs8It8r5Nj8aYmLIq)ngc79c7pOF2FhZz)7i8b0vHm2)ThzFKlIKpYRMQ3NMQ399pvppf1RlH5qPOoOCA(2Ln6nR)(xoZfYqUEJ7qYrj2YJmxCuciNUGKA)7UNzXbP7fkYQlg1EQ5KqGdiaa9Cg6c8IAptMZU6KGayKKXHXUUaGxOtc6k(41bjWhKe6756gealwui5kfWR45ff5edlNJxyCSB9vuldLvlO25fQ3asA2wQgxAbIbQrqPsGiQRjWbKaICs89dC9iDnYEeO8llMUyzjqmQjfgn7zQJXdj0BfjhhEHkCg(hQtYWPPRxUISi3nzZtqwdLE3K0fY8CK0qm7rh5T9QmshijJ6EIKqiZeIptxUenE6x(oXlQxDTiDfK4unYJQkwohLFp97DmmUcTYb1Wk611J(d1hV0N(BC2cDWLH0Q9CCA2ucJiEG7tllLVZ51RVOkqzcRC13oxvugMO8O0Bldo2mb3XTVaGer1DvWSvRwH6l(bhKizQTsO6mDhQgH1g3vYAi3QLSbQfg14wHqTvyuN1kmQ9TKC0PPbz5F1)8]==] },
    { key = "FHT", label = "|cFF00ff17FHT|r", str = [==[!TUI1!S3z2YTnUsy4NOKI7K6YiVKOQSLDzjxtM5cftjrBXY0KEiPghpx4N9tdaskWfblMJCg5K)lMfrdILg9x3GyPXm9ztNnzX6S8Kh(CAY6hZy)oo475JoE2yJztUR8HJ5P82OGG8W47gMKUmiDsEAY9bZgoBYFV2pkm)5jl8JcMnw7J22ZMSkCzWFfKMC0k)07cYyjZpEXQK0ltcJZNnz4ftNEX5NDYPu(MTi5XGly5POOMCxuYC)iEvyrKFw2SXMuQEmyXm6ndI9NhfSKLJpL6)4XHPZMC9LvVeLFH5bpWR1gw6MAAShj9sr(pNSoFu8YGVt5RoLLI05PkDgEfPZWtD6gWsNTTUHYu5uvQwktNBzPoqz6m1O0LZfrrrI(lnxn3bQEhBdEERz4QRmDw80z7nWtDvWINDoAMoktNnxa54nyGsjKjVL7mGAgkRCMfjZsxzY4votQuvND28SJ6I9uR0i6(8CDv3nBj6(SDgyPuPXYwKoBhB1YoHs4a9bwktNfxg76QovM8uzs6wgQlvbIOzBPwprRizVIQkxeBpW1wD)pxRZ021qxDLZQOu9uw5mT5acHi5PHX3hKNDzswyEys8SjNm(4ktyN5)mzeAYWt(Yi2tZjtHCtKjRJZpnjoFs4)sw40z2LssIwM8um7PuE89htdYYEY)5IexZk3vJ(8xkZLJsIsyM5MmxyPJ)Vtz)78nzQCI0yj6uphDphBZbow2oo2K1OB)aPSk9Iuw)NxC7Tzb58CuU61UsxLstP22fRZJcJdMn5IRNE2OXNu8N(QuUMTk5PJypKjGf)qKHSFxM5fn9Joz80tUAZJ)6wQDBPyBjxZ5UJEkF1SjfYtH)KRcI8Zd)NGIID6fxkCQu6ukp1p3F2KrJ)YjxnI5Cyrs8xccVBvoxlRmDvvVpO30rxvVHpVYx1XP9rpEpG2hzkRfvh5Mz9Szum)5ABE(5(P3tQBdB5zL3HziQRIFivtL7Mz(e5oT11SL98j7lOqXFrs06hIjxPouYwYFBrn(0u)hiX)jr)Z1N(TlJeea3TBapRp(QRPHdOoZZO6wAWiQ6oBo7V6VGAmKnHQkTOHTzuavncQDfZl)JsIZw)qq2l34hV8LBUIYcYBoxe8hHlPUDsg8rAGfHXlIwVmyAbhtLhVg8ThcVJ6PdwE(6O8qQGySE4dbP1gtd1HffMLxnIgAmdpn95hPI)XWVhqfNOAY6KyQ3JwsdOzEJrUuQy3OH8bBYPHupMlXwldYOEvFHDMSCQH5hLW01zL7vb(lFEeX6pm3NdusgVyDqKKz56u(l)P15jShpFDi14I3igBR8lB0QLXKtDnTC1SgyrgsixRKjyYmITKvinzRqDzARPvfYsutdb07CFy8ssstdSSfw8bdYBN4voEkR)H)gJB6mOOFWSTmyRYuMmZSDZVDRyBgUKAvdEDBuneUPfwQfwio1Xq3X1001zGnjQf2RD5KsLj05CJg55(lwjAZYAC1fqC0JpMCXaqzg1wCFvByElLrDRw6II(ewg1Upr3zqx6KZRWBYmdrJd9f00gRoC1k)ut(tPwY9v1aTYs58KLKG76rxsgiy9eHXRcsdZ5mDRe3aXksBH5AQzEBNDgLQifVDH7b5csyvISznMBRzJQwHOEiv1xMM8y5VNWAl8pAHlelTNPx0kL8QAjQu11Wwv4FHgyvtzTwJwL0ZPSoFDgjKNsQWRtlSjp6LBgg5hFVOC2uQmRM)z93EX9nLFuL)KnqL4l9QPY(rJcxzofo2YlYPV2mR)eVDqosp6IXsIH29gnuf12ITQY648crVSxwE1Hx9k90k87Y(V5B6V3OaxipkYAXaaEs41WWSWy(XfVvjQXvfk6H)RKKhkkMYmxUbWY7Vk5XIvNzFBC8YEuRxNfCeZRQ4vg2W9BfGKlQrcBemdAeFza(c8f4R9fFreLoikquGO2Jev2H8ybv08N3O5Nw18p4XVTQiU92u)jYU0UAGLsZiIJ8mI8ZflBA9StMRH9LFqI71S71K(Ar6V)9vbIce17wIYaefikqu7jIQygl4daK9)WPRYwMY17QfcYFGYxzU8EpyoF6GP2jBM))JvbXJI9xWe7S)Y8TS4nIPPvBZ8D3ahl7RyZh6y(sgOcY2avS0pkolCzqXIDmVtWsP(rjJz60fJXkHttd(71bXlEMRbB3XsyuvM1X3Uye(7UkCX9XbSnzbPfCFqWJFIn)U5xXsnFrhKwtkXEZ4PTjuL7ABmj7CdsvYLUn1kJ21w50wysrD)SG47ySHo97)T9he1nYYErzHGCQ30nj)02lFGmdwWNSUm2F6Zu2Vr9BZI(1YqtNEq6LPgwlPDoULjuuhujOsqLhyuPjOsqLGkpCOsXhiwT6B0pneBOrm1M)F(zJM4ZgXNno8OJp)Bh5NLtLaMEtqvGQEJOkmfNGQavTpPQ8QDzngkiWlGxWPfOQ3luLj(clLy1rxpz6fNVBqf)qM8wruBFZOTte1WEsuM6Qikt79crT920gIYWDVru)C2KKFqFleLyYiBqud7frz5A82ru29MO(CA4sJZ4hNu(tyABfKLn2gXyBeJTr8ECBexmZ761ofmgyhgJDV17ZV96wMwE5Hq)8toE01N)ozts6aFBW3g8TTh9THP3aoUGJR3(ZldoCNWZf8CTp9C5bIcefiQ9irHzoeefiQ9jr5cIcefiQF1dsoy(kW8v8R18vmaoUGJl44AF64cbmrGuaP2RiLgqkGuaP2JiLfikquGO2tevZOqv9RMN51c6b1vw7ohvf3fQRjROxvkEhO4oKyl9XBpCD0mGr0ouy0wrQMQPeuxi3gaPvpKw9iST0KHquB5GlQTSJHPLgb3LTgbwARtvpGU0mAS0DK95uLoTLfAsOQQ41Y2ZSDnAUOAk2ETq6Ic7dFTHKsMv70oqVIWs2WWwpmSPRdXvFexD6hO8Ua6u2TMONPHJPNPRl7cuuCRTXUiMSO)Gj9p6MwMo6UIlIPUcZxnTwWk2ZsOrww3gwp9sKk5Ly(pGxIpnNgghjIcQDRn10268DZNH9o6ZWYSJRUip3Ikg)(rsZ1XsPFKA(c6A0)9W5stp1DbivP3Dq3Eq6gbuhsWQpiI0Q1SHRArkvA2EEA2gAw2EgCLoRwdfzEhgFl5o3nyVMD3(C2UtIx3Ps7wBNowA6ltL3LwdrOBZq7K3KognqQ0W0kPfLoDCHv0Eyf1csREiTm(z9Th)4Ev686k1MBDYAGLn)kN1Y1qxN8gwADQpEFMKSo6LBsU9LBYxf8YnNMqwFQFZqlP30LtOH7(hUumOEf(GmLCaPRBPR5Da9HmP0Oq08CSO(dthtxlnDhHiVH5S51V5r)X(4MH1hUI3Rm9MtVE03MiUAbzxDOFtmIQ36VXXW5h9BCy99vEHg23WwzXDD(U7Zx5N50TSRCyPAWIApSO6bPvpKwoqATBslSkpyvEWQ8S3xLhDnteiiW(tfbHpCXybIcefU8gbrbI63iIYgefikqu7rIYcefikqu7VRdvDnCLrb0cO1E3zLumH1etyb4lWxyclarbI6GMOqClhKfil4RcefikSaWGOar9B0ubw7mP3JTUFNNjuCUHpOo3Wnoox74Xiw9r7sXUJTRTJFx7v(MNyW)T9g4RBKv1oRFxoFWnzWD8ObREBZ36C5TlMA61jewhujOsqLhyuPjOsqLGkpCOYA3pJMSFAy7IP2exC34Zg)p7E7gufOkqv9JQWuCcQcu1ELQATTSoOxYBC4NXHFg3jpGOarbI6qD8GGOar9lryy)NwuyVDp3BvqcA7ApYt8E3rY4DjEYcPvFIc7qATRrIk5PUx3YfrrhmFiy(qWC3dQcufM7EqvGQ(DKQ4Jf0XdJfe8f4lmwqqvGQWybbvbQ63ZXcAy7GTUXEKCWYI9B8YI9QBtkS0ZGXaJTxzmSfPavbQ6nGQquScriK3DF2LQBZVd7aXJdWmGzaZq8UcygWS39yMowcmWzGZEZ5mpGzaZaMHRGmGzaZE3JzUaZElXS)x7DM1BBJdea(xuaKOUF0hXTfOXXO272TV4aLyLyHQehyt32S)6xElkksjLMMUXOZlbgsuu8y(4CWjIaMbygKEIaMby2VfmldWmaZam7vxBMhWzaNbC2RoNbBDgWzaNbho7aMby2PnMz(nRkz4h9eMDh4KN4n3jpXapQjmoGkCEks09rsH55jH9ZMKzDUuR(qM2N0QUoXjCxzd98OOlYTVdLIo(oA1(GL4l9Py6zDkXKbOkGQaQEkGQbaQcOQluTTahaRdfwT)1G8LGQraQcOkOv9uqRQVpWQaRcS6jbRcOkGQaQEkGQXaQcOkGQNcOAiGQaQcO6PaQIaufqvieWNcHaMNgTaRcSkOw9TUA1uavbufq1tIqadMadSkWQV1zvlhyMEi4dGkKq(W5oXV6)fxon(O4d8fWxNM8f8b(aikGO(ftuWhdFGSaYc0vbefquWN4EGOaI6pfIY8BfWZiE(wdxleq)3ub03is9dm((9L6kDeeBBBdGTG1Bg8))T9zeMDOTRq7pKG3BsHdmU9oIqVHiqhl2yUxiVw)NwaujqLav(BHkdaQeOsGkF7qLT2MB2L2tf1MSnVT)n3S5(pin(TytjMol9XD38v67KmgqQ0Y8k6n39TI97jc8SbnH56FwmyKSEjMyLoTy3qFZ1dUP0RW7fThBzLTHppIIQFcYYwvywAyiYleHqrEEEHHPRV9SOaH0iU(bvv2zir1RgZ8BpMkFQwUpDOvdqi6Ze3lQ9THxA7sn1RwWAiDwL86PU17RnqAuZQ3Olzg6m)yTNVD50NremqSSMBmEPExIsf08zDxZ2KZpiU4QlxWDqJ1cnUi5N3TF33XBNwUNSWef6wo9YppNlVrfm1xXIaEvQlXMp0ckaZNUff7)eHqNJ84xqeAJ5HEnD40lLrohV9wknytENdCA(16ObzWf6TihmIV)WHKZ87Gs0LOAre()marhcITOaTMZSyKFCsqqsCwuwCgIHRXAnrpz2W9cGeVNRmEAlcPlr5obT(rfF3loytU3jI0GN0vtInL9DWnnu8OQyRwMqUR8OnVjAyrdFd6IU8HoDfGAzstGPklCzvj(jP03Fxw89c25s9wcZnIOW9sc)vrgUgxFjHffKRCK)0U0lzblTIVsonWCS8LRnRtqDwkkokmWlmL83WG4EvN9tPndniTzwLg7qU7LIT(gY6nR7NT2nlZbdIzpZg0ISUUryJf7g6QgnAy4Mkc(Fevnvege2lQEU0mWwWkPHG3x(WxlWhMm9cMjKAAfkP27l6dyY4Yws)8lZhDXhMWgbo(4IDhk59)ZNpLCT8h5HCVImgwvEGsGK3W9m)go)IXNpD65KID7w8hlVVeZDeqzJ6s2RJlnrdu9nvh3uSi)WbHlIBE6H87lVz1wYCYws)GrZI1r4plzmD9YRWhlxX7txuEh1xtwNHytnT7vVUWZqfSnXuBczUaAdJPSz16WSkttOqzNLA7BS6GsNoWAxsJ3Fy(hjL4r2CWTdhyuERyUPv7jvyELuwBtbtezokkkomrndt54GK00iTRe4JcPQKvxaLeMeKQFHyuMEDqwvoimuVaErjOgpqecPvLyBIyzm5a6UqqeGyoaBWiefomxVqr8th(QDKhy55tUC(0rF6l8SuoYXDqrjoUtSRhXpmo15TscC9Is8SFhSaA9f(fRnv9dTFBnzXfdwtedoue9PADeynY(cQkEAd4jYY2XK(2YFqDWlMSo1JQvdzLNvYPfxF8oA1vpotJrXr8ULf4rh3uUJiA9WdfvC9xvhpGl2lxkIkVUQrGFelrqDlyr(MnkB5Z3FxbEs(b8y(sdAZQYXKF0G3yJcVJEl6AWIQvtwH2Dig8uiyIvMDaY7M2cZRwSJS6RXB9AXBn08TkEpuRPUTA33v2gej7cRy)1Y7u2nWYsAVDPMMmhHYVrOnEVWwpE5vW9OdJv7ySyjwYe0Xhn6wps7TtlO6pk2i1ArA9hOLLYoZz7maxdJSemMI9K0YQcr1QD1REXTLCf3XOT0oivkKzPfzsL97avDewtXmvsLsth9QNTFQ3O9iGDmFZkxV8Dv7UoVQB2rMzAYgLRvQFQoYhXH26VnEjnfofQyN9(MJ8od8B9WvVTgVEBkEVSMICw51QLmFOTeUKYRvZy0QvJM8EQ5pdOTyK1h9S33IOOlSzHn1kwCHAqYQsHH(eZU(hhnrIzSShRzosKkstHirAlejYzIO1oYkfc6Hl12sGCzqMvrXx6FK1HyR7bGTNwBI1CyspG)10k1QV2gXzoPrB7IvfeX6P2RIgAa)4LFMF)2wQrgKfvbYRVCXGn7qThvtJJCpfOX6Gux1EJg4o)Cs6Amw6cq13(RzxTGPE6kMk7X8vcPrmBSyjQ(Yyd77aKzgM0m5rCK9sd0bQHLEmg2XsdDSPCrRCjrtnPkVIIA6KNRX7uvUcPYDORv5oKzMnzKfq0qRfMLrmNnkcL5rSbnwfATzXjP(Pz(PjbEjzOm5DU21ZG75W9iYR9MAL4qOu53LU3Orwc7sJ02jSrYsf1RBcUedXRx)F]==] },
}

local function PresetStr(key)
    for _, p in ipairs(PRESETS) do if p.key == key then return p.str end end
end
function ns.ImportPreset(key)
    local s = PresetStr(key)
    if not s or s == "" then print("|cFF8080FFthingsUI|r: preset '" .. tostring(key) .. "' not set.") return end
    local ok, err = ns.Share and ns.Share.Import(s)
    if ok then print("|cFF8080FFthingsUI|r - Imported " .. key .. " defaults.") end
    return ok, err
end

E.PopupDialogs["TUI_IMPORT_PRESET"] = {
    text = "Import the |cFF8080FFthingsUI|r %s?\nThis overwrites your current thingsUI layout sections.",
    button1 = YES, button2 = CANCEL,
    OnAccept = function(_, key) ns.ImportPreset(key) end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
function ns.ImportPresetConfirm(key, label)
    E:StaticPopup_Show("TUI_IMPORT_PRESET", label or key, nil, key)
end

ns.PRESET_LIST = {}
for _, p in ipairs(PRESETS) do ns.PRESET_LIST[#ns.PRESET_LIST + 1] = { key = p.key, label = p.label } end

-- ActionBars layouts
local L, R = -206, 207
local function M(x, y) return ("BOTTOM,ElvUIParent,BOTTOM,%d,%d"):format(x, y) end
local SIX = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true }
local FOUR = { bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = false, bar6 = false }
local AB_LAYOUTS = {
    {   -- 6 bars: left col 1/2/3, right col 4/5/6
        name = "6 Bars: 1-4 / 2-5 / 3-6",
        enables = SIX,
        movers = {
            ElvAB_1 = M(L, 70), ElvAB_2 = M(L, 36), ElvAB_3 = M(L, 2),
            ElvAB_4 = M(R, 70), ElvAB_5 = M(R, 36), ElvAB_6 = M(R, 2),
        },
    },
    {   -- 6 bars: pairs per row 1-2 / 3-4 / 5-6
        name = "6 Bars: 1-2 / 3-4 / 5-6",
        enables = SIX,
        movers = {
            ElvAB_1 = M(L, 70), ElvAB_2 = M(R, 70),
            ElvAB_3 = M(L, 36), ElvAB_4 = M(R, 36),
            ElvAB_5 = M(L, 2),  ElvAB_6 = M(R, 2),
        },
    },
    {   -- 4 bars: rows 1-2 / 3-4
        name = "4 Bars: 1-2 / 3-4",
        enables = FOUR,
        movers = {
            ElvAB_1 = M(L, 36), ElvAB_2 = M(R, 36),
            ElvAB_3 = M(L, 2),  ElvAB_4 = M(R, 2),
        },
    },
    {   -- 4 bars: columns 1/2 left, 3/4 right
        name = "4 Bars: 1-3 / 2-4",
        enables = FOUR,
        movers = {
            ElvAB_1 = M(L, 36), ElvAB_3 = M(R, 36),
            ElvAB_2 = M(L, 2),  ElvAB_4 = M(R, 2),
        },
    },
}

local function ApplyABLayout(layout)
    if not layout then return end
    for bar, on in pairs(layout.enables or {}) do
        if E.db.actionbar[bar] then E.db.actionbar[bar].enabled = on end
    end
    for k, v in pairs(layout.movers or {}) do E.db.movers[k] = v end
    local AB = E:GetModule("ActionBars", true)
    if AB and AB.UpdateButtonSettings then AB:UpdateButtonSettings() end
    if E.UpdateMoverPositions then E:UpdateMoverPositions() end
end

local function StepDone(msg)
    local f = _G.PluginInstallStepComplete
    if f then f.message = msg; f:Show() end
end

local function InstallComplete()
    Store().installComplete = true
    ReloadUI()
end

local function PIF() return _G.PluginInstallFrame end

local function IsInstalled(addon)
    local name, _, _, _, reason = C_AddOns.GetAddOnInfo(addon)
    return name ~= nil and reason ~= "MISSING"
end
local function IsEnabled(addon) return E.IsAddOnEnabled and E:IsAddOnEnabled(addon) end

local UF_GROUP_UNITS = { "party", "raid1", "raid2", "raid3" }
local function SetElvUFGroups(on)
    for _, u in ipairs(UF_GROUP_UNITS) do
        local cfg = E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[u]
        if cfg then cfg.enable = on end
    end
end
function ns.UseElvUF()
    SetElvUFGroups(true)
    if IsInstalled("Grid2") then C_AddOns.DisableAddOn("Grid2", E.myguid) end
    print("|cFF8080FFthingsUI|r - ElvUI UnitFrames enabled, Grid2 disabled. |cFFFFFF00Reload required.|r")
end
function ns.UseGrid2()
    SetElvUFGroups(false)
    if IsInstalled("Grid2") then C_AddOns.EnableAddOn("Grid2", E.myguid) end
    print("|cFF8080FFthingsUI|r - Grid2 enabled, ElvUI raid frames disabled. |cFFFFFF00Reload required.|r")
end

function ns.DisableBCM()
    C_AddOns.DisableAddOn("BetterCooldownManager", E.myguid)
    print("|cFF8080FFthingsUI|r - BetterCooldownManager disabled. |cFFFFFF00Reload required.|r")
end
E.PopupDialogs["TUI_BCM_WARNING"] = {
    text = "|cFF8080FFthingsUI|r: |cFFFFFFFFBetterCooldownManager|r is enabled and conflicts with the Cooldown Manager styling.\nDisable it? (Applies on the reload at the end.)",
    button1 = YES, button2 = NO,
    OnAccept = function() ns.DisableBCM() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

ns.installTable = {
    Name  = "|cFF8080FFthingsUI|r",
    Title = "|cFF8080FFthingsUI|r Installation",
    tutorialImage = [[Interface\AddOns\ElvUI_thingsUI\tui_options_banner]],
    tutorialImageSize = { 198, 60 },
    tutorialImagePoint = { 0, 130 },  -- lift it off the buttons into the upper-middle
    Pages = {
        -- 1: Welcome + import
        function()
            local f = PIF()
            f.SubTitle:SetText("Welcome to thingsUI!")
            f.Desc1:SetText("This sets up thingsUI with the recommended layout. Every step is optional - skip any you don't want.")
            f.Desc2:SetText("Step 1: import a thingsUI layout for your raid tier (custom groups, special bars/icons, timers, bar setup).")
            f.Desc3:SetText("")
            for i, p in ipairs(PRESETS) do
                local opt = f["Option" .. i]
                if opt then
                    opt:Show(); opt:Enable(); opt:SetText("Import " .. p.label)
                    opt:SetScript("OnClick", function()
                        local ok, err = ns.ImportPreset(p.key)
                        StepDone(ok and (p.label .. " imported") or ("Import failed: " .. (err or "?")))
                    end)
                end
            end
        end,
        -- 2: UI Scale
        function()
            local f = PIF()
            local best = (E.PixelBestSize and E:PixelBestSize()) or 0
            local cur = (E.global and E.global.general and E.global.general.UIScale) or 0
            f.SubTitle:SetText("UI Scale")
            f.Desc1:SetText(("Pixel-perfect scale for your screen (|cFFFFFF00%s|r) is |cFFFFFF00%.4f|r - your current UI Scale is |cFFFFFF00%.4f|r."):format(E.resolution or "?", best, cur))
            f.Desc2:SetText("Set it to the recommended value so everything lines up pixel-perfect. |cFFFF6B6BReload after finishing.|r")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText(("Set Auto Scale (%.4f)"):format(best))
            f.Option1:SetScript("OnClick", function() if ns.SetAutoScale then ns.SetAutoScale() end StepDone("UI Scale set - reload after finishing") end)
        end,
        -- 3: UnitFrame coloring
        function()
            local f = PIF()
            f.SubTitle:SetText("UnitFrame Coloring")
            f.Desc1:SetText("Class-coloured health bars, or dark bars with class-coloured names?")
            f.Desc2:SetText("")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Class Colored")
            f.Option1:SetScript("OnClick", function() if ns.ApplyClassColored then ns.ApplyClassColored() end; StepDone("Class Colored") end)
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("Dark Mode")
            f.Option2:SetScript("OnClick", function() if ns.ApplyDarkMode then ns.ApplyDarkMode() end; StepDone("Dark Mode") end)
        end,
        -- 4: Move That Stuff
        function()
            local f = PIF()
            f.SubTitle:SetText("Minimap & Aura Positions")
            f.Desc1:SetText("Move the minimap, auras and DataText panels to the top-right corner?")
            f.Desc2:SetText("Skip to keep your current ElvUI positions.")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Move That Stuff")
            f.Option1:SetScript("OnClick", function() if ns.MoveThatStuff then ns.MoveThatStuff() end; StepDone("Moved to top-right") end)
        end,
        -- 5: CDM skins info
        function()
            local f = PIF()
            f.SubTitle:SetText("Cooldown Manager Skins")
            f.Desc1:SetText("ElvUI skins the Blizzard Cooldown Manager (Essential / Utility / Buffs).")
            f.Desc2:SetText("That toggle lives in ElvUI's |cFFFFFFFFprivate settings|r (per character), so it is NOT part of an imported profile. If your CDM looks unskinned, enable it under Skins -> Cooldown Manager")
            if IsEnabled("BetterCooldownManager") then
                f.Desc3:SetText("|cFFFF6B6BBetterCooldownManager is enabled and conflicts with the styling - disable it below.|r")
                f.Option1:Show(); f.Option1:SetText("Disable BetterCooldownManager")
                f.Option1:SetScript("OnClick", function() ns.DisableBCM(); StepDone("BetterCooldownManager disabled - reload after finishing") end)
            else
                f.Desc3:SetText("")
            end
        end,
        -- 6: Details! to right chat
        function()
            local f = PIF()
            f.SubTitle:SetText("Details! in Right Chat")
            f.Desc1:SetText("Anchor Details! windows 1 & 2 inside ElvUI's right chat panel as a backdrop?")
            f.Desc2:SetText("")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Anchor Details!")
            f.Option1:SetScript("OnClick", function()
                E.db.thingsUI.rightChatAsBackground = true
                if TUI.ApplyDetailsRightChatAnchor then TUI:ApplyDetailsRightChatAnchor() end
                StepDone("Details! anchored to right chat")
            end)
        end,
        -- 7: ActionBars style
        function()
            local f = PIF()
            f.SubTitle:SetText("ActionBars Style")
            f.Desc1:SetText("Pick an action bar layout.")
            f.Desc2:SetText("")
            f.Desc3:SetText("")
            local n = math.min(4, #AB_LAYOUTS)
            for i = 1, n do
                local lay = AB_LAYOUTS[i]
                local opt = f["Option" .. i]
                opt:Show(); opt:Enable(); opt:SetText(lay.name)
                opt:SetScript("OnClick", function() ApplyABLayout(lay); StepDone(lay.name) end)
            end

            local pts = {
                { "BOTTOMRIGHT", f, "BOTTOM", -4, 79 }, { "BOTTOMLEFT", f, "BOTTOM", 4, 79 },
                { "BOTTOMRIGHT", f, "BOTTOM", -4, 45 }, { "BOTTOMLEFT", f, "BOTTOM", 4, 45 },
            }
            for i = 1, n do
                local opt = f["Option" .. i]
                opt:SetWidth(180)
                opt:ClearAllPoints()
                opt:SetPoint(unpack(pts[i]))
            end
        end,
        -- 8: Unit Frames (ElvUI UF vs Grid2)
        function()
            local f = PIF()
            local grid2 = IsInstalled("Grid2")
            f.SubTitle:SetText("Raid Frames")
            f.Desc1:SetText("Use ElvUI's UnitFrames (Party / Raid 1-3) or Grid2 for group frames? Only one should be active.")
            f.Desc2:SetText(grid2 and "Grid2 is installed - pick either." or "|cFFFF6B6BGrid2 is not installed - choose ElvUI UnitFrames.|r")
            f.Desc3:SetText(grid2 and "Picked Grid2? Apply a raid profile afterwards in |cFFFFFFFFthingsUI -> Grid2|r." or "")
            f.Option1:Show(); f.Option1:Enable(); f.Option1:SetText("ElvUI UnitFrames")
            f.Option1:SetScript("OnClick", function() ns.UseElvUF(); StepDone("ElvUI UnitFrames - reload after finishing") end)
            f.Option2:Show(); f.Option2:SetText("Grid2")
            if grid2 then
                f.Option2:Enable()
                f.Option2:SetScript("OnClick", function() ns.UseGrid2(); StepDone("Grid2 - reload after finishing") end)
            else
                f.Option2:Disable()
                f.Option2:SetScript("OnClick", nil)
            end
        end,
        -- 9: Finished
        function()
            local f = PIF()
            f.SubTitle:SetText("All done!")
            f.Desc1:SetText("thingsUI is set up. Re-run this any time from thingsUI -> Share -> Run Installer.")
            f.Desc2:SetText("Click Finished to save and reload.")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Finished")
            f.Option1:SetScript("OnClick", InstallComplete)
        end,
    },
    StepTitles = {
        "Welcome", "Scale", "Coloring", "Positions", "CDM Skins", "Details!", "ActionBars", "Unit Frames", "Finished",
    },
    StepTitlesColorSelected = { 0.5, 0.5, 1 },
}

function ns.OpenInstaller()
    if PI.Queue then PI:Queue(ns.installTable) end
    if IsEnabled("BetterCooldownManager") then
        C_Timer.After(0.5, function() E:StaticPopup_Show("TUI_BCM_WARNING") end)
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if not Store().installComplete then
        C_Timer.After(2, ns.OpenInstaller)
    end
end)
