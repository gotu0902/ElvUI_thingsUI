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
    { key = "NHT", label = "|cFFff0000NHT|r ", str = [==[!TUI1!S35wxnkYwC8poNzEONfuC)rJM0M1OepH4P7EEGwiPuzzeCiK225b)SFQQas4svartYKyVxZAn2IKIIQ2)(VVqrfxz3jUotxUij6XphhT8Pf0Fpe)ZKHN5All56Cx(rTzN6TZX4KGW76ffpdh7Keh9a2T36JFPx8d4y6rUpyg(VWXrNEVx8D4f0dfeoD(Yz4jXbHpGtw46764fo9(O4bXEpIDD6p)hxp47xn37fst483l9MhK8IZuV5yxBP)qp)SVkkimX1zYORUO)Gj5h9BJU92f4ex7pHCDwmn6j8iAxmTN7C38iFV5U2K)205Elw4ARqoRNWtDtO)0BkPVZowW0OqNG)HCfv0QD7YoU8QUw6rz3zZyhhh65phpJEeABZgmrAM0FeKGFK(7SlhE(80)n9)Y7BfojBKQmYcrpuHMKmUeTmzy4m8pDT1iFs6PPiz20PPKDAiZgpnv6PPPj34LuE1LuTPtdLExv6UKyOKoNFv0IGKGOqYKT9zRgiViDgVx)ZhspAcX(JzxgTmmzquys2apDYlkA(SONdZSboTV9K(JZoZvwaYRpVtJMhrTbCUZDGPUPfYYuxxsH8tDj3B)Kgzg3NyCX6W3h98P02HEhT6st6O)8Py8Ifp79s(5K20PNw6)U(zYAGSEzVrtMm6YXd)85tk)rgTmzEqiXYF01tUyOD)cx3A)Pegl(CY9UoRAP5lFmKykBKzuJzgCF5KXJhoACtgDoNn(AcG3Szzkwngp3lj4h4s3kPCxidApnkCXYhXlE9gVWzVEZyck5rAM8P2vtkOvh6RRiv5Qe2QPlp2SymL7r0jpYpnztvYR7AFTW8D5Mzyi74smd23NSLFfvNsZLCe0QP8Kj3GYKBOAmzaFfLhQTvMIIFvDOksCiH3WCLGmKfnvBllBkPy2g1ZShqA6nAtzGeFvmvv0v74vXuCZy0Q8KSgYuVD1jsZklPi8cPlROO3PURCQw47Rv46dOutzyO24WNoZsxxdHKBxb3s2Q5wJ50qZYqRdEGmnnLAB82wZ0YSXRObRTK0SuBZlvtEtOEHrDY9Ha9AbhELQuCASeS)FUwunpn5NuB(Be6ZQqxwD9rlFMI8sK(NkPWkWLzvxzvC)L(hw1qsDYXfhnYcUTs9AWlKkujhyNFnRhkwmrNyP3Q9RSKvlbQKsd6QgkADsXOfhRe7xKSUzRWGLHQoQ9y2i2msDscY58tU8eBXdxsMiJ2vfKTmZueBDC4Yt(C)gCOOIAva2wvtvP9asrkAQAsTRuPPO2UsLmXGqZQDrufnfzLonWF14H9DMiCKq1qZuR1XDT2DxrMBqn7irjVlDw)tMC(FAZipH9ltdjJ2LS1qkkT37LLA2jbBmLCfTA3Ix1IOt260iPTuv6KtI()Vr)zdYikgQiu7Jdk6kwYDlwaI(WfJo9pBIevBVPiNMQHr3iXZ6F5i72KlTmjUF7a)RBiB2PR6vNCXjNnuSIJEZ0yMVEvPMVCPqReQDdhIh2Mb7ujhlZwnu1B2K3KzqiBQ1nH5gtYYgHm7q62YiDI)oJob)eBHgm(ig7MkT71KeaTuR8fT1unKAF6drVQTZyiKMKrNgthp6Zxl25JcTF1U0gYWO9bcl9Ug7o3eLNm6QSKeRvSO08MpdFloCb5d86nNEgj75FlTUxVEZ1d(9Y52VnsrMgiO4ATrNdAkn5QLIJa4BwIYliTqmEijNwAZvym95yVNoliMmCm6l2L6INYkkPRtAQWFjygjesBsElvQzezC(9eXp)k0umMF)cX8hxjM)cxkZUueQMARVvku7ni((sbUlQav1Qx2Bk((AdIfIU)6RALesn87TKCnF9Mp96nJdU7(K053ZXS)nXDB9Yej1ccSAuLbazabFequvtQuhiFH1eED3RAvORwVlPcfGPHQeKvfbulfJBLEGuAAUkvW5ENm2P)KRV67mEyDYuj8QDuZfBiT6TBub0fKtxzLpFX5TxRmAu)17gbP0jRTMEK5gPhPTFRar5tQ1QnGqBb1OdMQn0KEuX6xxWpCMY0VnXl8HF)9Rl1rxZOoll1B)klXr2rLBnVlj308t6zDuqc0m2mHNoOKvx(tSWjn4WTGSJFXpMFv1gFb(WKsTusTBO983USub7HUilP0QSuXHV3xunfPhrbR81QFO1g1DuM0Nw9vsItAkw6QAK8drM0QVQvOBM(m)s8M(WIvDsT8Jis1PwyFAfLY8Z)4f7VRBWkpkr2XlnCS6mtBCR8dvqyFGQgIMtOKULHoslTOYwfe7xxA52Vhe)xlREx)rpksynxu9e)OCb1xVHA4VyVfMN0MiN6x(56VLvx30G6Q)G(u16Kgxjby)k31CccIJC8gUIjk9SkfiL3OoR(hbD2dS0rB5KEBpUPpGPJwm8V1zJEb(29xYOOdevkoQqwVXug3urOs9T)1eIiTX3Fm4UyVe8SlxopjG0hOrXg8ioU8IHZW1zEWIKvlfos)65jV8ePjFk4N45UoPDJ8aBgoBotlt4DEsmX3Er4OYOUCXzxnsRodVGCZ5XcQ2o1XWZJXEZEziH8F03lPsUSzlkTzlJzFMtwMeXSMwgqUnzxrAlisGSG0rZCeBfc6qN1wnxDiuqo9dGcY5VFuaheh8pVEZ)DP3mYmT3R3mzYQ1Z2ztOgY0l8dbHZiwWe3y8czQrF1OCZ9bX4)EjoC6lmznnXmaATzhbxLspXlWH3r9AkxKqQwLM8bewlFFW0hcXzlFQY8IFnEj7Q8L7XKCo9MsnvRWmPl9QNTPpjNwPhU((PFOIdBvzlgYjvBSNhIqBQQ996fqqUAO9CzX8bnQ2mvRkBbFwX7qNHso2tTyUThRsvkyVVRsL)wUkvP0iD(QvA86HxrIQnC1JBI66lWBEpVu)tRZ3G5DMmJN2JPw7(zNd5NS)klDYVv7cDz0SIxhNGW7XXbjSGCRDYvn5sp3SqMO(G5ouKdkRNfuPDRPpqrJWzfn8zR0BQ5(FKhivET0Kxf0HnBKznVMj02J0GZIJEk)3DyPpZatkjKh3KC2ir5iFVTMdP7ZIdePYBsQ0DE504twUGm9mHWBlJZEwBdjzdp3l8H0RZ6Rknk0VvTiavgJZh8kzUZ0KQ7iJn6ToStwZvRidNWUzCDgE6i7cJf1N2QlX2S(tbdh6CqEhp70Yx1SK5I(RfAVLAMtv3t8CDUS)zdVMKF6ZPjyHuYetpl3BsgvYmaYMx)RiI4CQzIFMbWgyprNakgwo93Z6VPX3SCb(uACNPTzpX0jfZuoUWS4kdl(aM1iMvQK(6R9BTFXmHw5INo5tI1S13MSyfmVkNvvRyJWme4nd8MbEZ2LEZYQf2I8OktrosN9ZKevYnjlEJunfpUagjFmI9eTAl080ggMLNMVGY1gxOCT5zavd(KkMwNiGQAMB0FFy4IGz41LpABKc29fQDyDkJBs0fHKYRAQCt5YGmpaQE6Y1koEjfKQLuSsIp1jLYfARbiJ9NAmjVA621W6)znd886NOz(99Gg1KfpEvrGKhOwnP88pAJ3pvR1zTIIW3Vuf5KCdOhW4NoHMuxYy6FMjruxExOZrkQkdOkGQaQEmGQkaQcOkGQh4OAAsNRQRkBf7QbLBfsqfsqfsqfCLcUsbxPqcQaQcO6hpuvhqvavbu9yavnaufqvavp6QLu2gNNOsjblPiyjfblPOD(skshWmaZamdw5EaMby2rpMj)beZ6hg7DhU8wCDryRhaBBfyJnKZELxPBB3On)Xsw2U(9twdO7yF6AAAkMsgk6YkU3(j6RE)24jvk2YBRYJMGBpGeb3E7A3EAaMbygGz7AmZaWmaZamBNNeNmWzaNbC2UMZSamdWmaZ25UZGA)dCgWz7Eotc4mGZaoBxZzQaMbygGz7sm7G)D8JZUwAZRYzolE0dOf6C9fPCTLk7gSKNBEboxDfnxDbpVjieN1(87CboxyvnxyToZBLTVPlR5MxK072f98xfilwArTZ3dw0pWXXeB0pt3lBP6WLwL5hRV4Fa)c8lWVhVBxna)c8lWVVT37iD1JH37OYzX8XCpS5nSpQ8l42AtPcDSd3vBARAdB3DmCzaZamdWSDnMHamdWmaZ2Lyg3I1wluzEFLBv72Puce8(evtTzdtPK3xdKV5ukldA8YMuyy6B5mhFJ5jwpRtbzj3HVR44Lfj3DodoFvlvo97sFDHXnFXbD75IvE7QquUCTVNvWpfYYdVnrU0zZI1oH)3rIvDgvtTsK(dh72U8Dk166YcOkGQaQEOJQkaQcOkGQh4OkVDmCLkLBvgk3kKGkKG6(ToqW28eSO9GfT3VkBZtBxVzJdEs8UpZ2f1KnbhAC2qAKmS(32)2wyZOzp)agH3IyWLh4YBN7Yd2INamdWmylEcWmaZGT4jaZamdWSFnx9NJ9Eadfk5F1cLOPzGqqPsGnckWPh40d2iOaod4myJGc4mGZaod2iOamdWSJ8nckze8LD7h3VSB5VbtiEHndFz3Ei)9sTfGQaQcO6XaQwF)DI7i(((LiI7EFZ2HC3dVercGXAt21jrE8kNz5gEhR6W7wKGxfMAVXmTJ1IEJKwlE0P3BTQO0gS)pTFEvJk67Ihcx3xwhFjR4QTwzwTr(vdC1cUAbxThdUALLbwfyvGvpky1sOAV3FyX92ZHfpj4oC8)zXR3myz8l1wAon8A23lVAOSRHRT22oI5vlzfnKSXXza0Cr)ni85ETe(CrFcFacGUQ20wnc63)(RHb4wgCldULpgClRcOkGQaQEmGQiOWYqHLHclF0wy5SLsi4Rf81c(ApW91AcOkGQaQEmGQ6aQcOkGQh4OAPnZv27Plst7y47ol4ncaEJa(i)I3aBMRaMby2VkBMRaMbygSxaTnXS)p7D)0BAddgga)t0K8)JZoMjH0ovKkAt7YkPf6aPUYu6QQ2f(SVabbjo2bhibIBFUuvK6Lc5xEnopV(fmdmdNtRGzGzGz4CAfmdmdNtRGzGzGzyiAaNbND5DgobwbZaZWjWkCgCgobwHZGZGZWjWkygy2q7eyfhaRi6Yi6Yb4XxdOkOkOAWCaScQcQcQoGBiiErdbPrdbHVGk(cQOHGAbZ8AAQcM13Jn1oAkPw1q(pMuBTGoHPyB3oNuzdXPwS5hlLi03s)9FwMT8H1tNS61hw4E2eNCfNnXDVOmUe0snRnxQmsZusbNi05)uWv6F(4NKIoRg2(d4vUi(WAQ(HpdLz3LToPLUu7AEB3XPlhNX3xvUmUJkeM4SX7(ufQ3)(k2AOGikigIfe1GzGzGz9nZKGzGzGz9nZIaZaZaZ6BMD8VB2MlggD3K0SFn3tQv8KTUUpxGBxKoB1BRN(9vzZ(86PJtx(8hLDCXVhvW23ahPIekPshR1SyjTyBx4hE(ND12Ui1X1Sj1HnNCZ4AK78FcbDX(MCc7ru7EWcMBKsf6fK9MeklIYIbzzrcCgCgCwV7mgCgCgCwF7mbygygywFYmZEtIE0MtYo)6IWuBBmJ1WC0kig0y1YA7zLzAlzV90M0UoJ0T9Gwxnc6Ldr)XZkTT4Wxk)0Us08Lz0H51WpZm)0hFE710UlzKB9MJbFJD8qmOkOkOAiq1TnXGxnRrTpLU0TTuR5RJR0dEbpGBqjZfxoy7pPYvNmTPJzAQRB35QT6mFT3niNdQkrvvuvfvvdHQQukSkSkSAqy1kunPzQweHGXpL(V5z39L0x(BsAM146SRBuAlDhjvsQmsXiSyTueX2KGKOISLWzSicrt5CUk)pzx2sofIpE1BZZwp9Rp)4RVS5FYYj55OIpXFXp5MXfVpSN8w37395AHsiQRWsOtAAj0S6xSvp5nL0DY1Oh)fHtp(78EMLVNO0(n889g3JesgLPOevCoLK5xtTxrrXugJK7ifNK)lBtOL8GISKxidS77u(ff4rbEuGFiuGxaQcQcQgcu9k(mEp3DEE3AQ3fq(BxSC(tZA3cR7C(EyD1rF03x635hCwETOAk5CwvDR3U6Dz(f1DrDxu3DGx3vdQcQcQgcuncufufuDGt1kNMSBZooLimonz19YPj7)zVZLEBByGGW)LOe1lFS(IrbksbsqlqVeyLe1uHKixqf7d5G)Txj3hrMIKIYuuL0EUuGc0hgr(BNLR4mlSuaSuaSuGRNMSAhZLxki0W5APxNfZ9YgsRffZIQfXJqNuAG4JPjluZGA2zTFVdGCgKZGCMTLZYaMbmdyMTXSyGzaZaMzBmlfygWmGz2gZ0nly5DtYSHCMoqKpY2u99TSjmiyZugeSjJbppHZM7qJkz5hUwVOGnyrijt41P7OcQlfqCDl3CNg1ZuKgSjPliXz0O42OVLehiknyVtEAWgy)LOJmVC4ozalKdHC4zTCyi4mWzGZSoNraNbodCMT5SiGzaZaMztmB8za7CNjD83VyZVZZJY6vt39Gw6fogoc0lDeyV71UyHjjxFFb3JDP3f)tndyTbQkYHcB2vWyni2QMYu)SvL5VuMx4pbj4xVhV9zpreQGNRkmWHg2wOh1Oi7eLFF75(jQWYqCLc0Yya8K0BkM34SBTHEvGgVngeS315SrIO6T)RA8WbdRF6ZOB2Y2vUl)52eUQ(1YQ7FTE0oX)3TnEOMXTxfznN5NeqB)tCwynj1Q1dAmjTiAN2Ss9kgoPgtskSFkUim2FdAJgoP6TYIh2V(6IhlQk(ZNzhfWddZIcVWtFd9JxCNU)7bjBztMqzICyR03iahvghvghv2hoQCGWDWGW2deLV(A4n63d60zUv8v5p3()W97xVABo7HY8(Rn63)sUOOM9iz6ydKPjQLPdOPKmv60hbRMOCRDiMMssIIA(L4eAwmjmQnQsJE)5RWqoDXTQ2ubC5ABxfGmLLqwQ9B6qw1EjhdVBUlp22XvxFrzZ6eLLefkU3FihFBO3KdVgwNVl)5d)y9Qi3nSpmTn9B2w18pAz1Jn9PVjNzw)5u7fnEHX00flMfYxNZRPAyo6hAfcu)nuIVJU(iMIMoc7NagpVzMNGc29jz6002EK)c8lZzpv)uPlFs8aCsCCs85(K4E8El9tBRYz7xVSi)fxv)oKerssCQg3L8wYgQH8abZiF4kb9(M(OhFUQUZLLvyZql6gf(xtZe07RYhACM3IPUHPUHPU5ctDlZFB1(lS6MhR7x)1Yh3WC1(TPPP4vFHgUN)gUt84ZqxWQlyp5QnBhtOTRAmmQmmQmdgvwGXy(rPR7HpXHXuU01L6IPR706)E30rh(TX7NRmk8iBCyXikCi)1mX5riWmGzaZSnMfcmdygWmBIz8wpmCUUJw39)DTSmWnYclLfl48bf8PB73HoZyH)iJk8b2eCtQCJRtjqvGQavnbvPavbQcu1Xr1Jg3kT93MgWnT1iSlZW2FbB)LlYDzgWmGzNZyg2LzaZaMz)Dz2ziM1(3QUEB9(138sE9pMWKYxj11MJ(xMuxhFbKrYsgmx81L0gtqlQvA4BDyCezLVFS8ZG(h0)oN1)IbMbmZCm7xS35tVTjquq8VoThQelSGXxPP9uRALsuLpA7eQmQjMkBSI6f)zVoPjuy)h7ZMfZgp3JJsS3FmpdVzgGzEr5NbmdygAMAWzGZaNDkC2uGzaZaM5C5SaWzGZaN5CodpSnWzGZCoNXbMbmdyMlXmPYllanIeAeP2PnIyk0ytri19AnFr3jsIBnE)1isOrZa)c(1F53iWVGFR9mt3XaLk6vg7b0wzrzk0h8Bm4xWVq)1B1FppvsgayaWaG7ha2)43RF8WX7NlHOd)pw8R8tSiGJDxpgKeOVaYg5eVYaw2bva(r1yWJFCFwVI79AnbZcHKnKSHKT3kzZvgWokZ1AJbSJQxX4OLbV7U817NFv(IQv002Z0uiJoQHrJd5rtgKlpinXI(JpzsDckP2rit3tu2YC4PrDCArNGo268GUce9uDxh12EpqtdVwJHAAi2tUqYGMoUp44(GpAVp4ta)c(fZK7TZKNc(f8l4xVLFta)c(f8RpYVYfhgliuikBtOgLTvf3xu9Nx)B9hf5pE4JERCnXnF77IwMiJwPR0Af7ZAX83uU72v7NxTkF)8pwU9HYT6JFSlods8ILiQTiH2Q48iJFmECquICsm)HqdMsyJGPewwBkbdoJr)lsY5c2B0IpNeeXzSP8PPXrbPrH0tWmLo8XQmk7FxLStJwOK6gv5IRbsD5fPXLeoaomijrplDe0P2J62gyGK91KQlWjYwh11moR5I7RGF)HzTfe)Az56Fw80b5HrgKLCXldYs4Pm5NQuc)TPm4YEug85zd9Yixc6Eq37TSUxkWmGzaZCnMfdmdygWmxJztaMbmdyMRXmMNDZsUEhUxjNH7vsSedYWTkP)VvjtHOhe9GONZf9cbNbodCMZ5SaWzGZaN5AoJdmdygWmxIzIPM7e7nWSDCPRCT8rUm2A8c6zyFSL3Z6U3Dz1MULA4tO4NV5A(2YEIKsre6gEV57sn2NzclxTn(q28YyBLlLB6)aXLR2WIVlTz9n9PGkJbiFYV5BKbDA24Pk5xDl8T(aiq1Rq8SvpyPckzpGK66)pxFor4MFctauLXF7SPUfbcebxe3gIfpGsjBbuXPnWyDU(FG8hHb61q8jnZqSmOuxtKOjMpUkF7EmJKF627l(9289ZF3x2TEXM3l94lmJOY5bcZzb(fpnMPlVVetWdFJRnhQasuDxcXJARozL2gbgN2x24u494o59HDcAkG(vBYx8WHVX4UnBRoLi97fmp0DyEu0tpnm961wmGv)I)MDoxhZFBLDh1mFo5jYnpaUXFv(CUbvpPZmZ(BvuLWIW3fdIJbXXG4J9bXBNZUz0cyG)2ExB7224ar)C2NYcjsDDFZk2PBbsCmACr3(stvTvQfQsCHK8M69H(TVCiPKiPiPLtCBUadu0KijEFoNz4qYHnUf(aQqwvCVFu4RoT8(S0)nR8pQ(5N)qA53L0jpeFCL8ivlZB1duRmogh7HgSJWEmWz14TNvhG5gg1lI89WCb2GIGJ2DW3W9f2Gvf)7Y5y7k8dicTNuvrWE5PfQNGFlQG(htHBrSjJ6CecBFrUXEHr(HrXboHXK(0BoXh3ZtAMQxAJcjjpA12j)2vBF59fFl)UF(zca8U)B7JEQ64bRv8qyxVRFicTNXRBRw)T7qCIgQqjzV4(YMkuj6i0TQ6prVtI7Zf(X9B66wflFMfcUFqHZ8DAqGgDI7oq((AX5CxTU4q4Co8VuNZfE05ChDo3tMZ5q7s9(ZxFZPmBGSBQ37zdShk4nVIKpoka6ue8E6wR8K9BTY)1orb9CCVINGGknOPPcBCIaXw0nzAA)ohDr3rx0D0fDVeCrx0XTL2XTL2XTL2l2TLg7KjDux7rDTh11(mwxRu86f)j(JkbbWtxL2)OfSy5TVTz3JNTmVgQTNVEX3GkswJ)0Hx2OwK2PX3h8StqXups(udkkjF2cOK76CJHNWAA97BPFB3q3F639X9i8plkikgfhfe4Gj)KDZ(G74UAsO0XrhY)UJcGgTqnPQ3zAOYQghAgBuFALg)ylXPqt(UnbQsURH9m7LQjxRcsdjcdoAghSSfuQK7dBlnTdXCqvGKhme)G(fsZBLf5HjrxU((6vJZljmxGUe(RMm(6)MjacsQIeBkNrEhyoLchrh65Kyww57i4v6DOf8a(ziIkfx0MFKAnaL2CZna8WeaOjTyVEuGijic8bI1edWfx3HJxoX1cCrwAvbAWsPi2WzyqdBYpDrwa2HSPhms7DZvOQnipsKIVvPz9YPkqeBsQwrAYqfN(iLitI6M5neX80G2qhOQwrC9bHwmhDiKWrTxmBt6StscmfziyR03ChjfxjJE3vtM)(zxdfjjzRi4RreDXDEABdlQvVtaisBGIxaa6R2esmIcJE(O06WPZsCLJELRLY1k0tz9G1di3Lcl96)RLj5pyaY2qxKwmzhVowJkozoIDGhnVdki1I6Y87(wwD1PJVGATOGavoyIlJ3)RmV5I4)2S1v5Sg)KPJjIofKXLI8ka2n113ZLqatPYULTZsUizY4Xtgdhf2ffBwMnlTQIpZVwRrVsO0sRjd0Rij8ks(p)TJoNyl)27sVnFX8vejNvKwb1cfonIysVUEt(Cwt6I8VcZ1K2wiwpdTUoQH9qdRoHwDcDMG0gecLvbpelPeiuAnJQDhFzHO2GCNAWOgUsnPh)zAlIonOgXEupzStCXUwNVs7Ktup53LK8mTOrEBzgxQbHdJI8fNEYuuakou(jo(Hi5N47h4j)ryxKhyYLWJ8WbyyrS6EuTorkxg)nCaDjcm0P4Pajiio6KQcyRlzXAY3F1KtVC64rV7JqId8m8cxhSH3qAcgtJ2CJdRMY4MqbrMsUxi24RccnwOgABGmx63PqK7vgt)HWVRDU18(6t5DTqF52oI9AHrMladcGkWw6ThcjVP563LLDLmykDt96RYQhTzz(AIe3D3LvW01vSPQoRSHScKKLho58hWCbMLUCzddF6cUwPs(TRrBq)6nq7h50MsrzhsDSiDBghnmxTosYEOsKwmBnH7nHXhjEBubzTNuxPy3IADuOQ3yler1rDA5xZQNt)Fn1JMXV6MVuFDLN3xsgiUPy99TJtonj700QALwqxMl3cezcgvL0EM55KYKHnIEffqg8SkkPavqKJ5Q7l2XSNCoRZh6wPmvn4x6kLVyfuJP)fyxaPId)oOAkVPJd571v5fKk1tPEhLR7nfR)cHfH)jZxZnnveh0C5j1uMYnYT7Axs0LZnprmZ7yaK7uSWjZ7H(TunSTSrW4jrG(VAcgKc1g9P5axX2kbW6KpEY7yALBhynrwpoutAEYdPMaXEKZUEgLctzyc9igMSPPqOQ1V3CRclIAm6CGw4ofjYHmf0cNaq(i4hGQUKU1iPfgV38ksY007AEXEp4Qu7aW8WSkoBjB2XmUL2QKButKRKyrWp)8vj276TtoPsP8J(rZMpygvzn2(qt3zLRVLhFz(YoedgcncENigXCCVKi1c6hi3QTc6zyVO7tok3izSPS)StcHze4h75GdJrrX0B()GNpDVgO0FHjz8IM)hlX)h6c8(Hig7V3(W(3r4JfjE1X()lNS3PJS3D4K9VcjPEcO63xsQNt9KVG5JEXAPYdN7cOMyBrgUdjPsE8jEdEBCEo3R(3SsAv)e7fkZyjtyBHCwa2b7Jj6odCXOWMdEhSAE(iuyOtKdI8VGOix4nE0f9W3dhh4HCD99jjlmG)MVqEJpXo6OGixxmgf4eZEJ5q)yDUW(gY8o2t7yZG3VFg0rjmcQn(9bDn(o4yCOtSNNVlQTRPFraotUVVH15TWqkT1MQmMBdopD76n1Tx0a0JrNJJAWbuoewEkDqekwMp9mLzsFTHCSPaf8dyV4sy)8hkA0HRO5DGC3NJ6tcbIjCvNUkEv88l)axvkILlAx8iLGR5O6Y1laN5zFBDrXvWYeWGvIlIN4L0GA0g9huxd6qttJcFwxmSBds4AG3vi)u)gOYEu(0akR3Yu9(zgm1yqX)tX9BHcBwpldBBa44(bu1EsAwJBNEd)(Nyyl6TRMfmUn8T6BoQEgzlQEUR1Ft21k1F6t)p]==] },
    { key = "FHT", label = "|cFF00ff17FHT|r", str = [==[!TUI1!S35wZnkoty4FrZuCg8LJZHzCv5uf7uB29cpbSvIPcbYIXBMSxKF7FTeGTqCi2ZsMpNmVxSBnMiKA1QF6wieTMQpDY0XZwTml5HVMMS6XL8FhZ(r2OdNEMX0X3vEXZeL82igllm(UHjPZzPJZstUNnD40X)9k)OWSNhpZpIn9mTpBBpD8IW5S)ILMCWc)07yl5fZpE2IK0lscJZMoE45tMC(PNC0Xu9UCwYJSZ51zEtn(UOKa)iHimlYF5YPNzsL6r2SP0DYI9dIyZ514tP(pEyy60XxDX6BIQVWm2dcP2Ws3utJFjPBkY)5KvzJINZ(bvV6uvMxoVUkNHxr5m86UCd4LZ2w3OZs5SUvT6SCULT6GolNPgvUmHkkkkF8sZvZDqx3JTHOU1mC17SCwIYz7nWRBrWsuDoAMoDwoBHcYXBWGo1qMIEUZaQB0PWzwuml9olMq4mPwT7QZwuD0qSx3gn5dFEUUDpmBLp8zB7y3Toj34sJuYD2S2IEHTRHE3vNO366A19aMyGWKmTm6U20leoRUnt0kk2RyPk0W2dCT7E4p34CG(GU7ewdY1WodS6elTSfacHizPHX3ZYwErYYWSWK4PJp6Sdx7c7e)NjNqJhE03gXVAg5ku4ImzvC2XjXzJd)xYdNo3Vuss08KNI5xLQJF8ykB5YN8FwQWnC5dsIs4o5gNM7Nt8)d4))SQvPCdr33FE(T3UKLjkEzXQvxh75O75yBoWXY2XXMCzD7NilAE9Rjx)RRmtjH98vzrHXSPJp)QjNm6SJk(tx3qdx4b)GJoBYrxsoDwK80bf)jUIp)309Y)r590u90rZwjiXLJ(63MW7au4ONYwmDC(fkINCjlYpl8Fyf3YKZVipOszqPSu)m)PJhD23o6Yr8GdZsI)gl8UfzcZSYYTwa)KUAGU1kAFH4NYdXzig80(S3MHVCXrUJwTAgflUU2MRFQF69K52WArwfd(g5YA(pKKuzBbEmrrqBDnB5iFYXckm8NLeT6HykuQdvS5I7omEw0Q5SjfiX0GIWTmrvE4LxrtdO7kLlG)r4CAqHKWptH9J9FGgmpijE5QhylF5g)45VCZL(ZcPiZfAO1Y)MUuE3wy88iv2ys1Ar)B6VMYgrnbxYYV5JtfnWrr)Zvh)9lIe4Qqs((dH3rJ0S5NUkklKQkoRh(alTYCAOHROWLzRNrdnNHNM88Jun(y4pyKiMli8bjUz8O50eAcuM5sPDVsV5t2uqdPrmxIUMZwsJQ(5(zwMrkd)OeU1oVDVK5p)5reg)qGVGvKCEXhGi1Z8vPIB(lRYs4xoyvi15I3mzQ6g)f83Ht49DEbVpmEo1RPj5vZe9tgKFrjNCQUFipiD6NRUFiTn(0o210YvZAGf5pIcJt(7jVr2cJOQomYeUWv8EZvaMnlBvLcvVpVMZffzMKthdDhxttxNb2KKM710TSFKQ47us5mq2vxaVq5QAoUS2qYS(GOFwM)Sf5DtzJmLXnYV1S7x3ZcYRxX8YZNeQQ9NU12B(PAhO7mOjBYGsmN7MHi4H(500gVocvOFQP4Qu36(1IJwzRCAYCQfVA0felZh8cJxWsdZeEnQvyfeROSfURjDWTnoQwQHlU7IWdYnKq)Y9DDMW9XgtTc9(qs0NNM8y5VhZ7lIhArOrlDkPx0lLIqBLluvnkxueFHMzLQUwtPxjDDQQZwTKuYtiR(vPfU5g9YndJ8JVpVD20QCpT)z17E29Q6ps4pAduL)KEs2(fZbr7ZoRdRLvutxRw1Fr0pOaPhC(zsQH6Jgk2LAT4RQugdOkI)CMXZLJZkej(ex(CPiwg5veRTCeFJjS1Mlk30pLhCYWSWJ(HfLPe(e2dfdZ)vsYdfTex5wiN5ZMGFHRLcCfuyWSdY8QLSd4rxZVLHkr0wdizcIshefikqu9irzaIcefiQ(IO4ct(uF5ZXnOyMH7RZfSJbWufLrWALXEpm26aC79PDNpBYIvbsRSIioBwrKFTqAnEOra81CG9tcJkEXurrv)8V)NliikquVBjkdquGOar1tevXSbftaK)pe0vzhRZ34vneuCHoVLa59EqGynojLfFL))JfS4rX(Z4QD(FjOTxEtUrWM3lMcowowXxp0ZeVYGUGSnqfV8JIxgoNv86mcAeS60(OKXmDAIX4TWXPS)EflE2Zc7z7gEfgRBZQ4BtmI4Exeo7(ygFtwyKFf5Mmq6fsPxF12RB(lC8SU)3OxYoWjEZFcl(oU5TUwd05)UXCM3sFLkpVDkicUAtfik73TRrQo(Wfb5oKCPQlWbkVAVA8SIhl53OzlbC4cqDRwzqqy1EpJ94x4ReF2L8w8vFynDqLGkbvUNrLMGkbvcQC)HkZFaX1RSj9tJ8n0iwAZ)Jp2OjESr8yJdp4Wt)(b(lZiXelVjOkqvVrufwItqvGQ6tQkB9USgtfe4fWle0cu17fQYepHvNy1bxnEY5NUDqL4Jm5TIOAFRPTve1WDKOm17IOmT7fIQ9(0gIYWT3iQFnBzs(NjxJev(Q21ZeLLRrVru2ke1WxJO(AA4CJteFoPIRWT2kilBSPIXMkgBQ4ECB6xSY76v2HXgyhgJDV1hLN96wUDF5NL(PhD4ORoDVCts6GyBi2gIT9r)tqdbUqGRpwbU0XhpnICHix9zKlpquGOar1Jefw5qquGO6tIYfefikquF0tcvy9kW6v8XA9kgGaxiWfcC1NbU0asbKcivFIui)jcKcivFIuwGOarbIQNik1Sqv1JMNGAPdHngRvmXBg)2MdacTQPwHDmBw0EU5OdJg5uGrZPBIRRzq1sIiza0w7G2AhsBlQ4dYAl7xzTLgnwvsLlnN6wup0Juukx)Qb17WwvoHTiHIsit35ALDntU04AL1w6DPEsVztsDP28zAmn10ugE5nkdlzdhB7GJnDDOU2f1vJXb4h(rwEEMM0)PBAz6O7MF4hXpK24NKIEMgoMEMUU8dvX8dPTYdAOxLF4n7jj0mlRYa7yuIaPOeP)erj(san1ts1WQCQnPYMbBxmd7TmMHLzdhDrEUfcM4SrsZ1XQT4iTe2OPhbOEyJ2cU0MET07v2)LionduRfb3bQbEQhQuE6hbvJRO6EVe11SB2v)2hXzd92ECOUE7mMUnedTXinYmhHvA2EEA2gAw2EgcYYsYixVHdFSxlg8g)DQtlRt)coWl6o4f1cARDqBz8R6zp(zIQCS1alBXzkRLRHUofzRecB80j1(Nl6Z4KvrVCtYTVCt2c2l3CCc5vP6jdTKDttbHgU9d7fZoTJyqMsbG01T018()YdYOAwfu9SeDNw7jPOkQhC35RSJm8n5QrFFC(jei)W6875tmQHfeRm2ZWMEMglZ(8zAmC(v9mnE72J0uDcchBR55yrCHPJPRLMUtoUSfpMtZk9YPLQbpQ7GhvpOT2bTLl0wBN2cVLh8wEWB5P3Flp6AMirqG9NkscF4GXcefikC4ncIce1VreLnikquGO6rIYcefikqu93XHQHTlwIcKrZbA9wKqZLYlSMyrlaJbgdhlBGQav9UGQ2RZH54TcJ3kmswrGOarbIAF95QarbI6dX3N(B(NNU6gx8nztuw3SOYEN81SN2Tp0oOT2LppDOT22TO76vtuS7cTWs3J3kgwaeSxOarbIc7xxquGO(DHOQ9QLXrok4mWzyUGGOarH5ccIce1Vr7I36lx)2L1DurqKYp3Zs5Nk5ATMZWdTKoCcABfXBhNAmdyEDdjEn9Q5Nn5fvxbi2107zBz9MMfy18Ftt5iNwZ5nnhW5nk5EQdQeujOY9mQ0eujOsqL7puzdVMBlxKfDWg9hp3i(8zavbQ69cvH14eufOQ(KQeZf0XdZfe8f4lmxqqvGQWCbbvbQ63Z5cAy7Gmuqpso4R)834V(Z3ltfeufOQ31ufYubGQav1Ruf(uyW2m(J4JD11Xo7(0U53bygWmGz4JMbygWS39yMoEfyGZaN9MZzEaZaMbmdhbzaZaM9UhZCbM9wIz)V27mRP2whka8ViMX7lpgsGE7mLqMMCBV9L0Xqmep1qySvkK)93J2SLLLCcqPLm98cdylRLJoFNfzHmIziMHBpreZqm73cMLIygIziM9M7ndxsFKZqo7TNZCqod5mKZWpo7iMHy2rnMPFwpgF4NFv6DE84R691XxLrtFVYZ0QEyOzJXdqIQNCvkhOvkhIvdFOt9CpsRmcH2oNR6F6F1E6w1ZpKXZRlth1vVrh1CPiQIOkIQhdOQpIQ)nHQMrtv4fr13ROAiIQOxv0R6XaQ66ISkYQiREuWQiQIOkIQhfOQhYQiRIS6XaRgGOkIQiQEmGQOxvCnGX1a(4icyhKvr3QOB1Jbwnbrvevru9yavJqufrvevFNJQg(Gz64HhaQ4gYh)UtGhabirHe17CIc)FGgjkKO(Lru4HHpYziNHXcIefsuySGirHe1FTeL(zfWZyhTOJG4c6)oBb9FL7EfJwjhaNmU(2Q9hLLVxDv9vwkFDG45U492wNEZDy9vS30Q6BDr6n7W5p))PfivIujsL)wOsFKkrQePY3puzVxZn7svuvTXRZ6NFZ1RU7JYGFZxvqO9WpT56FqBdq4bvArwj9MB(zEvfOWZKEIGZ)QyQiE5CceQpTyxtB5wPCc9kCnM(tkSY2jNhrr7zv48KGapNappVqhhNGGKL3CsOFRas(Gnv2jEIQVzYXWo3q(u9MaRh0SuEBoi8s3FK11AbRJSFJJ1T9ExfbPwn30IM3Ni8z(tvE((LtDgradrYAUJ8QPTeLYV7ZAVMnzfOwCXfxoJN7iRhQDrktuT5rY6jfvG6oLRNp5YVoLRVrvmv5aWAqzZLyZhklkalNUz5vFgmBm1ZHFbXsBmnWPB6LojmYz7n3qPbt67CGtj)tlDinUqThzHrCDpCi5e3bOevnQEeH7lbigqrShfO(rG2r2DQwEEKNBuSVFCuAyAuQhdDJK7gUxbK48C1Xt6ridPkpiOTFuX1UXbt69wrKo8KQhfIUUVfUPJB5Mk2yKjWDLFOZ7IggIfOdDrnFOsx(E9cPXx3LfPOSGStQ99LI8hZzFLQxdm3iWZQiWcyGTLxuBoHAA0alqQKg91LyVEFwdIJNN4ffg47eKa)mWpAVoTEr(S8oiFwg15gq761cNUAA0DR7NTpmdZbhezEIj00ZO1HGoM0ouBdD6yKUM7)dcKs3Dg8pThU8mzmF9itO)qQkU)h5K6XtUGfVOIlGcAGTIHcbepRHH73Mo6IpoMji2(WSn1fCXWztNaxl7bEshLGOSSOMcIqlChla5ZU40ZMm5mOy3SM8PI7ki8ueAciDoR54kv0v(96YTRYNLvxlYhC1U7ZUR46fRHPM1W4Gb1c7i8NfeTlN)DY2If8X0ff3stSKnyGaOPdVwZdpd)TM0wnPRzJR1ICYuiQhwiyk6gnbv18UAmMR2GzRAwHJpEyPIjv89mLn7azR0KAI(BOQcQWSsPUgK7pDYaOx)4KKWMPyObJc98CvVGtySN6Fhhe7NOCbWwSFqqNQWlnw5V9D9cC7uLHHrbkLGysflLPhqFLdGceltpngb4qwEwr8p2GLBGYp)SXxoDYOp)n(os22D8cJTDNyhB1wquI1Bf7BTLImFhIaAL78CLPQNu(DJBECHWASq4qr0DTUkikK9fux80oWoW6DeiPM)enBUiWo1dngfzLNvYj5xT9wA11kNHIKTLSzEoz02vfBavR7VpVK7gRCBnjVsAkIQVUOZQ8imrqZbyw2QvnbUNvDBozCwn5uUPbLzvPm5Po8gtk8b6TOMIfvRIUcD4uMTlxWel0haqBt7HzLZ2awF1A1ReTAGERkANlbbZnLBESjeHq5qyb7NgAt5WGilP5(vZ0KUek7AHt5krGD8Y3a3JQpT51dlmXctqBFqByvtVwnJZx24jjFfpepg78avESCAitkXSQSytRvkEmJl4z7SMoqOABSaRGjp2V73uhbT0kZ1tHmsrN2z1D77vMlHAc)fsUC(hk3Cvw5WmIC7MX7idBpw3OPQ4AO2G7jD0IfJg)pupP9fw76O70kUEl7pN369zGUICw5TSNm9G6jcTMFrDe3xIibm(fiEl1QVH7HxdqXsJlInHn1kmIqd8yrHiUEi8Q)ZIucIAL9yD34djIDIqOyNiek24dHlTSvta0JuOSo)2xA(b(FV6aEALjvDXKQ9LwALgDx)G101BO9DHvbXc40MerhpDF6YVYVF)iYaHSOk8C23gSGn7qJ7uXZI8ffqxadOUAt(03(MUjEizSmu)YF(VN)9zm3qFN5A(uULq6YGDQWe1(2lhMFTo67ROU7CdlBjjTD8YvlppkinfIflm0l1bcZlIV0r0uRJItCtsDtI9DIt9sL3PY2Zq6N31HT3z0I79eV(6x92OjkUvB20rHDZn028wYqBSi9T9KLemh87ZrOt)3uvSfLYM8Rut(m0WQS0zR4e0zhqfU30bSPgswU8)d]==] },
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

-- Auto-open once per account for new users.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if not Store().installComplete then
        C_Timer.After(2, ns.OpenInstaller)
    end
end)
