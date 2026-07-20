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
    { key = "NHT", label = "|cFFff0000NHT|r ", str = [==[!TUI1!S3zxZnQnxC8Vop9ITdiE)Y4eND90n48yCE2U9cQX2KyMqGua3SBVWF2FKeGnieVyht2L0Z0zA24GfcPZV)NJo(izBr752wR2gNe(0hJc3(Cm53dC)wYKRSnffSTEi)vnPx69(UUjEbpmkmATBKvsu4JU2JST(RTo(EjF3ALJVRTPWVQABTXBT7F4gfE5gNOhCJjxLxWk)TRDNh5f8OBsS9sBlNGvBcJUoY5jxBRX()9Dx)N3678D3O8)0xNE)9XUj2MFaL)s3g6fKyBnF6TFE81v7uE)JlP3AfVk8z3PKxkT7B9GF4shFBtCdTY3jo22ucFvp7UYoH8tNv42G(AERcdsBgjLdn)norpIBRdpTP3p6d2A6ni7133LrPnpDqfPOt(HxI7tKFNEhD99t)3K)lV7v4ImrYIide5LCdCw67UMCZWdpHBtMeS29B2Mk2j0ltsqVPltk7Yq6nEzYKltrrSXBP4(BPCtxgk9PQ0tj2GjDQ)2WyVeVWa8CU5v7h4(C6e)OXFAc5vtW2Hu7ZWTbjxhgKKn1sM)cd9xh(sa5vXTX3EoYno(fNVNDX7NbepCPxg6hsSeSEW(ADvDdKHUQQGe(NQc23)bf88(sSPlTpVj8LljTd5Hk)9Nz1D5yZ5JNLFnP)P0llRtYP7K9whnD(8P3mBYh)08Ypbt3M47fGbGP3n)ZtmhxO1Q8NsOm5ljBST23s(BFkaBnRLzx7sn4(YfZMnz6SMm6SUA2DyqVzZYuMBMRVtI3F7w6rjf)cOS7LHbXBFYnE3cNG17wmdtto4MPO5r2S8VVNOfzz39Zro0PUiIucImJH)PoD(r8qx63lmjxUzMeqFDbQHAtYwvrBwvRLmIoLMd5ONvr0HQVuwYjd0zeDiguzkklzLGyKcr1(axC4EV0JMyDtXMII6cs6Tt7cirv92PDCBRju7ntgFR0uB7MrBfKIAJgUAO6FK0LLuLpNpsQk1)izO3TNhvJ67WiKC6OwRnJOGuTnJQOKu3gCvRDS1usuxP1UIjw4uXOTHo8iSSGyRELYMU1RF4rR1(JOcsxTttLIP(SELdGi167UsiKIGwNAgT6Nm1tz22AIKYQ)14DLeDc614oTMxEVADuA4v0)FUgDf3U5xuBoFR1bEHUS8HxT8vwNxZ0)ujppD0Vo3yb23qcDYrohFhfCJxFqSOso0)0D0Ey96EQOuLQgdcuuWOLa3sLhvL1Ku6et1sGgMgAYQO2dofBm0nrqRpDXnxyw)4GGoQD6Xu0qptnT1hWBU4JJBWdQmQvThtzfzP2J8gjPi3S8RuAa6sYTVOar8mDZQ0Qz3tjrPonWF7SjJTMxVVqnfDLwh3vAxPgp3GAwjEVJJRgFX8p9BMuKQU(LIOGcQ1XbffKuRddMY6AnlUJYUkzPwNTLnWcGTonIBlduNglg))M(BnOpiPjJqT33LuLme7MBqm4)5Px(BnrIYT3u4ltwtRBK4vJVzQzB6Gg6k6gDG)v1e7w8F3EXNV4QjnP4GAFbZQYTRbQk1UvJQHSq3gRAATDMiKEhwLVisf7wrRBQKtnBWuahIMq3uzMn9J3nUHauXrl3QrScstRDpHgQQDmilURbE(0BZwhy6kGVY9E3Gy8FF3IlVcVo4)tAIS2T4UR)fo5mQA6Ek9GQPjl3U4TQcc1UVoKHOrZTwQFfdnLoKSjDDDH2Nb0n0B8oQLUebfd52m5PZaNJ8eqI6R(8ns0(oMuCI55JlBbX4wiYDcEH9KMRWt8lropFLxe2cA6xml1fVKMzwBR08b8fV144fnXZKmjmdBj2BzlBzHy7JyIT)RLcdMna7QziJxWZ1KES4eNvpgxyXdxlRGiYrcQgAQiL0Lnyuyvhhw8qJ990gEFpxJ76l0Re3p3vbL2whKdYFf(lf4WFl7Uiw81Qzzx8wrrZR3G3QAkSAJ7UTJYzJ2IhI2T4d7wmZ7HnjPMGFYL(VXrjunDEcTqP7NnOmAgZYNsRl7wm5RBzTPT)q3J9dlGnh9cfsuwdzhil7bOwsw6(vJlKUSBjgfNrxmZA887U9pPwlhwCxcVC81ShI0SRFuFgh1SgZYUMwwFEeQKUts8P9JMz6K1WuYSP0H8wkzsU68EX1kc6QY4G5WX3RjlGdlhlFQvvYKxF)eLm5NEL(xYK9LF1Folnjzw8JaPqaGzIN)N5obps1q)S79j)YRxdTJr6G6Se6O3wjuosKYC)Cukjn28NA4HqQRrF74ej7GQBvP66f5jXcFgKixw8TTKvzCzn(BtfaeYedsEnsOfSh6IeQu3LqrNTOofoEf0u)WDjj3ljzUglGQizOkROIx5LordvPq3uGJAPcx1sLw092RKUSzjtEXJwA4Gra141fzDVerAM7R6uyZvxVyzyUY6Ufed)4YYPiLElKuHJroDjtvOCEvxp2aqR(Hhlz0jnUscWlzEQ5eWgh54JSaCk95FxJuEJ6SQVh0zHv3dRUVFwDFXqvpS4EsGPVzRTh9tIqkhHsJtCf4hRozP(2pmTsCB8Np59qKtI76B26N4H7dKaT9EYnQCnGINo99It2xbO4(1lZ)(Z4M8zVV56BBL2nYJ9AYAFQCBTp5jryMOOWbZOUyXzxfCRU2ng)W5qJ7N4oJ0bM56S(7tWYypT0jHj1az1I56Tr03ZfBtcPwtB9WpMbzzE)L60WlOL0mhrlmwlYS2(5QxHin)keSn1ooABQNDv)UwpfLJzTgVdmzd4eRNI0bXRJ8(NDl(VBDwJNPD2Ty(891U5vZjgYKB8JEbRXwWypT8IQRXWjq5M7xh5(xBDdw9DQSMchgG8cF2n4bIdCsvtNB8HHwHSlFJ3QhdCjCmQaPWM8R8bMmOcXYllRWlzT)x24IxwSZkIPkdZKwXHVyABQ3o9Wn8eYBQ4WwNTZ5mf1Ym4RPYIkFrTxfrQNbR(JUkIwEMRIiQCNqv9oE6tK5rwdNQjysKnSlUcH5pPehJehfzfxoJRzU0i5T0knE3KBXbEhKS)ZL70iXtN9K(5K9ygrPt)A)OkUVJ1XZrLz8bdc(da1iB3dguJva40yT89SbP69h5KgliBHKJVTPdKKC3Um7IW)KIP01881k3PBcxx8gz5fSXnYlHUO3kxm7ZD61MT(esaVCNHYhaoyCq7EREKm)eSU4OpDdkrgZ)18vTKNBDX9r4BshAoaOzr1mc3GRJcFo)3TORXJIIKPJ8fPKV6VYfT69vyTn5zVsM3SuPN8YP1lzBmE(zog73gLvkdt2TyKVtWJP3Nd3vYs((kBsbzgJZh8krHurOQrnsh9oSgpAZvjPJxqFySTMC5uZcJfvN2QQP2meuWWHmhK3XZUS8DMbEUy8bL17j25e58ehBRBgF1K7UX26L0eUGKYuvVkpOTmXcQbq286FeIvJtntwMzaCe2tKjGIRbM87z930ftSn29sYI8sBZr1JNemtfWmaZamRVXmeGzaMbywFJzIVdXmY7koEB8Ufwp5eVP8UYSi1n6SsDKC1(VtQJo2txAKGUGUkpm8KiTkM2nGExRQziOOljtk9zDbfr77)a5dZ7TfgBuT5OatDW)h4)d8)13()uamdWmaZ6BmtdWmaZamR3xnNiWzaNbCwFZzgaMbygGz9U7mbGZaod4SENZGpSnGZaoR35mzaZamdWS(eZY2mvX5vkzwiK4E7h9dFj3MS4tcBjlZLWw7gJnOi7xhs1gpjiRAJxEe7jXW)2nkYBTl9GENywsE3hQo56qQhDDF(csjGMmJ0LZ7XtcIXT1HnH0Rzt1K)qUPWoqRkQXTaW3B2wgA5wx4LRdCE8ehbbgR38UkFnt2TSgtjixfKkVrUkI9L2kqSfbEENQXD0dBji)phiKkcXfAZRBu6M)Gt1jGM4z6gdG1je7wNJEbTVxpByZyYw18h8dWUjFR1LjbGna(f4xGFhS8ReWV)RLFBWcJZUdca5tdK5ilEg5xfGFb)VG)3bR)3SscaayaGbaEqcWdp(16fmZ6f8WUfKZoYhDl)9qgRXepAUW3jI0tDgoGXRGKpSFfuf0e0Ftq7oQpXrTRgfagwNVGWjgNDf64DcW)79rG287)voj7kPa0mXJax2GlBWL9G1Ln9Z5TYao3Z2B2pwTspc8EhNdupQaQNF0NuJrlF)7BxV2ny3IRCDs2CC(2hvY3E6jUh5Cm5KDWl0OdEfKSK2BIoqLiwQ38H5WveDKu)O6(eL7ONPCKQmFV3DZOJHRlp0XN45Y1Skn8Kx4Y31P1L7ouVoH2ACkvbnA7Sq9Anbvzz8)trvsxrajt(7YhqZA0eaF6qEWH8GpCZdUgWVqm5qm5d2yY1b(f4xGFhS8RkWVa)c87qKFt38dzNzT07PMaZjzR4pJNKTLRy(g2Oermf2(YHZgLO2I1V(NPEzVtu6BwpvMV8dFZ27ev23bC3YmTU5soJBMcoNiAf3OeSB2d4KSf2osW2rQebvHPzzOty)knepjBbVzG3S3ZEZGZ(iWDg4oR)DNbhmTaMbywVJzWbtlGzaM17ygCW0cygGz9oMjc5abYbcKdK(ohiW5sl4nd8M1)EZGZLwGZaoR)5m4CPf4mGZ6DodoxAbmdWSEfZypxARUDI4UdoBCRaZw)LNHDb8jwCZD5i948EeEWTkMRwDYvkG5Ak0zEuexjTwknz(ivx5NYLXmBbTxw0I1WVqrbFevOCx2)UnxrZh1U7TdMZDy7(Y3Xe3nZBP7st7ZDoLN)rES0c8lWVa)ou43FihlTaX2mX2LZmjoxFJWC977EMbQMpNw4QUxC4b433u(vb8)c(Fb)Vdw(LZXslaWaada8GbGlXVJE987O3y(9I)gBArpKA)se7XyxzlTwoe7Snn6TdOwzfzjfX3eANvcJl93(bEA(rAhF4UMZ6Qr8H9kNmIqa3nZ7KtNoKGIMQGGSUGKMUUg50PtPWE()SQbiaoXbN4Gt8bRtCzGFb(f43bl)IGSydzXgYI9GLFvb)VG)xW)7GLF1b(f4xGFhUjXgbamaWaapeb4sNQSs0tvwjMtvwTF(pvzzRk()fUdgyk5)Fk38cN0UrH7(AHNehCupaygGzaMn4pvzbmdWS3V7zV0vl2PV0i6iyom)ok5nyjK1S(Wg)M94S9DWnVLrxCfGml(SYIBBBfL1S2hEyrEAjEV)vR9r(vK4j(DiKbWVa)c87GLFLAnBTVTy6r9DM9gpx)17w8fhF)s1AChH2sfCSCVvWX6AIdbKMRajhUUATV0CIElNKAgG(DYxxydbsxz4vytwK)5UfZCV3hZYKU5r9fJplIl1BiUKUIKXBZEkOzlaw7LU)1MDN(gaekfQH3gcecohcohcoFq6Yw8DqW5J8dx94Ro6CLosX)F278R12ggkk(NOc2sY)rVwAhSN2GbJUxgnqD7c0LaPRmyp0p7lKT04kjlB5evBf(9bO0qI)PJoxFp3B4s35sHktXf05c6toTNHCnY1ixNSaSkLLR9A1Ems2XZTTqQfzOyJI9ud8Ieg4)4dRwVP5LB)8ILRMXfppxNPkkb2b2NAyV0A68y8BrBw)6NEA7F6YfpU)F(xx287T)MgJ5ZtqY8pF3DnRE52RAmNpp9wn9lhV(()XVHkVRR2x28ixl9olO6B)CBqP5v1wJMNXLWyxZONUo7kWIP7Tk2tq11Tug9J5((uFtNVnKwpF(PDFbV)bKUOO)nFFQZ1QQ6IQADzwLE7xO3FrXU0p8MZd6cPBNBrmVJ5DmVNKY7vP3Rh)QMFUEZIhx(NDJCVV8J1p)RJ7fKhXRXNxMXRhNxp(8nOJcJGokNJbDCORZPeEx7ojRZPz(I11Ehlh62iorw2ULGzGzGzXgZeGzGzGzXgZYpdXSRxTzXdnwt29xHTlb2ojW2bNZ1kzPiy6BqRcule1dz9HYmPkpxR01fYSAP473FHsfeRncu)KYJ1i7bjISxSL9kaZaZaZInMvbMbMbMfDtC5WzWzWzXMZ0GzGzGzrxoJA)dNbNfFoldododol2CMcmdmdmlMyM5m7TIKoqsh6pPdE2n5KZbx0IJwm3FYhoztvOjkPdHeCXXqOdSDYt5vFAhp29kvg8ZubLObxHE8BN1bAW8qXad4GtfPofs8nMrq)f9x0Fts9xb6VO)I(BYQ)kHFHFHFtw(TG7pZ9N5(ZP49NTZTFzrkKBFwPJSshzbfdMbMbMXckgmdmlvwqXSFIXS4qmlo0QcHVrBWXWOT7rT3X0SdWVWVWVjj)kHFHFHFtr(1rXAvPxXAhLVPzVh4ryHkk93)8WBSzjmCA71WK)P0XBFvKW0aSLd50VyTGzGzNxyMamdmdmlMy2ruS2EAzpZ74(oVC(SWSdy1aBupxMSIsJ6nY2YZ29OJZhCyoU)(ZZBB7mWTnJl)Uox)uMhV3YByx9l37KVWwgynTe6wdY9Hu(orYXtY3yDi1Xxxwqvq1HIQ)L9ox2PTbIcd)40vvAUKzS9YAKYUErPDbRadftjQrnvKWISXp7abekz84ljoj2o(7jasWFZ)4dNZ3bu9WJQAqvqvq1ooQMVARsH2PCRsk3kVGkVG6PToqStRWqryOOHYoT6WMMnz6)lEv7CyrnPHanpBFhrquBNVn2OccSgJrhkc0wPUQnVZTT9)GruMorEe5D0J8yFwbMbMX(ScmdmJ9zfygygy2WS7pNCZFtPqjTAHsmMaLIsLWwVIqpc9yRxbNbNXwVcododoJTEfygywpFRxj7CA73TtIlVFN9zyHoIWVlS5GBwNpxQ0cC64565abp(4WtjrQ273EX4cA45n6(463RZ1rb4hxjFVvhS7pyQGw33t7PVRg(ocufufuTpGQ5xMgUFbx9WLCegRO90MtD2HkQa8m3F(RNuNQ3qfvWdnEN1i)w6QcOUiRuDzzuHVhG62gEYj7YhcVzwwfQWk3ch5YQEPWQxMge1sulrTD9OwPewfwfwTxWQBHQXn)AXXN4Rf)RP)j9XpTilz8tpUkxR5uYDK)WF(R)zC13mhA5N(rlRyuYGtY1LR5D(pLxHoUSZSCsfodUcDvssTb3HU5(1iGyzILjwUpelpcufufuTpGQkkSmfwMcl3BlS87TsizTK1swBhpRneufufuTpGQwqvqvq1ooQULmxxpNUwRRlxf9AzU2JhjG9PH3hGtjWwdhsLJrrpzWBSGzGzGzTVmxF9Z14R)XSBwL(41xCZILV8HUHi3ILRML(gr82d8zjF)FZwLL81P3T7Z8wT8wYfZF56g)(9VUl0FjX7kfgwQ)seDo)LS5Js36tDjRF7HXJmkPYkf2OaRYyfxD)NnANDmqHaz8xMuptMOSMaDZezs8UD(DdO2XwHEKugnkk0OfHALpHNCBPcpX3rG7OKtCxcSEHZULByjbLe0Z5e0qWmWmWSbIBybZaZoNXSaWmWmWS23nSNhLD5NpmnD2DzjZVplz5dPzjtE9xM05pT4Kveg7WrIS1UYlsTAKqFySsK)dYDk0u7w4f3sg5IY5pQAVR6se5NKFs(5qrZSWzWzN1CMaodoZhN9m7D(1Btddff)t0KsSDstFSLjajaXKyc0Eb1XOvRIrJ0A3M4L(zNKwnO2(g)NyNe7M7Ji0Q2uZpF)toNJro7mmMzrmdXSZvmtmMzNO12IW4NJwvesH2MBvX5pu9WFfKCCJkFP()4LBF8N1yZP7tbqtSq63Ml(pyDw8Fqsyj1lPbum3YcXwsoWwiRB(tvapsub7a6RrXpEo33jlYB1k5wedez9tuVTfoy0e5BRwm4DN4UvAZZtT)qdY7gYhcg75G2MATDc5dzszf)rlX(VVSExTZFQM4)LZ4oTZWDgLKNyzE)O8PeVL7p8NoaEQROpp06CDDo)a(0SBoV83CqN6p2g8TnFQ2av03AFz5xWUhkBd(LS(QXsDkdzo(MFmJhs5E(K7GcXQdJOI0WfcnSgS5g2YYGVvKF7BNu6w1Ati4EQZ8Qs1SP5gJ4(W4LaF7lE4Qigdvt20HF55C4hNhHDLdFyTYpcW6vYPLJR9MdKDUy56iSCT2GQXbmglxhWLRJE(Dw1N4MD7xC5Yvl3u)eNfzQB)v6MMwK1p0o8WwGjm1nsZaQ(8G22BoUdTaI3tIY(ZN9C1Vqh2K(3Q(HU3To0PDjMxWWg0Xg0dMg0zr5YZVC9ZvF1TFXrbjhWVSSCgbxDoU68Wy15KyVx(kCFZHI8F8a85qN8DyjEYKSuSvESv(bVvETrwOPNP7wR9ULM38sK5Qhl3v93puQVeeJXNMqiH0vJttHVT6L9bb2A0jtJtPmYQVBC4PRv2s)RcRTyV1Hk8a3l)7EQwYB3U5iHpBZDRpSVUpub9Bd130wrEE20qSXEGhwmP7(ggu3Mobg9T2RVAQ(yMfwIJaQGSPT3rWx3g(62Wx3wm2Zox2ftR)NKSjcHxmn8ZUyrf9h8oirRBiCkwgN7PWaW3ofPvrbbOBsGoJZNoirYtlIEiPfP8GNt3deZqmdXmhXmcIziMHywxIzIMM8aYz0O5gYLd)(I5OsdFxW9WiKd6sHGgJgybGNU(x4HB1ThOggcccpED)e4oFuFtfPxCMi)I8lYVrj)sr(f5xKFJr(fABT04BBTUMiSrwOaff5(QVhowChgGZ9kmLVph5v3kjS8sZjg3wlIziMDEHzeeZqmdXSUeZCyBTHTI)KWm1A31WPS6ev)4GY8b8Yh)5dnBnp)ezDnUhbObEHg2t1ftEtsXPNgm8KjyntcU2RGkxCAtkIQiQIOAmGQuevrufr1ahvbw3AU61Tgi7bYR3)wJfjhf9dJkiISUBA0bx1EueZqmdXSrI4yrmdXSZvmdCDR24J6at8nbI5j9BUhamDNIzKny(wZmcngac(trowfgcUkowKFr(f53OKFPi)I8lYVXi)kVT20eIW2AlSvCS7w)W6D)51hd(66LVuhM3MmS71F(kXjDN7GnqNZX8xx(0D3VFXU7xUFXBk3(7YTsrt24DU2o6wX8)34jzj08ePNPVas3nT6(pTfxVOMpF8BZtOS00PSPfz0Kck57RUGXSAIzWfZio1myjLJNuQD(yqQ7iFNJg2ocnSDmDr12Ml3xpUokOd4G2iL1NQmOR(9vW3FygFbXpvwUz166hK7NYGP5J(YGP5SIuIeeMZIKYGtMMKvqzzftlksYs1vg8hESm4HEdTZGjNJ5b0FzVZNEuByGO4FCA7Hkr(hj(Au3kvPkTh2dLJGAdsOsPRsGUA7b(S3SiQa7m2X2joXbEx3d7YgYV555LjZd6Eq3ZZ09YaMbmdyMRXSeGzaZaM5AmlfygWmGzUgZcgkZsQ2)62IZbyqXMYJlR)JBHzjpDaELmcELKOYnaRUlLUSRfmzhFFMn2mflMcpHYxbgYOmifcPqif6CPqSqLbNboZ9C2mWzGZaN5AolgygWmGzUeZeFfOs5gb7CBsqwUrgnVxxkgIJ(mr2XwFX9u2X(LDRpuzyQXMZLMKpE6NjzNtqEV35keAMOKXHS404Xl7y)Cwq9hGSK0m28zPS6pTR)ys0vFBE6sVygAloJ7xpn3HY3hXATpJZ5lU)qvv9nPBwTvCcG1F8V1yYUvEVSVNL8Qx1XbPzckGNVo1wg1j7k)5QfmSaDUZwGo6TtTXc0Xp31vgKoSTkOp8qAntww)l8h2N)7NvYdCw4qhMYsNX8PyGNt2orheVH2IUrqGC1yQJoUWm15X79Usl9nRddEY6PDb0tAf0Dx(HqL)ZMq4FQSy1VQ7h9qz1(UK)7MFIDd584OO3ENDKltRrSb3ZQ5kFB9AqCwTi8KueO1uf3SGLw5Vk9rFDYHAJsA6wF1lLfMmkY7fIQXIfSvVOdW2MfNahNaF6SyOv5OMYLAW))kP)eKB1dT3oV9lfR(tr57QoU8BRkFMttwNe(AynslIfXIvPkZJFDbMvi3MR8(ibBYOmQrHsCUwYTkDf76RC9KqSosTQRfOLqCJspQOCPEgQquArJrtJ3UtzWLkxu3BMJAZ9AB31ri)Xx2(Zn7oUSga393x7CV6rdHw)LjemjnmmBqdsqIsHC37X02Q9f6VxpUuoru0HUO4nSv66T2zK9qhfUnRn)0fptq803vUh((2npxvCC57F63Bxv(H(G4Dvx7zjbPER5Cmyo3nV5CHTjV7VEZj0nqX69g3nGbc8ugM1hLao1IqS2TiO(O0JARcZ6EJc0A93Wniiw9uwRWsBeGPqBswB)ZGfDWIoyr3uWIUmtKNL6WqhBaVRc1xoq(xpSt8a5T(G0YBA9HJM6T6dJNniE1jTPm(p3uwXjib3qW12USVBTOR9dLqwrJtSH0r5bYFUaKeRqnhQ5tVmJlajghYyN78m2XIi0P)I08jyIXj)1Qby2aU)o6Rx4lEoBKFJVeWCrotSwbsmoGzqnZFuZ8IeJRtt3LXbwJ7FknYFWSD8rWy64s3hPgU1dlnjflPbqINe6imz0k))H6zWW1rpTUKeRmiAx34hidqvGQavNcOAeqvGQav9CuTPzRHZJHDRObveP5JxKMpbTBfygWSPiMb7wbMbmZPyMxy3kciCeq4iGW7La(pa8l4xWVtw(nc8l4xWVtr(Ly0yNLO0T2iS91NGBFD)OTvR8HG0rdQkE3u2inhygWmGz3jU16py2)yV7OetqyyWaWxPXMiY9)ITN2dcTsLrad8Dh8RPnsYpMHzBpZ664moJZI2zpWmmdZIMz9ygMHzrZSbmdZWSWFCMVynFXAgq4Ox3fJQMPAMQzHxntk8ZzCw8oZFDgNXzH7SBygMHz758enyrtyrtyrty9nHQOkQUru9w77k)9lJ63WPiQXmV64gKO)z0u24ycv6iTxK55v(zz9fQFLFGw6UM)vt4SpNqlmvqtpWCLt5NLAQsTk1MIsT3rvufvtZsn1TIDRy3koB3kUWMoD4RQZo)0Mm39MH9E9tZwDOXvQIDUxHgBBurw8O0P5b3cvxNNpzTx5Ewor(0ptNA7xNnK1O8offKRQ4C1JMlx5RXRe2ET8LBNf)YV8Bk9738l)YVP1V35x(LFtRF)HF5x(nJ(Tue)mMVLg55mRNxtsgFbJ)5N(6Mx8Rdpjr9ChMHzy2fjr1Xmm7SYSLJ4hVw0Rf9AXS0ThFTd8l)QBT8l)YVhD3A7tre)06cbmXpV9qwiGF4VLDEBnE3gaKK2iDhZWmm7I0TwmdZoZmRdZWmmlAM9aZWmmlAM1JzygMfnZgWmmdZc)TzECgNXzH7SrmdZWSWlNPL(H5SFzVZTEtBKO44FIwjpx9m9r2SiLh6w0UrD39LwCkjTiLcvo0gLx4Z(AStc45MVatat()svJQQcyp)oN)NZCUaodC2P2Q0cCg4SZzoJdmdygWSJB)eHjK8zZes2SoLBA4PIjKmwXpavbQcu9qmmZbQcufO6jmQ6QHGugneukAiieGkcqfneuVwHWaZCHzNg7eAZtOEwW31pMFijOESjNnPmltfd)X3uGnQ(hZ((pMNp)lRNE1YF(LVTLOgzquJoOefrEkVG1Fw1)yfvk4SeUQ4p5mP6t3(Bc(bZhw5RHlVOqNexVvt1UF0Tol2lHj9WRwhxj7JLjmoHO5ALGLOy0IhuCEaY966KlL5XdHjCg06tDq96ZRYwdoeHdXHOdrfWmGzaZInMjaMbmdywSXSuGzaZaMfBmR5yZ2Cyy8NVkl)R30suR6MToU3lWF)TSzlFy90)zz(S3TE6KS5lERKXL2DvbLpahlt5sHuPvkQwqQs7cB79FEOs7IqPTytIh28QpmPLGO1j)iN3KEKDNUDXcMjsPg6ni7nj4weUfhKUftaNbodCw05mk4mWzGZInNXbMbmdywmXmZEtICuAoPR3PmQZdp85JwLu)YNHNRQ6vrAPl0ZvSGJkO22EGVIZD3pznuA11lKA3gB9wr4UQ99qvpTV6zU5sO29oxO(JXqu6UfSTTfPDod4Cvle8)rNSnzw471DbeSJh0avbQcuDiGQ1BoPrnUcJ8)T7PF9J6rRknwYO00KefHXysrQ8P8M)C7lnwPtjQ0uoNj1kPsxvoJDeW)JffFc)XMkg9VMF7kRRVy7dmly)LcTSCJk9P)u3(fH0vFysLWNxiDNYFFj1(CrcrZEvqF3nTvv9JMQjuAsXRejlP4VuErgIYxfCbLqLKePovsfYKn)lPBEv4WSXUwjObaBpx3XwJigUmAS1V(3qDIKRJWNgMtCCbkMwoSVkXj3L94n5F(3ZUFvrysoV7WQtG2xyKPzBtVEoU9eJFBpzfr0Ove3(aIDNo2gZcVF(IzRNEXn)Azr4L51ml44iDJ2gyh6LK22IToLrtONkTcPnE3PvJ2O9Svinvq2Q(n8KP7iBIYTm0710PPCrZFU1DLRV5mabA5HwEOLFiOLN0jVWUvpSNA5leikKcsHe(cxvALGNsReiwwDmUv53haFYYhUjF90lxC7pVFJDOD9A3iV)kkNNuOG(vc(RVyr9FKZWRDddWaIPxBVYl7Z4lWWvId)Z8HZ0lWRrqJqxCzt0JstB6YD4xbczl3Lx(qA5Ln5W)OStJ7IXbJIv89zZkPKoeW)1gwieXtuptWLPTEviFiK57Dl5A8nWRVjVkfAvS8Hfr8FHe4E(TEKT8byQM27U8(ql0NFedHFFL7xb8pUrpW9Lu3EjhiMrWl0kYXk5EUcOPRXhqBkOEVc(BYXijSEaeyGPY8oeyaDaZ2FC58z3Um)77DI50rdRjAoLRdLyo7tCbzI6OSpGVf4TPTpNEtm8QBbLDjd91nGzGZTIImb9o4Op(2b8yBStmFRgyC(t6A4maKGS1HS1HS1neYwNcOkqvGQdbun94xKm7l4wDl3JVl7X3vgMC2I5RECFQbMigLSMWtiVQ3ZDpLtBgzSPbGGdd4r(hiZbZi05vqYbm75pMdB9ZnpkGB1C)TSk)jjCJ5(RAip3FrZFGM)yi2JvYb2aj9Tcc18ei9eEQzBz08io0SDzlYeH61CBzio3FH3m4n7SUZ8jWDgCNb3zX2DMcygWmGzXgZeaZaM92bZ(F27SPNgxhkm8VOrkX57LuwGgjMHRyyqt3LuixMikPsPTGywKF7tB5d1Ky7yhhN405DdRqqvBF85CC87JhlmlaygWmGz6gZe1AV1dlJsi36nVUm99ZV6bQOm(Q8LVwg)TS7fc9Mvb9(AXQ8)FBrpAL3W(ZkVDy8B1GYf90gHm7SRftjV2reRqBvVkK4)2b7fONlZQD8S6BqKLxOJR3EfgB5ztZQVlyB1xB9FziXk5kMJlFrXsuS8KUyjbCg4mWzANZSaNbodCMU5mxGzaZaMPtmZmC5lpTcu)e4QLGpWot29xWhgCpGTO1CoW9uqVqrpGrN3zecIXv6x9JGaOxyIruayLsfAhAFt3LVmnHaFwvKOcpE5uIbvsneaTNkykF2Y4lg0)wunqMc4kQHp4gVzPTZP5Nj459AMGPkkj2R)kHGFPWVgSwp2w8C2ZjlpeyPnz53TzTCM9OUgFC1wML8TD2)By0I9OLC(luzAMDwmxwMMg4AmrzQpY5V4rysHKj6nE0TQw6AhNK)NS07lJVo9H0803FnBOaoHe6sgbr(zs9AludSnqhJR)7w565DXDrIzWVjI)DXOYyuzmQSSJkFavfQ5h(k10a1hWfjl3)F4UY4l2MuCFwsUkUdqfDAAXVmTTtGvOW60u1k3n9ZAGLVR7UF457e6zrCF7Mk5ZpmP6V1ignS3(q6KQl)h2UYbKVl(6RJYybJJ1JHSTJ3b7B(X6twc464AL3)fNBOaQfpRxd7OVlF1H3x)URucezs1M(p2MV7pAw(d76tFvsHA9NRpPHyt8CcIIgeYNFjEgt31xBQw7L4)htHUQ0HEts2rh20Dsb8ZskEC9JzM8K42ysCmj(qpjoz6Ur6xUnpPOmEwAYtMA9BILRLV)414U4QXwKX0gU9yx0UZzDR4naTORK))6JDqVzvEIr6rxSRByx3WUUj7UUfoDB1(NfR39XAz8TzpSQWu732jiap6l0W9W3WT)eEg60I1PfpAQnB7z5S)IvdBvg2Qmf2QmBLX8kU39WRyIFyn376BIU3TAyn60HN34t0rxsTGomy4ukPhkK9EPJ1rT8Xuprh1tqeCV7jFMOmdxF2j9wqLMOT4qFsqnyAAPIssTLmfDVlQMHQzNYvZG7Dr5muot)LZG7DbMbmt7ygCVlWmGzAhZG7DbMbmt7yMaZMTjBz2Mx)4bfDBw6lPckF3BU6)u7MiIJWDVC)FU0IY4B(DsEz8zzCCVBptGHgT7DhmO8ZNNPRBKVvudk9lefjrz0QBdqshkCQAXaH0Q7BpNVwHsQmg8QlkeIcHdvHq47tWzGZ0pNb)vdodCM25m4vxGzaZ0kMr3RUIzGeXaZPPmp73JnTmI7K7jSTDbEky0ePDuYp(47sjfIvpa319nzLZonJd6onO4JtMV5lOt1K5N0Ne9okRZiWVGFb)oz53MY2DCXuPYS0YDVuxTDtz85REAXQkpmdb52HYvaKqpFNPaytDzYwCeaF4M6AbhJ1Nic1EAW7EMIMaeVE85PltxVjBVvTNvK(IXM6ycXZkWeYOyB2LJxCf5IYiJIsLrr6vofmbIIRFabSXlAqhnOJg0NKfST7wd6)L9UBYPHHbcddFHyrCID(5cGu3al4ceeQrTcuRe0GGUiNDGUa14KwzL2Q4X(DjlrQpEMjX5B8Ig0VF777w389HO4CqP7P0HU(gMgNjvgnDOth6Zo4tOInvSPITybSwEJyVyZN)(Fwx9dRB3)8276Q3TA5Hxy7lV2v)4x(6i3QSutrjJCZi3(0i3PcUJ9Nw12082sF(rPRm6IkAuNg1N7685c25h9m1xSPP9d79yNVnCUwLycx07AgbI)NYUPD45bxW6RSKHZz4CgoxSfTlWV4x8Re97izVRj3k7DZ(p7DTVP5aFGVlW31EX5mGj049L(EWXV4x8Ri9Rg)IFXVI1V8HAIFXVY1V54x8l(vI(T3d(k7V)uP16t(KV8OTovVGTysrKreg3joSto8JmpXoAAora20p9wcQedkhMbZGzrYwNcMbZczMPGzWmywKS0PGzWSqMzgygmdMfjlDkygmlONnJHZWz4SBUZQGzWmywSS6OWz4SG2z8QZWz4Syz1rbZGzHkZgS6OsMJC27kEJLDji9MVRR8GBgSBxt5rUg2NjxIC4cnpA(5zFKQZ3A5tEjShC2nrPZT(lsOc)IFXVI1Vz4x87XFly2)Uc2ov2E(JdTdMijTkOWVu)L6VxNeXrbGbWayzhPv4x8lnqlYgOvPayamfGLDM0HFXV4x5MjD4x8lnqlYgOZXV4xQ)k26VL4x8l(1h97pS35wtnksuC8prwv4wdSVzmjZovTbTe3TQ5fvsehPgmzQeSCY(GF23(cDOVsanwkZEEkAa60xo)(3DFGZHU)Yqc4xGFb(D4NtyDrUqkHfcrbiefGuclGzaMbPewaZamdWS37uc74tVmD6v)9f3C15x0nuJTRbvuB8HqnLoDXHMXsy0Ss8hVCB6dRx(dPxQ9VJiLdQpiL1rTnkJAl2pQ9Uqz1C1EoBHO3)F9u22QDL5SXIVuUErwP4RY)OiVO4w1kT3jyewP2DhsKsHr14QwG2z(bUooXobHHihKxm667pX3VxySXzlurzfTjNdrQsGhKzzHjfHjfHmllGzaMbzwwaZamdWmiZYcCgWzqMLfWmaZGmllWzaNbCgKzzbod4miZYcygGzaMbzww45I(qpx0gI2n4HH(v(WqB4HFU9h7CiZYc8lWV)VJFHmllWVa)oC5xiZYc8lWVdx(fYSSaada8qgGb(f4xGFhU8lKz7aaga4HladzwwGFb(D4YVW8Va)c87WLFHmllWVa)oC5xiZYc8lWVdx(fYSSa)c87GKFLYSSoxx)vBYwwKvU9SjZjvnmywH)mXX1lmkcBOI7cWxn(mWgFbOyFmAD3UvzpwSK8fbi)q5Zb5gl)nOO4yxHlY3d5rYYsINs8OWrIL7OGqxPZWZX13Xr8RQ4pW9u(F75Rk3rF(2zLXvpGh7EaBAs0cWNA1MIv)iVI3kftDyfeJA2JMEwfUp9HRtN8TKtN)1ZWdrKY(I1BlOIBPttMG7clX97Lf1Dtb4QfcxojU(rbrE4)QYuLGie(ifFMoF80jtMorOTKkufkwTS8P7YViB72AbrADGs(pvvuwuTt80VP6PIRyTT5fFNONsBu4HzsZSIOkI)CznKkMEW2BaYtny8ts36x8in0Ik9Zplfbh(xlshIfOUXn)OcSqfTB4zmUXJybJ5DoJI0YhCFHIcIRJbfAlIsX8OrXvtg)ehpNwbRLK4ra3Tt1ivSWW6Y0iqiKf9bLRXNF60ZopzYPx(nYfZYVZgoGlcz7ib2UgKVLd4mYZ2Ly9xbfARW8d9SErEwRbwBObXwlnRhjyK1RX(rcSwAwpckYA7XyFDnPNGTtPxUJ1(WOrwpK1EE3alLhbsY(jLPFwjoX(LWFBCUSAfRZQTIjMT7AYxDSy8ImnrkjbaYZ740p)sEXMxUTwW5velpARgOlHFLs8kDeJ8Q(KPkFvblNXWU7EnLv7XnxxsiIIXvx3YiIAr0vxIgpLq9smkWuJYltRAvlmUSVINQ9jCsWk73BRSwcLqDdWJVvgRh4LBjRN8LBNxCxRgCdIS664tVS1nt0BZU2B16)aICKAybR9AMZOLRwSclAhTWIXMU5IQ5wKG52cD5SdGaQgFAiGSL3cDvi5auTrGRtBiwtst1XlQBl8i4ZLwCQaZRlTVTBdUPWK7x6Opke96IrFSyEx(w88Ij8tXli97nPJ8VQQBNS6DeJU16FLNKL76nto(q3HrA(u6qEZq1vlAoZWKkUnNVyGap4RvhHPHK3KjfyUl)(SNkRAwfkNC4E4inVcVJz5nH9Z1pNVzsoz)9539N8SiaPXqo5T09YtxwD9M1Q0xenB4LEISIJ27Y34h9LYZYhY289C6)HhZxMTTI834Y6XIvSqWNoevVkDHvyBE)SRKY02St5Q11jg7FjL2XzlgN)lk323DOmgHul1rUOB2lJqfGFHw9umR)5TungDmQg17A5p457EHAJ5R5ixX2j5cJgRJp8oM9wTDSMWTi7Dnr27l11eY8OZU5IYSD5BugMCFddt6TFlvp1wXo1PKvEfeix55UTJRl9pf5ptBhjU1ssm9fkrYfkOgam)lY1Fye7E5dNOg3aVhY7TMJKfFsGsFBc6iOkXLitCdIiE(K4vhQBpzYvUVCB642Tu4Yvc1nVwSeF2ywVPdJZTyL0rnR2AfwYjp76y(5HEDZ2S(X61PV4vZYgf9Btt)Zsn)ijpFC4ERYZ2SbMDsi5gvee7pYlm2nk2)67pja9jYWWSi)qWM(3Lze8extzcXFXybZqh6nmc5s)NAXZUj83O17jonGjH)3SoF7ZwnQrX3P7k(dvn2wuQ(aMPQVkvFQMTA4kknyNO9niG5RVK2gra2QABwpiIC)Vtq07ho9gesL5cyFWUl5Oq2bzFgoQpIFFOR6Lj1XCl8zDuTB4UYSpl60t(A6PJ)lYtlXXxSwVe71UBbX6b1ki7XGwxBQD31pVbb4avb4)R9U62TT1Hb)eDoqwYs2(Y42LTb0Hf0Fq3vDZjXbXa50u44STEZE2NOKST(pUfddRNvGErHLLenL4hPn)y0aKyc2a9fO3XllWu6p(sP473(kw6l4yEFfg9V0xe)3)MGNpmkalkt3PISJIDtLYLeijtx3OY40MTDFkGy3wl7MwUjNZiicLKHrSecoJahHOucKnR5umoldLJW8)y55jqlqIa5TKskyP4KekL3TmMQLL8wOj87NLNKqiygQq2s4F)V7A0YMwvFE0gsB7s1x2YRs2BsFd3BhNKAlIE5kaOAOisbjdvKMs5ER6vnUtbquv3Kf6LdLcOOJhQLzf7IQh3FSB4ycwCo0Iq(s9(y5aCMyreMwjfgJnyykJA05R22uVBnWbaXzqSZ84HXgI188mArrkHqz4KcsrVYyzprShy8NdDvCfpqYXXKCJNZa6IEvvxV(xLRASRPlSlt5KpXk7Xx8XBvU9XYrX3zgSnnkM11UFvt3JNOQkeMLqcWLwL6zKw)Wz2(x48V)wqCqI(OKAms(bE3XxCQB75ZnqMetenfbRF)Q93VOA96E2MuTAfWz(57BVrEdW9oWEB77wOFeYaKE5oynOtA8ymzc2YW3TCgpUMECOQVwV(w1rtmlRGItWP8)HLGYvhnXrz4SowLZhmv)mv(XrAnlcqrKio)YOu(Vo0trFiFambxfaQ1QDlGaEknD3TuDRPgI5WeOPfChCREOTkPwFj5kLPpjCcKc3iTKYNvlhwvDR2A5ZXVcL7byue1kaaYWf)4xRB3SB)3gIAfj5aKKfmZE4HDn9k)Lh3SPSpxzNGnso0bAcmAmGxfjv7pVH7Vtw3d3SiuQaNYzzGgVTS9E7Smn8aqkCz9Ld0y0ZPG0PZFUWN(4wuctEJAAWHZJcAygZLF6d(8p5ekvGmLxDSB)v1DZoUUzphF)(7R3jIAPfed(fCp7lgAz2HYbb0Ol2l)diBFa4Ie8y8i3ULcbdjA)bZ9agWfRw)FVVNpB1C8aOCiUa8uQJyENgnNeEDuu9uzndlCJvUIa4TNjvfXltf(9oAb8V0if(YCEqwf4ICgJhHcUGHg9hJ0lggdYycJVwfHeUeyCSioCIkVHpWbRuUdEyrLbhPeDp6eihhtvJ8AXNv)8CtwazLAloEwhc0DXqBQdhMnVlXQOsygyftR(HmX(68GRjB6nN)53j3ac7u15NOfNq5XJBIMb70xu3E5(VXbSuW49Cld2fVTzSsU4I9UHHFeEhSwczp0puKuh4rSHfdj1uWcy9afq3unF(NKNyzJz1tDtf00SuITDAetwsTwhRQ5Pq0s8iLyfzmEu7cd6mnHf5sUWNSHdn6MB)BBTSyITXnQHNPLdY1Wjpyj4fegrhcq4UZal3y76ZY4zA(v5b3A5yDPLTvcoAb)f07z5SlV6nxFZIpdZzN0EC2X2kftDlhVceug3jRiqeUlwPGafl64Bfa7rSmOF(6KrRfsuFHeAqR58)C8f(RZvO(R8))CNFjrnHnzp(jQT2q4r(dROZ3BWy7xZ14mWBqzIs4eGCuFKe8PdaoYN0R7U7(j]==] },
    { key = "FHT", label = "|cFF00ff17FHT|r", str = [==[!TUI1!S3z3tTPsua8)IAh(gYJnrTnZOrhjo1EFikewnmIqUaPw7d(3(D)acllleIfVA6CE4ENgCb2po)oNZE2LZUqDX8fUl3KLN84xtt2SoJ87y0VYNE0Iz6lCVV8IZOL8Uiekpm((XjPbOu380KhqlgVW9F34ffM)S7sVi0IzkF20CH7QWa0)GstMSYl9EugPyEXlxLKErsyC(c3XNpF(5ND6XNGFUzltwJoN8mzVk37Js89Iwmtdx7I8YYOvMS1OLlW3jk2ZpcfqEIpL6T(OW0fUxDX2Bc)8cZrpsR1AgQ6kkKlXDtrEpNSjFACa6x4NRk(rYkNtxLtZPOCAoDxUrKYzAQQ1zPS2(wn6SC2LV1rDwoDfC5YPDrrrSwUIPTDx3ILc9rBAnYOZgKHj9rJF45PHXpGYZUijlmpmjEH7XZoA7G)PEpJh(ChF83MsUAowiIkCLSjo)KK4C3WFJLnujJOjjrbjpftUk(z8R1POSSN8EMRWsU8KKOeI4HBktcH()9j))8QhzJcDIJLQJLP(ildtllt8O4DFYuNEJkSBe)O)X53DxgkNEl8vUMv5TLuNRYE(M8OWy0c3ZVA(PtNDCXF6Ajp1cz)jhpB(XxIhUwL80KI)ePJN9B89s(r59CDl1UwET1WRlN(1VnN0oXG8t5Rw4YUqbjEjkYlp8NOIBz(5xWWXsCop1l3BH70zF74lNsWQLjXFdfE)kshG22YTTc(jvrveBhp8Ov)uIYbn6GNYNDQg(yvh(gA9hZ0y61vQU(zEPpGf3g3qNeDitJvxz)GRMYpqt0Mqv3PQyYRZGNIke8xMeT5XySsilCXcO3Dy8YOnbO5fiXc)cfvi6J8OlVcRaT7hkPc(9Wa8GcUg(zScZyVhXdMtsIZ28ik7LB9IdE52l9wgI1Pv0dTT(x1KynBQWZACzJXDTg4)n(VMIMIFfKAg7MpjL(coo6NxDYnxerXv6JApuSBO1uXo(f4ZFB(1E9Jl)RsefyccvWOmf7hD(3NvRfmHATAHB9Eqlr9qyH5)eLqYuj0lnqBVrfr1ae6qe4BW4kTtXDPeXn3B5dzSN4U0vMrl726PzRQDzfuUQgPAQ6qRulpf6BGVXx9ozdvJ4VKSQhFtLPzrJ49rPifRqvk4KQG3Ap0qwYPNIfdly0lsYX4kkFPGgsRMAivggfKk7JcsFofJQCQj0RPKSQY2I1aEb7sDN86gvy6g1AORsPvD0vAmZlRMvneIewHYn)91dXg6gL45Pm)ffvt3UMZBMqEPJ9szL7MhdVhBSefC2MO8q8BK4Uu4JO0AouJfMJcZY36onUc808NxJF0Rd)fcRLNvFlB9tdIqvQVfOEHo5pz6OWpEAJ7ncqz4oDpQRAu2a)6Ue5f88uSQSh99OSlNo3IHVkLMIGc27Po1B2unPsLYNtS1nSvmgzG9fBKITPgXtmtAxEDLIezHnH4UX4QrozCi92oAoPxMuWGnP0M6x2KNq(9dHXb4(BmM2aF(Kg2Pw2CBCjYvBffknhwmoG7d9YXkqwX6F4htWUgT8HTvA)gJhQgdYWHEJMjruLilvmtKgnBzJEc6nBXguBAVfgvXJKwAQw2662wJmXJLmFQTlhPt36zDdXNr82n8jfInirAtnhKuTg12GKEj9Csk6F3GIx(mvVPPeKIEHvHlFigrusOXp4UtiJCZNIIVN4IHQYUh1vy3Y3xHWtoYBjrIv(4(SfZC2TeGuVEi3eVHarbaIyJtdXgj9J0NKyvVP9iE)huQ0jkqKL9yCINKjulyH5dYKcRxODpbqRoCVRpta8tVMza63M3HVYza2bQPiyO7QPxGDFpoVCQkeZQ4zHGT2rnNvnZjQ(aVukos906hnEKNLeW)eXtCAfknmN63EJclkmXkBHdv4oK7K2OljGQ(BJ6VhQdee76ZOnVkgZVWndCnpinzD5VR8MMk(w6WKArJKtYWGvNQlzUQWbqndz901AuCx3VOsWtGkF2IXDFwTWNWsFePYU3vRIq8l9hIUsl2JIBphxPGHf5pov7ZkFpwB9fT0j6gEP)fAtBH70jNpJRNP54ttLKDQcH0rquxfhShDfLYafpRcN4lVk)7(j2mg10l8Y6OIYusFuzKIH()jbRZL9QWTV8neh(MJ1HTjTWDWPVC74iV4hy9(xZn9CYVlQmm3O3KHO(mYAuJBh5OVzMoaIrkmFPb8fWxaFnu8fMOubIcikGOgqIkRWxqGSEljRubXj)3mYQwKiTeIE8)BKvdzs5uZUe1FLeKmyuKA6G9BFWAVily2varbe1qsuW8PaIciQHIOkIyb1bqY)GsxLvRDVs07gbf3DbbOmCxjz52ibAFACrG293JDAqdeuHpU8TXEpGqR)cj6N5xsUBAC1X3004SWae3Av2e66uaAf3cg3K)KUmh8SsT9iW23DDexMusZvgrCPfex5yHyv3KtewZ2DHyIXcxeBBSyo)MB2n4x1xX)DYl6PQnbIi5u2WBVlP(aL4AIWxQMnJgRzDoD9H6qKxCfLe0viFpDSxlmtlbuufOsGkbQ8dgvQdujqLav(XHkztqC7QVH)PMLbeAZoN2OomTryAJ9BAJJNC0z3mXllNTZjHWBcufqvVfufeItGQaQAiPQ8TFPyGrlaVa8cmAbu17kvPdyv)WQDh3Ijx5s)I46dur)2RgmIACpjQX7jrPR2frPB()2(CuZ(WzFos(ovKsuLFXKdlrzyRnSeL5RCRy2nr910WaTtPPed6viYKfKLjyWc2gXW2iEa3gXfrExT2xbJwTDymm3ly3B9HBUx3rKMltyoND8rtV6Sd8njPfGzGTnW22aABdcVby4cmC9MB4c2MgaMby2BoM5ayg4Fi4F4a6FienrGOaIAijkBGOaIciQHmX5aZUcqkaPgsKAequarbe1qAKsbqkaPaKAirkyXRaKcqQHePmaIcikGOgiIsmluv7SVZVr6qOsyTMiUC6Rphalk1tTc7zATO900rhsi85cd55BI(KH)P9wJGER9O36piRTS7SEXBygCrYPBcKexUEx2thIm7Y170cVyYoHpNTWrJCut3PBL9nzUiDdkiMHxe18lMtxAKeAKL7G6Grh(eSKjOyBpuSXIUp0D13UlP2bih1zgoo664)tv3q3s1MDuNrooAnDgHVSMLUJUT9ihJIJJ2YdnRAaMVO5c8tgFZkMookMAkgMoA073OuFF6WycXNZes6RWeYx8XEHI74q1omRAY27YmIzpnJyOl5WdZXUOorpnQuSTm600slhVKsAU1TG0MDM26svRgLEngF6I02wfShjAdQHE5MZnHZCJOw)sLakMYvO3FdrvCD7MN6ANYPBlXLkzgHeTKw7i2QDDdeO(0e8K0Q7ZJOBq(7qVGfOfDp0IAa9w7rV1Fq2vMhmCeSsm(vyL4eJrgMQAJ0mmS1uvX2Xkngj9ux381znXnzt0l3MC3l3MVc9YTNKG1uu)SIUpZszC)hPlMyrhwx05mTOQAOQ48UoRfrjk)6NYU7vmM4SBiES5YcitdlhsDXV0AYyztEH0JoCtErZ6TAYl7EU68kHMF10BCzhuIKd(8ByoiYRcZVhUgCIPIJLbgE0T0TnuuTymL40CK)YkDlvb0OUhAuDGER9zopAq3vFp6uHv5bwLhyvEg4v5rZwPCnEQDiP(r(aO7v91y9HNk35382EJGYKj)q(vb(k(8iLtHnqHH8dfuqJMigkAg4G)uPdWmaZ(ldZ0amdWmaZElXmXDoeZbsU1drSokUadsbSbyBBK8tuAAya6RywBnrQSmcsDVPnedp470o2qEClBgGT(ffuXL0uiudDebu1xFeq97tmaLVfFUwE4l(DZS4qBRKwF20gDhf1Efv0ETucsp7EKfx723Bl9yJC0YQcij8(7E9Ka(9qIFBsH7ytxTJ9qeWVhW8RgWVG9xGFpy5xlGFb7Va)EWYV6a)c2Fb(9qKFBE61QQOdPnFiTOchzzVbzaviLiaefquqQ7gikGO(OsuqofgikGOgsIQAtNcBbvyt7aBAhylOcygGzWwqfWmaZamBy2cQVlBbgzP9Ld7LGRL1xRX6W1V06IK1HPJ8yqpsam9k3USFR0ER5AGoxYlFUfJIp70iljWO(UNdySKOBs6c01z7RFPXTkZaIla7Utmua)c8lWVhK8lSfyo82cmTZzs50F0rc0b2cmh6BbgiRBal7bSShd1YEGlRLfK0nGyebXicwXdaZamdwXdaZamdWSd8v8aI4c8rhbrCzq(ObHKMdWVa)cF0Va)c8lWVVZF0VqgsgMElm9wiyTaMbygeSwaZamdWmiyTqgEdYWBqWEGG1c8lWVqWAb(f4xGF)aeSwlZ)McwB7NcHW0BLn92pghRKIZmu(CxfME5qoZ1gtlw2gCFppbq)BoyTaMby2FoM9FS3DsYjqiuaa07KTtzBmBZE3LkNbZ9VsQSIa00OfO0X3rqkET8h4Z9NzBWmmdZ6jZmlrmlck(C7VqF)yeeu9iiOCi6X3OCZse(LFF687e)YV87A0V5EoD2650XegXegP1dw9K6F4X1HV4lpUoefrnQIAKRrpzrwRxzj6kIIO8yLsue1GorutlYEvnQALemofLnOzTZLZ3Lt)FMmL)iRaWSzhVUM0oFlFFU(2YUQu4xIyrRdjSnPGgbzTpSksHPspsoxBpApxdxxAAQpxE6ZTLpUaxZuPL)(v9k7i7LlDovsLu5aPYjQKkPYXrLPL5EZUdkZDXWgNe2OWgRlSXxp927FC6ZlF9ZpiLIJQOQoPkP4KQOQMQQv11s))t5eM)AG1ARng3yVB6kyM3J5GZnAWLODSht(IHsEtue1dtuopirruTsuzl5DWo2OCVg8ofeUfV0fJktoodtNC8Lh6kYG(8veiDtqy22xC3Z5KDpLkfPvRkxTMSAv3QvMBO22dtIrt(qKpKoLLrXPrvuLC3tvu1iRQFpl4(JoliFXxolivrvolivrvpNNfCZU9AP37aVuwSNGYITyBs5VWymgRPgtsmOkQQdQ6IZfAcHmQHD1YNLJXyq8ShZWmmZ8UcZWSvpZesgMHzDNzhXmmdZ6nZ2HzygM1BMDaZWmmR7XMj4moJZ6UZEzTYSVBVZSEBBCGaW)IcGef11J(iPBbACmI9UT9fx4eRuluL4az62K)97Wdjrsrj7C4DRrNxcsKO4XW5BoOyermdXSti3z4s6JCgYzhFoZd5mKZqo7yZzueZqmdXS)lpMMIF9h9e7)t3)r8yOWAUgpjkSpjkCAi064PW9XrH(xbkhhpfFzVMMTpXg0p4j0(UvP9fMQ)ZmIx6jsHtI1(yQWMATpykADsA46aqPhJvV)NsmPiQIOkIQNcOAaIQ)5IQVQd9jev)Fcvdruf9QIEvpfqvFFKvrwfz1tcwfrvevru9KavjiRISkYQNcSkfrvevru9uavrVQ4AaJRb8PreWEiRIUvr3QNcSAcIQiQIO6PaQgHOkIQiQ(BoQ64aZ0JGFauXnKpEUt8E)V4c(rXh5lKVWV(IirHe1jdrTfpVmrYcjRJazHzxHefsu4N4EKOqI6u4BfWByhT4gbpIRHV9kLJlGVEt)ESw99HywYHwyBRfaxBP71xrFTLX3MCEPlCV9A03)RfWEf73)7JY(ft0Xlt63Q)tlqQePsKkV(3SVaaivIujsLxFSFn3IlvYv6gTEz7SGUD19FSk43Sv5mop(Pn3(dExbKEqLMVSGFZn)mRSeu9fIpvy8FwnxeVygdskGxSB5TCJyoHFfPot7zfrz1NaQkAlP6fjukXJsiKqpppknzXDNfg0inQEW6k7mIQ6RvXCSBLREQwzATT3P1SM85KLU9iZCkv0r2VXXTn9EFnbPvnx3IU3VeYz(HApF7YPpJOOHOQA2qEv3wQsfy(SDxZUG9TQlo)QPY0mf9qRlYPMYn)ITECEjy6Ld2ZgF1NNi134kM62KbZbf1xsmFOT0bIC6MMvEny3ycXtEb1sBmH6zMiQxIGC2D3DCAWL(Ue40YLVTfslKqVZ0bE47F48Xz(9ai6ktTGb)xdl0Joylaq)8D2RQ7uU4IiIFuCqqCuAyAukrqTrc993gF49svVtAbh9Pf3lJTFkXVB7cUu57KomqjDh)mB1(xgY4m(eODvrvyHfgytaXIR8JS8Vx3)TcUjW2LflViN9CLk4)KN9RmX5s9AG5gaokvHwmS5kxbezbif5S3o2gjkoA8L8lStwDD5OQU)tDaY6yBGTO9T7xRxU9IesuinWJMa)KgeTxhBVk)AKdYVMtLZEudFRuSVLQF7yBFr(5CmhCqi8zUyyItZiudBFhQreJogZ0VqhKBFi1bdUUDq1YLyNwi6KDpVkUWw0l0FyL5p8Jm2woyYZn85hwEF(TZxdcG1qPL5CLZt6tnOyGGAnmW)6Kbx(XrcrYUhNUzBUuGC(KXW1w(OmjLcqOwKVLJKtia0KeaZeqREVinYZVC45JhFo8a3TM9P87ZzYaVRdKDMOHLkA83mWTf7wLnD52TQCk1MDvwuKpbiKxm7BSD5ZLJUlZ)opLurbHWT5d0gdfVax0U0BDP11fHBfNLRaApSa200sQdbREL)DMaxVz56w1toEezUvHaexzb3tUn1jYy)(SkHkCzrTwxMufbSOgqP1AHCL(WuAJ7c4VjX(PAximjnXOarEbr61qusAkXOaK0yT77tcItsc1BZyACqI(fcdJOXM9QyIEBK6f7P3gWdeQ3RahfPMLikKq81QIaFc133OrJsH8M0h6Wyv)Vt9tPgd9KKe92io242qlKsmlFCSVUOjagv(6LimnouVa(WWmo1Spr1(BMl7hPcaI)MDaYtS8rZndjfmLjsNnsEOowSbk)SZhD1KXdU(R8hgefDEN4UUtSxh3XNgL05TId66wED07ykRDv7UFnD8N0(DNBqFLWAKs4WTO9CJ3wMMHWl5rjX7aGq)Siqsn7jEsZrGP(hR9RikVOKJZUz33nnqYKrHnlJny3Q8nat(WdzfYibk2TLLvwzdNd6ZnwBn18lpvRPlxTQojPLLFpJnA5w2qPnvTz1kzYtggQesHpWVfPrtvtxHpCGqgZugtMBpaG2M3dxwmDd4aZQvVr1Qu7wv1o84rVRyZVQJYkSAimx8thTz1WGvvs39R6PjBj0YBvX1uQIFww(ARId2oS(vLQ8nbtq7E0Ay9iF0ooJ74nBvvSX8vAKxwo7mrUl4uKu9YnnFtJjEz45ZLzxUMpy4ACI4tHjqXVhOAjHiSIyfERZRc42RzM959T7eKrku1HfiUQ6d5v6dc3fFOyZnll6NDQ2TFYNUFhC2EH0fJ91gYasgmF(Gr)fpGK2cWNn0PAeHhZ(ZfnUZ7PRuntDm7jtoOEIst6DQJ4)AejGrrQAtcOVdx6F)eOElfQG9etTkJl8i5MNRszcIs9lDiLGecepM5gEirTHhcvB4Hq1gEiCrh70hahz5AltD3VLKE(ND7aEATjvBXK(E)PXGcpC52r)AR3W77klfQfrRj)mdpGF6QplVF7qCbHSQkiE7BRWiMD4bYR5XP6n2WxejOUAYRpO7nMsCFY4QSOk(5FFX3MkCp9nHl7HsRJ8vHCOYe1(20nU)pkT)nHuh7imR9M0nlUiIMMcr5fgss9GamJKlFhFvlIIt8ts9tIdG43iPv3PSRNH1oL2dBxozLibpxDB9Rw7Zhn3T17mSqZ0U7AElPVnuK9EtRJC379Guj0R9RmmUdLY60u1ZRp0XcyzSDPOgBtTW9MFvxQHSfl(3p]==] },
}

local function PresetStr(key)
    for _, p in ipairs(PRESETS) do if p.key == key then return p.str end end
end
function ns.PresetString(key) return PresetStr(key) end
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

function ns.SetDamageMeterProvider(provider)
    E.db.thingsUI.damageMeter = E.db.thingsUI.damageMeter or {}
    E.db.thingsUI.damageMeter.provider = provider
    local hasDetails = IsInstalled("Details")
    if provider == "TUI" then
        if hasDetails then C_AddOns.DisableAddOn("Details", E.myguid) end
        pcall(SetCVar, "damageMeterEnabled", "0")
        print("|cFF8080FFthingsUI|r - Mini Meter selected" .. (hasDetails and ", Details! disabled." or ".") .. " |cFFFFFF00Reload required.|r")
    else
        if hasDetails then C_AddOns.EnableAddOn("Details", E.myguid) end
        print("|cFF8080FFthingsUI|r - Details! selected" .. (hasDetails and "." or " |cFFFF6060(not installed)|r.") .. " |cFFFFFF00Reload required.|r")
    end
    if TUI.UpdateTUIMeter then TUI:UpdateTUIMeter() end
    if ns.MoverSync and ns.MoverSync.Queue then ns.MoverSync.Queue() end
end

function ns.GetDamageMeterProvider()
    local dm = E.db.thingsUI and E.db.thingsUI.damageMeter
    return (dm and dm.provider) or "DETAILS"
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
    tutorialImagePoint = { 0, 208 },  -- right under the SubTitle
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
            local skins = E.private and E.private.skins and E.private.skins.blizzard
            local skinOn = skins and skins.cooldownManager
            local gdb = _G.thingsUIGlobalDB
            local guid = UnitGUID and UnitGUID("player")
            local autoWill = E.db.thingsUI and E.db.thingsUI.cdmIcons and E.db.thingsUI.cdmIcons.autoEnableCDM
                and not (gdb and gdb.cdmSkinEnabled and guid and gdb.cdmSkinEnabled[guid])
            f.SubTitle:SetText("Cooldown Manager Skins")
            f.Desc1:SetText("ElvUI skins the Blizzard Cooldown Manager (Essential / Utility / Buffs). The toggle lives in ElvUI's |cFFFFFFFFprivate settings|r (per character), so it is NOT part of an imported profile.")
            if skinOn then
                f.Desc2:SetText("Status: |cFF40FF40Enabled|r")
            elseif autoWill then
                f.Desc2:SetText("Status: |cFFFF6060Disabled|r - Auto Enable Cooldown Manager turns it on at the reload after finishing.")
            else
                f.Desc2:SetText("Status: |cFFFF6060Disabled|r - enable it below.")
            end
            local nextOpt = 1
            if not skinOn then
                f.Option1:Show(); f.Option1:Enable(); f.Option1:SetText("Enable CDM Skin")
                f.Option1:SetScript("OnClick", function()
                    if skins then skins.cooldownManager = true end
                    StepDone("CDM skin enabled - applies on the reload after finishing")
                end)
                nextOpt = 2
            end
            if IsEnabled("BetterCooldownManager") then
                f.Desc3:SetText("|cFFFF6B6BBetterCooldownManager is enabled and conflicts with the styling - disable it below.|r")
                local opt = f["Option" .. nextOpt]
                opt:Show(); opt:Enable(); opt:SetText("Disable BetterCooldownManager")
                opt:SetScript("OnClick", function() ns.DisableBCM(); StepDone("BetterCooldownManager disabled - reload after finishing") end)
            else
                f.Desc3:SetText("")
            end
        end,
        -- 6: Damage meter choice
        function()
            local f = PIF()
            local hasDetails = IsInstalled("Details")
            f.SubTitle:SetText("Damage Meter")
            f.Desc1:SetText("Pick your damage meter. Details! gets anchored inside ElvUI's right chat panel; |cFF8080FFMini Meter|r uses Blizzard's built-in meter data with thingsUI's look, filling the same panel.")
            f.Desc2:SetText(hasDetails and "Picking the Mini Meter disables the Details! addon." or "|cFFFF6060Details! is not installed - Mini Meter is your option.|r")
            f.Desc3:SetText("")
            f.Option1:Show(); f.Option1:SetText("Details! + Right Chat")
            if hasDetails then
                f.Option1:Enable()
                f.Option1:SetScript("OnClick", function()
                    ns.SetDamageMeterProvider("DETAILS")
                    E.db.thingsUI.rightChatAsBackground = true
                    if TUI.ApplyDetailsRightChatAnchor then TUI:ApplyDetailsRightChatAnchor() end
                    StepDone("Details! anchored to right chat")
                end)
            else
                f.Option1:Disable()
                f.Option1:SetScript("OnClick", nil)
            end
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("|cFF8080FFMini Meter|r")
            f.Option2:SetScript("OnClick", function()
                ns.SetDamageMeterProvider("TUI")
                E.db.thingsUI.rightChatAsBackground = true
                StepDone("Ingame Mini Meter OK - reload after finishing")
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
        "Welcome", "Scale", "Coloring", "Positions", "CDM Skins", "Damage Meter", "ActionBars", "Unit Frames", "Finished",
    },
    StepTitlesColorSelected = { 0.5, 0.5, 1 },
}

local function TweakLayout()
    local f = PIF()
    if not f then return end
    if not f._tuiHideHook then
        f._tuiHideHook = true
        f:HookScript("OnHide", function()
            if f._tuiDescShift then
                f._tuiDescShift = nil
                f.Desc1:ClearAllPoints()
                f.Desc1:SetPoint("TOPLEFT", 20, -75)
            end
        end)
    end
    if not f._tuiDescShift then
        f._tuiDescShift = true
        f.Desc1:ClearAllPoints()
        f.Desc1:SetPoint("TOPLEFT", 20, -128)
    end
end

do
    local pages = ns.installTable.Pages
    for i, fn in ipairs(pages) do
        pages[i] = function() TweakLayout(); fn() end
    end
end

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
