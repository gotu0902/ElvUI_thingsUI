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
    { key = "NHT", label = "|cFFff0000NHT|r ", str = [==[!TUI1!S35w3TjUwC8VoN5HolqC)XCXP1R2GZX4CA78atGyscR4aza8K2(q(SFKexmiecCIj1UDV6dPHGfcP9V)7lwiCLDx46C960S4hEFs86htj)EuW3YMEQRTSKRZTLh1MEQ3Skiilm62JJtwgK4KLeFFG7XBo(5Ej3hKqoYDHld(RGK4tUZl52G06Nu(hEAuAqMRn(A4fD9DXjNL49qGRZKv)7LN93xSY7742Xj9rVRXFcxBLYt7I4WOmxNfZU4ttoRDpk8hbKUQt61XpgmJCO8(UZTRI99w5AJW3VR8stPnz6Jbx7Mv20FD2n3q7tVdFsHxhhL3AkAUo)ZAVvHzFV6mWNqeT7EsCu66hcsF(kVOLpF1CC31BvA1h4t53ghp5dtTp11jiYZFvWsYGb5sthTrAMKFeMf8a53ZO)PvRY))K)v21RDs2ivzKfICOAnjEmlED20OLbFZ1wZnJEAksMIonLItdzk80ujNMMMSWlPC1Luv0PHYVRACxITKcJUpil9I40WSW4iSHazalCjDYldBrsTuJxhLDwCuwX8mQ2HWFIV9ysqA6tEFV4WvtxYKdeVAz8trNeVkMyt4CR7zM6MwiltDDjf8p1LCV5DAyRcFIvjPhEx8tNqAhYTq11z26SvHr4P(zxU4ttTNuEE5nF(PM))lmvpzI9IjZlAHIJD8SflMD(8PV)dl2C(8B96)1g3Jzu68PS7CDQAOvRFicBABuyKhqTWoD(LyCwGnMZNpA(8PZM3JDyoLmpyLxw4)g04ojNflm6ZrrYirXbCU2BfE6s6p1Ro0xQynzwgUAgYJoX5NJVKpUPRtc5NOn9MVuBkom66vRxgSOWuY1NAp(6KT8z0DAmXjs4Iv)Pq0bvi6quFk4626pTKFiwyfJQ(nffRpLZtDXqURjvBzztjfZ(aA6mVCorZTz0Lvu0huRiqPZw2OxLfznKPE)cl4M1a191XuvrxDyDx9U7UkiKMKXaBgRU7niKQH0aNcu2jtb6BTZMgxkddvHJE6uMtxdHK73vHLSL4wJ6DsZYqBaU6mnnL6Z6WgjPzP2VJotltHNLr5OLa3wOECB1HQUi3e4)qL4yLSOmvuKmG22hh1tMapDB(GD4TSwNwDZrBEMD6xK(NAi03WJ6GDBMF4QgsQFpM8cjOM7YCVv5bWDAWnbrPy)zpF1jNIdJ7)KRG)8vxE2F00l6KJw8HpAtNl6Io0KLeBQQNhhfsrPx6q10qvPxtv8zjooqkcPAHN37fHWTLynTkb2EIxaJzizDZEPrldv9(78iSj7W0iD(WrNFKD3QTsMiJ(LLKTmleB7DC48JE)eb(xvr96VYwvtvP)qVrkAQAs9lvQPO2VuPSSKLMv)Q4kAkYkdAG)I5tN40nwOAOzQ174Uw)E3XZniXE6uk7sZN9(l7EUrH45T3RMgYWO3XCzl9H5798z2FuGXIgsAyd2y47tZo5JImZvL173mxs1WyyM5Nob33)WLu94oVQwMy3MdaU0nKnh0v9IJ(0rNoTBCwxSPUrU)EvjXxokrOiBQ1ReJTUyvBZCLwZEblSByX4xUPUecnilDHP3zJqMdiRDzKUSP(We)N8)M9rbgckgQiuVTKTIUIL8WaN(S8m1XbC2pNkz1tHjYdkvx1qrBideDLr8IzxueXwR8H5vSku3fgBxKx876kXyfrjgZM4og12UuJtXTqsWuCwSKMR2q5tjEpEAiod5tN9z7gPqFcTmKUo5j)(5WL4q1SX5hWuln8W7RjY6ooC1GBsT4Q9zIRU2fYCiLysuB91gHZUfXq3ryYSrtZu8Qxum0CMyRff9Lx0laKhI9XRXx1NV6DpF18WBVllF(9db0)pwhODnH6Z0VWyVY4VCSLJPFFOvrLFyQQsTQVSP7Xw5z2AclvRSlyXBHfCtqbvkKwQkSJuE6Kk8W4A5N0DYOnvH87ufA7kzU46eKXVQwnky2Xhn3zYIlV4VjenX154iiLpzTZ0Jm3k9iT3Wm95Cs9MvpcTduK2tYQxKEuhz8xOm9Fw4fD)F861LgOlz0GLLoENllTTYoQIG2MYpTX9bOrSDIoDOC1koRUklhV4G02bYo(1)y(SQn(D5dl3wzZx40lxwQM9WqKLu6vwQ(04RlUM60txIdFH9dTXOE4HTjTPlDMjjDgnflDvnCYwits9o1O2BzExFFAvNuR74PONOOVWpIGN)GvT40k0RqJHNQRz(8Kv5HAvq3ClOZu1qKm3K0Tm0rA5L11AZTz7bT8J3C0TvSTAC(Qf7syTuu9i)4sb1NVIy4N(MfMN02iN6ZSmbEdd6JJ6QwlvtvTov5Ai26ZCNY8neUvQQTKp5ef1weWxhH3P)RGo7Ev6O9CsVSVsNFjthTE4FBYg9tb382LmkAprLIJkKfVy32hfHYV5ELcr4)8F)q4TjEzblpF9QSq8fJK8C4dbjnx(BgUoRctZQw8B4l8tl((J4M8XWVfSY1jVVwENpD5QaHD8SeSZ36qbZOUC9zxnCRUmifpf4rJGL4RG0bMh4T87tXS)d(Ezm5YwSAPwUoH(zoADwm1AADi(2KEfjTqB736IhsIQRzXeaznb6qMDRMmE1kGNLe(JNV6)U2BjUV798vlw8clmN(HtH583XkH0w(0fedzYf6(WOLylySBmEHmj0xnQ0C)SKG)zDq01FNkYPXHbOh4UWRVpkOy9nvA(HXBPkgbvJryRtt5ifPP(uq0TehTK1EAtEXVfViL)r(8Db4e88UMyQYWm5lYQNSjF5m9spK)EhJqBIfyW25DAq)ZTGp58XoRGp(Vnf8HZGzwHCNuB9UMUijtRSMmTRBJe7yjxjWYBgIJhIlIIfolxfrU0i5d2lnE50lWr1gv9TmrCrg6T6yVC)tBY3G6deFZMpxqS29loh8pPF)o089(ARl05XlRFDCcJUlijmJgKBRtM9Ep)ClczIuozUZELtkfF6cdDFC3HmyfTS(uaDHHsMe(ZYYNvgxLCLVDB6qZgGTWY7yCdUmj(XYF3HMGBLvqzGtYfdfnd(9MwEKURiqqKkVzPg361oUFrNylUNUPrhHez6xzleaZ4E5aAdQLQl1wtGEX3u)rAZ1QqdhrV)CDMEYm7AdpTNkBl7kgoQzmrMwk74BKquZNDMSr79gILprWpZZ158jNo9sCgNpLNZfsPiaRtlDSu4fLAsumt)xXy958bz8Ds26umTSaRvVoPyP5o95RoELx095d2FHzH8xClKhFZ60GtiXNMpUEC30jbZK3hXm2PG9EcQV5SThxymWyiLgjTPVjiW3wsPLLhxuPt1Leg1f)nQl7qCINUdlcjqwV7o5wHziaZamdWSXeZkQfwAzuL5ihUh)ECeZuZww8JEaHzKWwWwC2zylqsTxizTnnQiRn)okERFTI3MuuBIwtEs1tYtecUb5iN)0O0WLbBkx1UiVG7QvhX2uj3eQRdvnxbvL2)nbFE2jTZbNJgY9bbpEej3HS5KgGtzgze5evaJndB8LGBvMab0C5LvOH0p2qkSj0v(5f36nhmQF0MJVIyAY0klsZwdu2Iy0sQRlXlofdzizisrvzavbufq1dbuvbqvavbuDphvZt6SQUQ0vSR2Hq5wBLsZwNVWVHjXoGsRUFKj7lihv(vUOvkX7YuzzQjaBwSSvnzRQdKoGzaMby2yJziaZamdWSXgZGV8q4B1a(wng9V8qtWBg4nd8Mn2EZ0amdWmaZgBmZaWmaZamB0Zntg4mGZaoBS5mlaZamdWSr3DgusFGZaoB85mjGZaod4SXMZubmdWmaZgtmJ9bcYaw6YWsxgw6YWdeeGQaQcO6ocvvBHQm9s2Ef3l5wcN82veJ)3GKemwrFrGsI1RKSetNS3S84toM07AwSnh1TDC)uzRnAYgsqcacgSSTbJyISPQmVTPm(c51hEQzW)J2ReRV0b9XFmPBYR9Tox6RlGx49yR9vWU0z7waBaBYDDizYrRvi)cpM8GRwWv7bHRwDavbufq1dZhtEiQyiQyiQ4dGOIB)SZx8(4g2PsHDQuyNk9N2ovQoGzaMby2yJziaZamdWSrFF3wg4mGZaoBS5mtaZamdWSXgZ0amdWmaZgBmZaWmaZam73YxksVwmBsuI3TbnELb2a2o(3OTaTrcQOJ2039QMQk6iEu2GaPxG2Z28eACMgYWqxtttXuYqrxwX9M3rEZqVJ3y0ekOCi(m2dU9a3E)s72tc4mGZaoB05m47yd4mGZgDotfWmaZamBmXSdSx6MCws3Ixh0Cw3O7BpQcTxNVTwJ0Txg18qjoYdCx948fq5tyCFokeUyPzx55nL0g0JMa7YtElwW07FpUcCwS5B5cvNXo7q(bVh4xGFb(9W91ZjWVa)c87qFUJ0vf(ChTpUbFFW9Yx6L8cg63R3htnlFrVFtT)Y92xsbWmaZamBSXmeGzaMby2yIzClw7GE297jlYUFC)FXzrYBVSySZI8nydTyC2Cz4V1KWUzaVd2el(sVsZT2TvQvlIA5bwlHSHN(3q2nlg0(vXqYbSrc88sBv06aS1EB0a25k6VUSaQcOkGQ77OQcGQaQcO6EoQ2UARYskmLBvEFCBEcsqfsq9x56abBZtWI2dw0E)USnpnuVzZdFS7NCXDldjBU35q7N3lCQnprJsgw8qQwwHVSxIy9y7pCSBh(Sn2(vG1480nEG994p37(aGf)PYIAAgieqJJcncByuq8Nq8NWggfGzaMbByuaMbygGzWU5lWzaNThWzWgbfGzaMbBeuaNbCgSrqbCgWzaNbBeuaMby2(2gbLb8UQgExvpVRfen82Q(f)2QMD9K)6FxvBbOkGQaQEiGQVINTi(ZEJWZt0l8no)(Zttuhu2RKDhYtpKOf)f)huOH)KgXAT2HiaRr)(87D()p7DVZJBcefgg(NtQIKzUadBPlOmzLIvsNJVihBkYfr0wKg(ThN17AYay84WLmZUVnU1yzEMVZGMZbRqRR2Tro8w4Vr2r97v6BVbQjQLOwIAdHO2OiSkwfRgew1IQZBEn6qXVZN8MPFr((DfV5NLRYEO4xwDuHl1cFUXwFSo7LVtp01gFUDd0IOKjTuzNA8(BDkC6yLYZVWnWnw3)VVa96IKDA7Idq1ZTUVVHF8AetSmXYelhcXYkOkufQgcuvWdwMhSmpy5G9bl)0j2LSwYAjR1ZZAnqvOkuniEWYcSkwfR65w1AyU(4X8wO1D(UZsshbqhbqhbm2nEddZvygm71YWCfMbZyk)GZWz4S(4mgbRWmygJGvygmJrWkmdMbZcL3IgWmygtGvygmdMXeyfNHZycSIZWzmbwHzWmy20nbw5OlZrxMJUCao)AGQqvOQppbwHQqvOAO0qqYtneKHgcInOYguPHGAWS6)f49c6A)ND7CP2ny1KYt24SvSMfqtMuACNxRu5IRUuuB1LnvRUmGCQT1DQtOoww)YxK0qqFC9x)rEr(2Yvl((dBpynXuTO58bLMrgVlCRBT(CUwMreRvYzkZXpvYyZYV8wTQApd9uVNNpSsvA10YAG1CBCQdUMPfjjXATwAMLiJJKh)jRuDa4n2awiV9aX6Ph2qDtFp1A)5lp7ZlwxSFNJy90gM(pJ1pCy9Xk5lx9PJ7d4UYv3Vo)B(jyN6S0N3(CwCIkwhBsngrQo6KoLv7SBO0P2K2WMrow25)WIzny9iRvxYBBDDOfV)(Rzvl65XTMe1Vs9RVSQFvdZGzWSXMzjWmygmBSzMFo3iWz4SxwolfMbZGzJECMaNHZWzJUZMHZWz4SX2zkygmdMnMmREVj5W7vH29Nf0(n7Dg1BBYdfg(VKTX2axoMuRQ00Av73M6vDH2Y6xuZsMinDA7I8BFqAsgyogBcqXGo3mnTUT244NZ7Ht87RpEw)EFV3ED0BxSE6mtxQEI6jxx9Agd8m8Q)qsB6AjR2lvlD37y1(pQW5LUWHx2(JkTn3)ywFdJz68sx6KIdDc)RuRRpUAXcrufrvevhdOQh4T4jKVrQ09WqAAPgtYM9T071T5jOxEof41sJwPURrJzLmFFEQSubvmcUSEDfckis4ogtsvTQFCMeG4sTOQavvrvvuvDmOQsPiRISkYQJcwTeQg1E75hDYe7zspgZNqcOEEEsHVC)b8)(7otif0S)agHfgi4(S8VIFtj7Rw9RK0TZUy533So)9fv3vutdYr2Z4)3Lx92Gnpc5Gtf(ODdOeICW6y(4sVFiLXizl(sps2VzN3ke7w65cgLjPezy26Vi7h1dl9gscaMMn16VA8Jkt9gl6bDL3pc8(p3C5HQ2z6QfX)oj9BFmE9lrXPG(x6TDD2pPEQH0ba8B8(Qg(OapkWJc8JbbEoIQiQIO6yavD8aOSb9yV3eZ38)Ztw8ytA0UZb4)1NTVlnwA7JrRMmzAWjZo16Fw2S(NnOOzy68fRX2SeQKG6UOUlQ7og0DdqufrvevhdOQervevru1Xr1sPj7UicLs4kPjBG7NMSOLcqlfmTCUJJKMSLJQ3XgL5qjw5WMeZNuKhcxQTHXwPJhAZOFVr1munR)97TLzbR6HNyyqUOsi3fPRw(9nPDyeVguBeVk7efUA2D1ky8(ocgJ(W12fYR0qgjG2LkE6xAabyJf3QjfyL(HerGhxKNfUebfkfyVxFkWAj)Aqc8ElpUqUtgWIDDIDDoL76uGygIziM13yMpIziMHywFJzUsgWICgYztzoleXmeZqmR3LZiiNHCgYz9oNXqod5mKZ6BoJJygIziM1NyMAgW6p(Th4nzVdNrclFA7SRxfN2qNb(2w3ZZ2N8Z7(Sx)5uqMWZpmSUJlD1J0BLZDB1JeTUdoTf2fSWR8l3TAK)Y3ShcvpQZNCY2PYhwzxq1JU8FQ(5pF7WMYD3wtk3Pjm)uJVetLabOcR9qyiy6ucD80vF)591eeREnjnnJu3T)mVS4bVOowSabG9f6atrOwRf0sehTaH6(rawTERQQSIv7(fn1SRiOuayAa9AJzhQN2T2kehKcnAdciZ8wS047x6YcYVQl8WvUhw)lDZM0xN)A8I8i0A9lZx(WlRljGBjpxsfN3BQ4sQx(Fdx1YtWsXAsgR2A5PknnElSS8WATjOYkQCTQqxfohw5RpOBX0n7OZaML)zEYJzDPN8uYYK9)O3IU17poNXc4SXv0E0DTLx5bala6q4KBfY0Nq732NwhTV9BlIX2bLKvlO12iG3Y93Je)hxTAJ9zUJYlkt8PEnh4Ip6XRPr870nbeFZy1UPv7GolmBp1MSppEr(3Hh2o78nXPpopEzJ7Xosr7v0cTxs9AVupFsqZguMwC3UbMvDsyCDBvuNXC5WPTrnGhPztCLU6GbWdStzf4IPUSJ2UDtQSz8jqkR(uHBatA4W)9F0z(ejNN9lcPxGGW45FDEhKyioF74rjPRtsF2nNwUG45XD7zLtXzLp5NvoF6(04rXPpV(55U7ZFtXN)gF(7UVNEZXHRloL8pTzzC62zrjX)O1thV)uTzeorkh4o3hYzMBsKgQjw4pnmTzPRRn6CRsgTbAy6wexU4S2WzTHZAZbM1wW0Tv7VKUo7TZTZ(68NwL6M9B757JFGxyd3Ney)x27mO30ggmm8VOjfhNecxz760Mevt9iTRmbARfPfqv7c)2lqv7i2XXXjXPXWZXEesF(Etm597XwiCmHWecti8ipeU02190xuXPsLTRRS021LQ07ZYA4RLIwWTHclxeJoSHZc09rOemdmdmZ3ygn8fmdmZRyMA1dJB)RxL9JDUJpXiAzXXJ0XP3uQ2(ZUCR1rZAp00zN7WfOUvmFiowEVOAJq)bvbvbvh7OQeufufuDKJQLoUv5X)CIq50wtWLzy)fS)YvPlZaZaZUKXmCzgygyM)DzMaododoZ3CwoygygyMVXSuWmWmWmFJztaZaZaZ(4fn94cZo(HQOyxX(fZF8UIv9OKPRL6oQG6RoQ7SkvNhLN5mg2xuNgo3vdshcG5uY)i)J8pVN)XpcaCgCM)5Si4m4m4mFZzjGzGzGzdzdIeXiZORxzgv9(pWYcGbdg10TPXqiZiKrg8l8B4YVs43Ry(T5RrmazBGS(WVHGFtHFj)L83Gn)viaGbGbGdxa26YrDy5uNu37ZhOZtA3)WvK1)Ez3f3BQ)utqwKzPI5h2UEleOZQQ0EZfDJRuELBq7Bdf8UrPDw5Ev42yavFt8zKytInj2bBITdobRJ758zdUPcMV7Hhw(0(fFz5DBx5IPcgo7GMgNiN0yIVRQlq77xd(I89lJg8nz1cnO6b6kkfvXKS1oXywlmiOkFyqyGM8kAt2e6TycXzYnTgEVsBe15vKEL2G1UuXitNJbNJbpipg8jWVCp5Cp5b79KNd)c)c)gUNcEeamamaCicW6IdtefRSkBN46QSD76)SE7)E7Fk(X6LpF4sFJAnXnF77QvMyMBvMOMxH97vEf2)77Vc7Nr(3Sz3pxTFX2vl3V4ZBkECtH5QYpkL1I5pLUx(cZo7w)Cq)FlbI7Zk0NKgjZ09d6NInmD91HGnTtgkTlP2(XhjteIPjtZtLr5Yy37hVTYXO2gJsT)zM1Iwuj1nQ2lUxO6rQpjU6R7KNGnhR7uRgXw906QgW0NLEYvKtBQXh6EX9TzzDQdHDnq8RB280VwF8RUHjguKrmOEmOiljxeRHQzMEiJt3iv)NbwEhXezld8(Hod0V7OPrbpoFh444aht1Wrb04OFn7YnHwcWEP9UswUTX1I(58E9c)ksco(2zzj3DQYr2vSs1jBCmLmDSQql5IKkoQx4V9gtKeZeYAWYP4MmqkacaEpN7fxaCyFqO)MfeAqpmRhM1dZ23WSOEywpmRhMTVHzhlFdu6Xz94SFNXzj9WSEywpmBV7oZPhN1JZ6Xz7DCMxpoRhN1JZ234m)EywpmRhMTpHzIQMBeNMJmW8EQEuzjSwMNMlUzm3YJQ82k(idYHdLyXh5dlUFvjQLZUE2Q2KRgpXYa73(1udelvEeFVe)i)dYjww7rmMVHlUFRfoWX2JgDJIfp(XIB2yZ7UC71CeR2U3hYnNTOhlLhfzRA1FrRMXiFqK90TDTDAR9ZJDHwCXbrXjHorjWb07pjaiTfU1bS3CL51SmhOxDwApVahyUJJ0ZMXU4KyOMq5lDfTuhApKvNiJV0z8BsKdmNWbgmpdtGzK6MI7T(yxW6mSZJEHsCS5ZeoVsASteHxonetOlioU)gd)gnlF(tLzVC7)9Ivlsl(JJyzdZpoW9WQAywbx7w8WETAsGAGRefVvogoUpDvIuw2DeR68SjUXqBzN8U2iAVVcndClH9BR4cnSil9r40BwvuwTjAl0u7deAktGq1sQ0oHgaaqNxhdUT5Tp3MG4fz2uqiQX2Tb9RYpBhYqIwwlJYv1gQHqwPAwhqXfkSBV9VIut0H6cj72yNPWV9bI3hiEFG4VDbI72vI1EtfaqrZEz1)RkT45S0FMv8FkF52)oT4PxVea26ME)KvnqciXVtpY82Ik1awEmQ96aO6KS0(2um2oCggfPaeY8MgQZUZ6MvjS1mR2x3tUWntwyJd(oDHBtK8s5K0UjhPk9PAZYQDjwBt(M117qV3HEVd93oh6(VBZS21lZp(ZSwuFM16ZS2HmZAaB0X3J2a4TsbV5JHp7(TpvBGdAQ2Wb27Vzb2RLDWUa8vWWXrcMyDG7Y0l6fQBvYYLmQ434WYnqi(kcoV2mRROZ3gPhSpC8(WX7dh)TlC8y7)0BSD(T3nlo27EXcD)4U1YGjuTUjszXrAHvmRL88GzDQekNDll01chW6I9(a5V9R7t)TcCNgM)KPp9vMcV240P3T7X0oZg(LpN)J5lE5wiQyX)SEZ2CPtvhbP18FBxi0UbrEEh2DTsx78uwS1ozRN6ykf48oILdQUFBN2fRNYzbQ1JthIcm4g6LkqMVN9qQ8byy2Dp(H6TOE2DZRqVhVy5SFGAlz15thDZAFQ4MaDt1toNgJ9H1tfYll8Nnd9KBBQjORqS6KFzH)TTJP)VG2FS0a55XHXjEjXHHoa4Ft(8obys5aTGCBOdu93E(sue1zDPKcSQ04BsCfRf4wQWXn)7yuX7EcpL8dnKRz(PQZvcYAyaZlhfVh0uCCvZpg280u(kMAIgYXBZ(dKFi13LhyGirkw(C1ddNxaP3WNZaYTgn8B)fXaezPYY(jitAojiY52dce(WyCvwXNGobXFHRqxGEqLWwX5n1hSvJGsRU)Ee8qhaOUSGge5O2WjzqiO7Z2q0GwCDThUCIRb0cVXQaYGuswOHJDidtMpTQLh5mYiGI4JZu53QTi50nUXaLaJgZQntfqiMmunc04rkoYaLyDw66PnyH8yHiSftvjyT(Qal6v8qoyK8x)opbWuR(MkO3MYrlX55AWPF66rt(8vFd9qHf7bia7uOFYlHGTC4qWG2l1gXXkICz3jO0tPc1ZGkderTd0cnJpECK17hBR9J5AeDkKrA1ywZmfC4uwM)DgkTrqBndupbOWThpXrhqu97QcyROQy(IFKvvE2WpIJGKzbpMJMqaXzW3jtgZJ(VUAz5CsNF04HqJLC4BI85LiyhCku(Uqwz842JKTvZhhmA4Wrdrhc3z5RUl7Q0Ys6KpBIq9AMNwAf8v7dWcEnS(N8HtVag696fPpoF2KhG2kpa7f4OwO0iSf9BvRMpH0L(48VJMUlUVaJOg17APg2a3UQmtvzMPdsRXSJ3VSnrxXqO0eAvZwRXa3Tg7or1SoiHEWRX9iCErQn79KSXoXf4AComntyr8iNxaRZ08A7T7YOwnEGO44a2PSm2hecqRNfZLaUE(OySyUKxqqOFe)LCGtJN)kHEjC)MkvMuUe(B0jdgAWGNqSaKaI4Wt0kIiLm5lH)(RhD2LJhE6N(kQWHEAUHxyOU7eORmH(AUHRdqxr0(ucJ0vz(raTfcOTfOTJgKOT20ENahTLXv7Dc0wBAVtOJ2(dESMqyn(V0v8yTJHXARzFTJ8EbA6Ci4D6ty2ONfGp)QRZup1S(mQvmYSDDRxZkgqWhrXEHAaRXFPxG1nUwFINMGZry6QQLxNvD6Q7MVecUxSilNeir(QYQSIA)cisdEKdLQgnvSRsV7UANPPZOU8lOFbvAKD7)e1)9CAkjlmf2gHHwMrjEMi2gHvpQrKMF1sOBUbeQFMvjap06ZnuYoSi2gzA61HDc9sxLw89SQj4)ur7O(9xv9VuDBLw3OGLVpF5ZnVNCQl2zPLvc9G2kNVhWs6EA5Gg5CG6)d(Ad6cNVEEcnanmd5Tn7U6OUrd6LOFCjMygBHs59QKThjX0pH8wbvDyVf1CO4KFn7buxb))qrJb7rO)nk8G51JOoT9P1s65UIpUq3C9FMVCAAZkvmzjDYb)ItApiF3SinRjBuA3L6NTpN6cY(Oy4nygExZzGv3X3MgI7UOHGEBcTZ))1FKgu2AwlMO3TCSq7QB0AD82)gQ2Q1C8u1HvN)ZpF(3UcZezQ1ux4T41KNvVMKham58yZEnvj)9hWY5ymM04RyjzWWYwoc3421VPbjVXelCM14TFj7a44WDa1tnp4yuaydqXEgJ(luWqy6Cc1K3l3E9aZd(1utmnrWn28MWecXctFX2eVfxdrjtZWuVqJOsT2sbMcxUZlw(ivsJMY1uL7t6PqAzw11YDpoB5Bmv8(eJZtfBHnW5NeHMQvqIVdikXloXhLkSWJiddgc93z20)UW(d6M93XE2)wcFaBvOI9F3r2h5Ii5J8iu9(Su9U2t1)ELCvKI6T1f1MsrDu5M69lB07wpSBbZLp7mFhJs3ekIVqsGFHHyobhmNakbA4lgr(VK)oKMe8TnUwRjY8moH5lxKV(LBpZs2Q3VHu1Zq8M00pwCVn8dxF6Glql20HGKabVjBKs6AgHn(OjSdTGqtMtxQ17FGB3AWouuKrkgZEC88qGdiaadVo0f4f1Cg5NEZ5bbWPBghg76caEHojO74Jxx6aFqsOVNRBqaSyrH07uaVJNxuKtmSCoEHXXUK7OxwGRMZSt40VHqnCmbSU0srpWy(PusArdnboGeqKtIVFGRhDOr1JaTEFYlFNYf0PopN17H1ZWVsy3AOooIch7u8fizI8I01lxr30r1P8xsMzv(RPR(c3ZrrdXUhDK3URYOdG0v40tgpJmtO(JCfwnIlU8VPEO8i1IYv0xqfFpTQy5m0IayEV8IXvOvYLaRy3NfSF4ufLI6FHxsbhCzOTAphN6nj2G6mY0H2cR(KmzwVN1GYK2jbF(kDtfXgLGMDBYjWMjfZEthaKiR22sMTg1UzF5paSujSUrsRNA6qokTzLCvSNEA027a9cvDCJWu3iu1tBeQ6U2IeS5Yfz5FZ)o]==] },
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
