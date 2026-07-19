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
    { key = "NHT", label = "|cFFff0000NHT|r ", str = [==[!TUI1!S35wZTjoBC8Vo7Er3beNVmoXP1Z2GZRTZ2T7fSghtIzcbYc4M2EH)S)kXbBqie4dKesFMDMnPoyHqs)()CqsilrRzwtVDDuCWJFmmy9trK)TVZ3JhDHLPOG107Z)uZKl9ophNyx)7heeU0jCACyWdowdSM(FRT9CJ)X0BT9CSmf(dvRPRCx68poHbNVYo8ENiYv56FR36LoZcD9FWjoYAH1uB)BxfeEzO9Jowth69TBU8FV2Z(hoHvUxU)0HujY(gxh46hBnD24R)8WlXvSONSVfFTwMs4F)2GNCgt(sP17P37fSW2ZYeHFw9SJIsVQNCU1koV8(647UlYj2Y8d4lY92a)07NKYU6Xv2HpGlYDpTPvSKhSLj3NSpFBzHsVljnQifDYpCJDEK8VJt(tEEP)o5)YRLfUitKSiYar(ihF7fEolj3mCZtW64r(lD(ULPIvCYLjjOZ7YKYUmKo3ltMCzkkICVLIBVLY8Umu6tvPNs8aM0U(RdICJDd8X95MxSTH7ZPD8dg(PrKpngpomz8zWA)4ld8JZgdq6gdc8wg8Sp5tXLX3Fk0jk6z7FKDXB7be3DPNh4fqgqm9ERl1v1nqg6QQcs4FQkyD3huWdjwGh6MuNxf885KYH8qL)9ZgXD(qZzdNKFnP)P0llRsYO6K9vhmE2SXxnz0h)0SYpbJxh756JbGX3m7ZJmhwO0Q8NItyYNJxznDBj5T(rF8GATSH3ojd4(YztMmA8eEd6MEXKBWGo)HLP8Xehp7y3V5u6rjf98ty3Zd8Jw)Ot0M52(l3mFcghTXftXHhz9Y)9wutKgY32hzN01fsKsqKEm8p1t6Fe3vL(7cDYLlMr(jFUqYavEYwvrBAvRfucoL6dzONvr7jrMPSYtgOhtPAHhqLPOSGwcIsJcv7dCXM7TspAI11fBkkQliP3mTlGev1BM2XLTMqT3mzJgVtjfbsrL7Ownu9pp6YsQYNYNhvLJ)5r1O(kmcjN2K1yXikivBXOkkjP2QsrT22wtjrDLgRkMyvtfJMA6WTWYcInAskR7wV(MhTgRpIkiD1w1vkMAW6iBarQ1xDLqifbTwvmA13zQNcSnveXLL(RX0kX1e0bBlLY0zyQ7unAan5Uu5Br()5s48mxYY6DHQS8UpT8vwNjZ0)ujZoT0Oothb2wqcTYkoddhfSHNAcLLRUOswZ)0nj1W619urPkvC9auuWObV2sLhvL1KuAft1GxgMgAYQOM9mfpkQDIGt)0zxDMz9Tdc6OMPhtrd9m10gFaV6SpoKJ5tzuJApMYkYsn72nssrMV8RuQ35sYnhrGiUNMVkTA29usuQvn8xpz0WPZQ3wOMIUsJT7knRuJ7Bq8vI3A44IHNn7t)Pzcsvx9sruqb1y7GIcsQXMbtzDn(I7OSRswQXEBzdSYzJDJ4YYa1Q2IH)14)KJ(GKMmc1CDxsvYqSDMbXG)NhF(FYJeLBUOWxMSMw7iXlgE1yZM0bn0v0nAb)RQj2o))U(SpF2fJ4P4GAoAzv5M1avLAEuJQHSq7AR4fyNjcP3Iq8frQyZkATtLCSjNHcyx0eANkZKXF8MHCCqf7TCJdIvqAAnBj0qvTLozXma4zJVoliW0WFVW5oh)i8FFZ8ZVahe8VLMfRnZV5YFNrcJQMRNspOAAYYnlERQGqnBRdziAWV0sTRyOP0ImnPRRl0CpGUHo37OwAickgYnnKpPh4uKKGpiYlzJeTV9j)MyEE)svqeUecDgHJQNuCfEIFo0(PlCdXJGg)fZsvXZtslR100Kb8f3Ly)fnX9KuzldpsSZsv2IcEUhU1ZDkFVfy5GD10JXY55AYnwuS9Tpevi(HlLvqe5ibvdnvKsA8ggfIPGruhSQ7Pf82AUgZ4l0R43pZqvslRDYb5Fc7qb293YUlIf)mg9l1frb)4nyfvtHOnU56wkNnynUjAZ8pSz(e37xfNoe8toj)o2lHQ5YtObkDBVrcJMXSSP06sTfvY6wuo9zfsy2UQh9SeqNGEHczjJt2bYYEaQHmLUnACH0WULOuCgC2KPdNDZ1)BYOLDb3fZkbF8TqKMA99AEoQjgZYMMwuFEeQKRtI)PDJMz2u60lLmzNSJxEjtYvNxlUurqxvg7mh2)EnzbSB5y5tT2LOMduYKD6v6Ejt2jW6iMKfEsMfN)JcoaMjE(BZS9Fird9Zo3f)7hVgAl90b1Aj0bVSsOmKiLzojkLKg5pLH7CPUg9T9tKSfQUvLQRxKN4l8jqICrXV2cALXf1yVnvaqitmi(yKqlmEOnsOsTxcfDY86uy)vqtTdZjt0fQsxQtIgwrYqvwrfh5LordvPq1uGHAPct1sLg092QKUGVKjl)rl1CqjGACCEw3jEKMz(Qof2C11ZweKRSUzozGFuz5uKsN5sQW(iNUO8Av5eRUUVoGwDMJLmALgxjb4fup1mCyJHC8(P7wEYVRrkNRoR67bDwi6(op6E5FnJUVORQ7cUN4y6lwS9O3icPmeknoWiW3xDYs1TxnTsCz8Vp6EFODSZYRw7f7IRdehTDF0jS8caf3D65gfVD5FIRxpp7hpHlYNC)UJN100QrUVxJw6Li3w7tECiMjkkCq1QlwS3vbxQlDIWpC2j(9tmNrQatCSx(JryzShxyhtLAGSfI5Y1HjFNZwhhKmAATl(X0plZ7pxNgEbTe(CuYQIDkPxBBF1XTclkC9QTrQJZYk8KQ6321trzFwRX6av2aoW1trAJ4LHU)CZ8)3A7L4EA7nZNnB7c38IzKbYKB8dU(lXJGXwAz5vhx3jq5d3Vm05)w74F7psK1uyWaKp4Zo(3tmGtwY05d(WqRq2LVY92h8DiCmQaPqN8R8gMmOcrZllQWlzL)xw5Gdl2(wYqvkMjD5g(SPLPEZ0dt3tiFPkbzTRnoH4e2JH)m65ABw02Jfve77sZlUi1tamS3lUOfN(fxuf5js3i94MQ5xsK2RlM6G5pre7Ie7ezlSCklZ0IWP0i570inEZORXoE7hVDE5oms8WzpP3MShDtAc8PvHjFf6)j7)aQ()oZG4Py9eEy5RV3OaCySw(g2GS09hyN6li9Qih3fNwLj5UDr2fH)zcMMeZZxRCNUkyzXB0ux)voHUXjb9w5IPhJLETzXNqC4LzBrozSRBiP6D7dewWFzXr6j7ojY47)ipQL8CRlU1dFZKMMDaAMxndWf4YWGNY)3ttIXlHejd9Zdsjp6VYHDExLrNRYZELmREPsp5LtRx86iC)ZmmGTomBPmmAZ8bE2(pKEF2DxjH89v6Kcs1gN34vA8EIiuvVgtA92fJxsXvjPJNL8WynD05Jnl0wuTBRQMkFbNcdCi9b5v8SllFBzG7lgUtz9oY4CICEST10RgEXOBUYA6ZPjCbjL5rZf5oTLHLjdaY6x)NaSAC6WKfzda2JXtKoGIXat(3z130Gjwh5CojiV0YCq94jbZubmdWmaZ6AmdbygGzaM11yM47qmJ8TIIwhTz(0hTJwvElzwK6gCsPosUA)1K6sA7tcdvqxqxLfgEqKwLH2CqVlv1meu0LKjl9zDbfrR7(GS8lnmYvTzVatDW(hy)dS)112)uamdWmaZ6AmtdWmaZamRZJMte4mGZaoRR5mdaZamdWSo3CMaWzaNbCwNZzWKTbCgWzDoNjdygGzaM1Lyw2MPkkFLsM5cjU2(rVGNZhtw8jHEjlZKWw6eHhqr2VoKvB8i)SvB8I9ypjg8nNWq3LojVL3jdljF7DRo56qQhCCE6mYsanEcPkNxJh5hHlRDBcPJzt1K)qUQWoqRkQXCbGVDyBzOL56cV86aNfpXqqGdxqnWo)PybRxw90QRSwhW7AmlY)L2Bp1TAW5U1EOx33)ChQurrUqzY)HUCRuXpTCpbpWM0pxXAe9EOl5c4(8vvFQQGxj7a0BY3AnzsaydGFb(f43El)kb8BFMFRo44OWwoRHmGGpycUIA4jKFva(fS)c2F7T2FZwsaaadamaW9saU)XVtFgZSU(3Vzo5Dh5doLpeYOhdXIMlCGiM8wNPwptpisE3(vqvqtq)fbTBP(ed1UJbZzm0SDGEfS4DcP)3hNJ28JFPOGAL3KDLua4t8iWKnyYgmz3BnzNmpVvANz(U9MEA1kvZz9nofOEybup)1mtnJmzBFF9YLo(BMFHJD8Q9Z2(Gs22tFJ7zkFeg4f4AGxbjlP9IOduXJLsdFQX6q(7kWfuVTu5A2EqDZOmtzPQ4yojvgR3AUzW(GZLB6yd6mXzAbgwQkmX66K4YnhQxN8zngLQGgn9Uq9snbvzz8)trvsxrajt(7Y7qZA0eaB6qEWH8G3FZdUgWVGp5Gp59wFY1b(f4xGF7T8RkWVa)c8BFKFt38dzVZAtUvAcuVjBLEl(MST8kMNZgLiKAHTVO)SrjQDX6x)ZuNS3jkDY6PsD4h(IT3jQSVdyULzACZLCc3mfmEJOvCJsqVzp6JV7)amdWS3ZygcWmaZamRlXm6D9x1K1YC(X4orR0E3EcMJ1dm0X2SGPoTlqQ6pSxkf7xLWdRjmswed7P4S6jtg)OczduTzMvOtxq15RT4y6crAThH91MzhLFyI71CN2IHZTyYuzByQLhwn1elpJKFSNB6pGFb(f43(c)kb87BD(L5CLZZTZ9eKBALhd87By(vb4xW(ly)T3YVm20FaadamaW9gaUe)o4453bVW87zFdp0kzla(Lq6njq5rAnSfbSmn6ST)NSISKI4lcTZ8m8UDUFtTxbyQk00ggGfSxzFNuS(b8oRfIZLAibfnvbbzDbjnDDnYA)xPWcP4KQbiagXbJ4Gr8ERrCzGFb(f43El)Ia(fYInKf7El)Qc8ly)fS)2B5xDGFb(f43(BsSbhObaga4EjaxAp7jLSN9KO2ZEAV93ZE0lO8Fbp3IOwY9VjpYIoOZGkMBMbwsCNYnWqLTub9wy4ao8J6)7zpaZam79fMHamdWmaZ6smRYj1hI5Bn1AFnm3my2pFdW8cecznXhY91LYj7nCoRWOlgbivOL1hCBtHwwtqqS4J88t8U)9xoZy7)6j8K6d4xGFb(TxYVnVP9EzX096ns(kxhVLBM)fBpVsR14wcTLwWXYD2cowxtSpG0mfizW1LsC7(KX3YccuanCsJ01K(RYz63Xntmtj)6M5tCUZdZYKQ5rDKcj1ziUKUIKH4l2IFI(iLH3m5qrWvoHA2Rxk58pwlyopFW(l4vEdbcoNdoNdoN3lnzl(oW58bEb3(Wr7DE3DAakkHKfKbh0bh0F1PDbWCnyUgmx3Bby5(S5AUHAFiMS7UOTrsgibWInyX(1g4r9yGF09(bHoBMFTTR)B4KNlAiiROcWoa7V2WUAL3opuDbfz9Hrr4VQRTxE15VCDEg3v2fVFEEvoeF3l77z4xBnVBOLN28oox6mK6A)kctutN)RPN8dv)6pTIguJIqTNn)Tpz6CZI9Rq213ZJQiE166pBIQEitJQlN7cfoBF1fnK10v00nuf0mWnO39bfPkNTV1H0f33IqW7qW7qW79sZ7A9VPh)cNhdcT9C)zYRCVPRcwhFCtqEh6gVOQam94W0J)2DJoI6dhoHL2OaVppnNo9BFK()r3u1tXR998UQNCQPP(lbM9)zV7MCAyyGWWWNiKIJTZpBrIEa6kydsfPccHecX9Fb7OT2JB(P2nDsFpdnpzYm1J)GzWmcNqygmBDZmZkKzp99V7(yF0n7()y7rWwwW2HoN7C2M6jRVeltE8t7Nq0ZiRnnvwNX076782QoB9RV)GZnjRndQNvp2rzpKiL9kDzppmdMbZknZAHzWmywXBIZGZWz4Ss7SEygmdMv8Yzm7FCgoR8oRcNHZWzL2zoygmdMvsMfEN92YMoWMom8MomukkYcoi7L0N28WTilB3Qql0MomLfxCocDKhNC1LvtYpOD4x)WCA600vkJB0GuoS(YQEHgcFP4exWbXksjlKCURzeQ)s9xQ)QY6V1u)L6Vu)vT1FT4x8l(vT(1Z3pZ3pZ3pRXVFoEV9B8AyV9jshjshjGIHzWmygbummdMPLakM8jMMfhZ16y6l5vAvusljglx6MhVKd7a(f)IFvPFT4x8l(vJ(vyyTo9nS2z130nFpWZOfQIC((Vn6noCegIT9g0KFo74DOjse2aCuhY6FyTWmy26Iz1WmygmRKm7cgw7ahzVWVX9khoFrm7aRg5b1tQjRICq9M5XYlU7rH3pCgte0qyYSFi953zKhNfPwFftIQW30FuhJPo6CxPUfpQT2WgfLlhf)(kXK3r4j5NJEj1LpxwOkufQUCu1cvHQq1BCQgpTvtLnyCRgg3knOsdQx35arMwXnue3qr3lzAvERMT9ZFsh1o5LAgpf0esFNQ2(LU(2gFDBBJ37TDvT2gJDOK35TL(pyKRmDk5rjVIxYJ8ScMbZipRGzWmYZkygmdMDFE6p3U7R96zqj)XENl92MarrH)50vvINdWYqQS6M(qjvQnBsiPbxBvRyjBNw5n8BVGtAemCNHzmg8aCwx1e)GV5CZvNZzgLlkX3pWXbRkb36vq0dIE4wVcCg4mCRxbodCg4mCRxbmdy2a)wVY24QTFENel3VZunSGHu43cDeC7C(Skno7)D6mDNg0GnNfSsKM79BsmwGlNlz5y1n4SkvaE3wY3evPmVWKaR7ty6CDB47iGQavbQoeq16xMg8Fa3CIs6GyfDKT5KXgQib4zTV(vRuNi(sM4rbbp0WHZsYkJY3YgIQNQFidpOEsYSB9jormkwUSOgD8IKEtOqQd28LPbKAHulKAnDPwBBWQGvbRoiy1kOAC7hloUNhl(Bl)v6M3Tnlz2ZB2xZAosMr(T(Z)WVJB)S)PU8tFZYk(o2b9Y4YkoZ)zze6yzhEXjpmcgHUPItv)zOBF)Aeazzildz5HGSShqvGQavhcOQdwSmwSmwS8GDXYVALqO1cTwO1A4ATHavbQcuDiGQmGQavbQA4OALYC9qoDzm(UC1AqxMRd4ibCmgEFcMsGkHdPXyumqcEddygWmGzN)YCT491S7(6Q73NU5UlVF7U830Te52UB)Q0xiIxEGpl5lpTAFwYNw(O(zEtPEl5Y15JB8Zx)4wy)LeRlfgkT)sSmU(lP8JspqvDjh(RhM557y7WSTyrbmhFM1TZFVVl3flGqGm(IRuRjtCy(bUTRitI1787wqTZywUE22rErH(UwHUoufEYdsl8eQJa1SKt4VeyjHtZQByHckuqhZkOHaZaMbmBI0nSaZaMnMXSaGzaZaMD(7g2XXAxUEXY0vpMLSEEwYUfPzjxv8IjD9ZB7TLWWMoLiRYBEX21XZY900kr0hKZTOPZ7Ix4xzepkx)OQJERlrq)e6Nq)CQuZSGZaNnQ5mlWzGZaNnrQzwGzaZgRygFnZg0ySfPXVwgvrkhAREufJxL)WFoK8YgvUU4F4V3V5XcSP8(ui8elL)TRu)hEDw9F4y5zvSKgsZCx3i21SdSg26U6Pk1S0TySHmsJKPORbtEl3j38yapRxY92AeCrvSVTCZG3DM7wA6olh)bb27MkhckN5GJT1A7eYNkKYsEtxJ9)46ID1g)CbX)7wJ7UDgU756WS0SVFK(uYjR3FQE6a5PUCNd0CY1voMZ0hRDZ4kFZMyR)OBX3k(uTZKOV25Y60c29HST(ZZkVscQpenr6UQYM8pwwDmIYQdtirAAHqf1GvpWwAw8T88BFNKY2PwRcb3ttMNlv7fXugXpfbVu43(3iHwBi9LkRblOPsMEtLtFyT0FeK6v1BlN2oBor35c5AdtUUzG940O1zuAixBOY1dE(9I8FIpTll5dPZtFQ4jon6u3(t621o0VFOD(JW0AyDv2RM(ZMJDOzq8U1GC(8l(t(lOdBs)75)Nw0Uj0D7smp0ddOFKi))yVZMDBAGOOWpoSQs2J)FjHcieGALOcyzdfxHLAtq2jTQB6ZooojK4Xxp)y7j2t7zjSOus83CV3JVZ5Gg0h(g09TsXZpp7HYV6E(6TlK8e(LLf6ZG05q68PH05mBVx(sCFrvr(VubF9OtEdwINff4Iw5rR8JER8sTSq5NPpeT23p38U(kYCz(YvL))NY1xMeJX76WytPOXPnp3wSuE0d4jztzADoLxzf27K9Ptm81)RWQl2RTPcpY9Y)X1Bw5T5l2s4VDXnzv6195sOVyQ(M2IdddsMIn2t8WIkD33(G6Il))QVnEvlHQ16rq0f2HQBIvVJHx3gEDB41TzJ9SxZ7I928hzbrCMxS3037I53O)j)nir6THOx2Y4SbYmag6BksNSccYBtc1zCd5niPXDAH)oK0bxEyGD3dGzaZaM1tmJbmdygWmtIz8xAYkKtPP0vKlhF9IRrLk(UGpbJqoQIcrngnHaGhl)B9HBfQdult(qXe7fLaA(WnDEJKjIlkIeTCMGFb)c(1k5xpWVGFb)AJ8lLATE2NAT91ryTmtbYk891HE4yEnmiN7LBk)HCKxzssOzO5yJQ1cmdy2llmJbmdygWmtIz9qT2P9g)1aZeV7UkoLLr26NESz(e3LV6NpOU)1P8L4Rn3RRvjfOM9LAeqrzuEBBLZjACXJMRvJDX9N6U)vADtBCbQcufOQnGQEavbQcuDIJQnLB11HXj3ASUYTUk7USvpT)3XVNL(yQIHY1vxCj)OQZ6XIfnRgiF1Y138NDbS17wwC)sbPR1lRvnA88z9dEOxGJxyZT0)mQj56KJ63bdRx9PzvkDTepFl5800rSfxvHTh3jDaxsQBlFhIva0cxbqBk6d6sCrmGIhrDah1caQ9PkJQ2T7b)HdZQxq8RlxU42SnpiFAkdQxit(ISmOBOFSBZSum03skdgL4ee75heNeh7e4kRm4VgWYGv9gQ3RSe3Weu3d19mEDVyGzaZaMzAmlaygWmGzMgZIaMbmdyMPXm3tLyjfRE6U0DwIvAw(Zxx(pEhel5BRHwjJGwjbIudOtpLsFSBhyYEUHCAlMshU0ZChF5QjJMGsHOuikfA8sHWIoaNboZ8CMd4mWzGZmnN5dmdygWmtIz83HPOA(t8SUKjb1wZ6zd6AwZV9YePrq5hUvPrWNwC76cnZHGz18N8lQ(7AzlMjF2B3jeQMgWSe)i)Xlnc(qSB5VaXbrXjHorjL)2E7zbEh9Tz1h98PYc)cbF8oBZeA2fT4qgCry17lkkFYmB(D8R9R6HyGcUNHWhGN4jreVwmrXQBz57(itMRh32xc7oTibxjdCLm2)GJyZVbxid1VqgMisX80mVbKwq)0dPLmzE5pWF39efAxLCxJf3iSOKiNKPuWcvRSDaj4ASqfswmJnPD3kLkRPiGZFYOM5kIwGEGuq3CosxFdh4ZZtNFF58ORZlw1Nefs)o21KZ9982CNDAVmTcbrXaxnNi7zAC6or)6hYky5LVB51RknNA0lQse(Js9Zaujzt0k7sK60DTzpHcCqqItJ5pWwS9fa)laDGJoWTIoWDLPOMW46F)3edxbzPAOTPF7htN)qA(BkE(6Fmp)VANF3NwH08s8s8zNKSbRzwCPydECYKXRrkPMo10itHYTcfit9C(v5cXn(46FS3zZUTnmqq4xN2B2s(3Rfi3kqp0l5ykkCbcIHDGRtlApKN96AahdrUKIuslnPY3JGb8hhUdxnJoLiM1jo(GBN2h6ru6ERvtRPDNUGlFUOEmoh1wK12UhIq(x(92NEC3RpCca393)07z1RtHw)1neC(YQQvjnAQfokSX)9whSv7(Y0JMNHyQ00EdHoYSs33iW9PbqJTcGNv(UYD333(4Z)CZRp8HVUF73o8XHG41AQ9vZNUmBnNBnMZn6nNRQn5981BoJPb28JJrpnqec8sgMnehbCEeHzbpIG)RsNvJkmj(bfKL9hXdiyE6PRrHDoiWApAtUg7Fcw0HfDyrxjyr3QyKND6WqphaVVc1xVq(NFzN5fYB9H0(KT1hkT1BNUm(QK4vNegg86LE2bodLyjJzJBG73Tw01(LsC5MXvXgrhLtK)CtjB)rnh18CxnxifI9w5BzsUUz9jjm(6iNBsWcK3fIJXNvKEnIth6NOHTlQQllmZ9NvdywcZVJH6d(YUcYUHFXxgyUjNzEwrjw5BOMHA2yvntSY3A8qUXSCxk8KoTUDxnaQq2VA9FLg3pmBpFcg7jbLF8eR2L(YSFPCzPfPyhZ9j8KO3GnJ27VhP3GPXe9Y6soSYWNxEH(GmGQGQGQLaQwdQcQcQM5OQuLVn3RDR1KNpfyE(KhZD2jJeeTKq6mTHCa1wdt1ombBu(arlTbMbMPoMryRcMbMPoMr5RbNbNPpNr5RbMbMPoMr5RbMbMPoMr5RbMbMP)WzSYzSYzSYzAVa10FAOMHAM(Qz0RtWzWz6Zz80zWzWzQZz0FAGzGzQIz(7pnwDzwDzwDz(GGavbvbv7oQol80xkDTEKusmT)xBoC4ecEoLQ()9fVqH(z5atr1HnFKtyyNhyksjDKMNw0XDirjaXnODpTuQ5LoVioK15ICRbFEazsLXXJbEA7BhVgr(hJulsTi1MPsTlavbvbvlMptEUvm3kMBfxA3k2(BNVA5eNF78MMmpnY6dY9PzDogILuS7iMhIKDcy8HVOa7t9Yya1beCUnzzRKh3QnscVzEDrWjkCX7K4SZJMLv(c8kHHRLpO1)f8l8l8B(WVvWVWVWVfl)Ua(f(f(Ty53A4x4x43SJF)h7DV1BAddfha)t0K89l7rwxK2dBfTH22tTek0vK2Gkw3M2l8zFbcxsCCUqeEqG)VuvjufPj(NDS954td8RNf(sz7EhAKxMvpK2uBmUclOi5IU5AJo8osXdHcMbMbMDLuJEaZaZUuzw91OhmBrmBrmBXUYQ9GODa(f(fRwl8l8l87PE1ALDIs8dk1ZOupFjxQNvGzGzGzOIQdMbM15zgfmdmdml0mZaMbMbMfAMjbZaZaZcnZ0GzGzGzbFUzyYzWzWzb3zwWmWmWSGpCgwsF4m4SW7mcCgCgCwODMamdmdm70Mpr4es(C(es23rCCJpFKRlYLXjKmkXpGQGQGQhJdZCqvqvq1ZyQ6lHGmojeKgjeeMGkMGksiOwvcHbZ8XSZJAcTBl0skW35BMFmfulQKZUkRqxfD)JVPkQO6Fo(hppDX0hwoCW8F9Wt7fvphr17OkkQ6CUaRV9T(JmmLuWjctYpfCL5UhFLuC0gdB9JH3DtY7jjS7FNQSx6fAl2QxmPfJQDGLK9ifHlOuRWAKCIHZsUrjevi3r5LlJxYieU4SYEFYd1rxwHTggqedi2fhq0aMbMbMfAMjbZaZaZcnZ0GzGzGzHMz1p3SvngIUFq8IVnPHulDNToT7lWNEkE88)SC4xMVy8RxoSF80zxlR4sZ2QG13aJuAHsQmwJHzL00LDHVF)ppwl7I0ylytAj2CWT9Biel0YpWRBslwDNdBJfCxiLC0RtMBsyyrmSyNCyrcCgCgCwWDgdododol0otaMbMbMfsM5MBs0tsYjnktyuVO6dF(Gfj17Ug2gv1VeOIUqllXcEIG6I9huwW5M9kZTwl4joS3FJYFNTLgr4(I99QIE6YIN56dHA)1CH83gRsPzdy7I9iLPnG3sTqL)fhuFtUr2E(HaQmJhSGQGQGQDbQMp5K6vBjmQ8)72813RfPQuKIZyAcXq5CUsQvBw38TPVuKXQPgTwi4kRrzSPHZ4bc83ol5k85vrm6hN(4lf2(I93WkG9DbA56kQ0DFW28cH0GB7N(Ip7KU3x)D3s7lKeQL)FH((tAR04hvBPmgj5rIIts(L1BKHC9JcHKrzkkrz1kMurw9j6vpk80Tr2Ejy(HDXDXitFhoJuuBgF91QsajFTCpp6fXZ(M42HrXDqS)3J)7Kf3)M4F(sYSJ8ULHPn8oGkGL7OEE29eNV2n9IiRTxe)Jbe6mDSjDl8(PZgVC4nt(98KPxUix3c7Bs)p27SB32ghik8RKif1F7DRVylkW2TlsXgaFNLRvceIRmGCCx4EHF2RSCBQn1W)efLOCNBkqbcAdS13mNzeph(2J0kRneo0xsA)6WwNesdOJUvi5BKSuGmaA3gbsKfSWsRqYRGul)g6nUJufU3PqVqnr8Yf5)7A7kxr5mab1YJA5rT8ZbT8eJ6cdlJWsT8nceJIJins4BAvLLgXsOxei2E6yGv53ha)F39)f1Nw9(QNoS)CDOR7ARK3hr58Kgf0Jd8dlKgo3cOYB(kTRTyDM9i(c4ALa0FMnFsVaHfb5MHbQMOaLMDPl4XVKmYwnuxEzA5Jv1WFsUtJnP4a3Hv8d5BAPedg4FnxfIi3jQpmIfNO9vH8qiZxwozyqhQFQxauVxVfrSuMa37VRh5o9a4vtl8U8EOf6ZMWr4TvU)fG)4z9a7BPoRKd4Yj4JYsjt1Y9GgOX05dOQKhiuWVQgJe56bWbdGwUIMdgqNXS9J7k380U6Vy9I5YCgwtYyuwMSfZ19joPmXTOSiGxd8MV2hy3eU(5qqPyEVBvlogwl0HNUnO7U7HFbfenb0bsfo5ZF1zUT3WE5Baia3whUToCBDZHT1LIOkIQiQohq1KP)qYyl4E5TC)xBZp(hTJjNxv(6rBodmoCk5mclGmQVN7EkNgAN6soClb6mSSYncDFnKSKYE692ja7kcuDwRC)T9u(tcyC5(B6Co3FrZFGM)yo6XQ4zwGK(7ccPobs94uZUtrZjm0SHQfXJq9k3wMJ5(l2nd7MDx7mFc2odBNHTZCD7SueZqmdXmxJzriMHygIzUgZsqmdXmeZCnMPBQ9YBwgRqU9VECBXpo)QTuXPvFSA7XtR(q5gTqVf3GEVVEx1thQhWu5nD4sL3Em(TDq56bAril(Zh0lsEjz0GuITxfsY)4qCb6LMuTtwQ(MKfeLgYIohHXbreOu9DT4u9L4(ldjroxXFYYxSzj2S8UUzjf5mKZqoZ5CwaYziNHCMR5mgIziMHyMlXm)ilFLfRa8NaxNy8bXEYE4m(G7YbmERlahTiKUh0EPNc61wMdyW8UatqmTH(1WeqaWnMeyfazr9a)H233ZYxHjHGCwvhRcpD(usavcAca1Ucg47wEYvWdkGz6bSDWvaYI80SXzZP)7j4Lw5jyvL94dkjbwcETrb8la)6XX6XH6Vw(18TTgw61YQp)6EZs2d(y8H5mplftcp)t41b7HcF(3B6UdlOfEdXWEJvMgal)BGfMSWzIrthDBBkD1WjvFRSyZPvpu8CrvXp(D2tbCknLrhhZgFZ3(cEwzs0ARLa2oOJ3P)wjxVSpzxKEj43mj)DXrLXrLXrLnDu5wuvlXpYJutpm(aEx(2Z)p85tRE3H86nL5v2KDa2eNMbYBttctcs1oonTTZD38znjiMXA(JO4W0Oak7YnvYBFzcMFRzceSd)8lxOdCD5)u1roG5Q45RJkOGX1XJHPYX7r6B(Z6tYJslW278dwRmnb47HD1ZYFS9Z1)HzuaImRKP)Pdvn)Jww9CJo9D512Pp3DHgcHgfMKLnkKpNcDJh0ZQU)QBX)Bwe6AJc9UKCOlst3zfWViV(L9Vu6ZtItWjXXjXh7jXPZ3fP)3hQYRpTArr(x81(30awqC80jCx)OXwNX0gVDSRR6CrxpEJGeDRY)VHyd6D7Yt9YC0f36gU1nCRBMU1T05Ru7)REFZxRNw9y5Z7Q9v92Hjj4R(cfCp(cUJNXZqxuVVO(fFvSDuq45lwnCvz4QYSyvzeRX8BYE32FJPXPCzVBSpM9U3AwJED459EhD0hxl4IemCo50dl8EVX26GZFm8o6G3bry27E37jk)iRp7v8wastqfhgscQdtd5kQlLa)o7DT1BJIdf(p0wjUziSV1M0UtL2sRgIwP5LoHMsMGgAYOeYMY8q(Tp2gCIXytCAUs15P0cyJT58DUz7pRDhPnY9UG1mWA2NzRza37cMZaZzhFZza37cWmaMD0Hza37cWmaMD0Hza37cWmaMD0HzAeBwwsAswoB2H(VK4LXAs(U9F8P97KiQbc39Fjvx8Svd6poAYQbxN0a37EGrGDUO5E3tgOC98z6447A4xdLEL1EIe3fA1Tgq6yqHtvngOfT6wmpFBfukfJb8QlyiemeEQmec89jGZaC2XhNb8xnGZaC2rhNb8QlaZay2rfMjNxD1Jbs0dy2ojZZd7YMExiUZgxHTBNap1CRjkBPKZV8DLSleLSfDuV6PvSu3LblyRn)lF268KrNF7bzD6d4xa)c43wl(Toz7EEHP70Ewkf3uNUiB1GUtF7LPvMmdnXTNkUcWQdY1UnaSLQMCp5iG6Bhlby9Ne21UnG3rxk0eG(2J7gNgpplHWQ23mlE5f7Uo2Ycz4Do2JIIshBJD5G9O4Pzpkk3YPM7ar9PFanyJxWbDWbDWb9wPbBZwSd63nDwwYOCkvCwZ09hXdDNJiBCA4JCap0bp0p7aEdWInyXgSy3AbWoTVqSVFY)J7zRgeKS43rt)RvdYghtNW2H)C1GhF)snKBtBlKxhiKBiK7lPqUTAXEShoEXOrPXxYPs3e545doQdoQFUTZ72IX5C5u)(jJwmx8CS7sl4Chtd0NwqVmzsaYVBqEjko3QpzFKJVYoqW5qW5qW5TwJ2Ea(fWVa(TnIFLW9UixbU31En37kUsZbGpa81a43SV4aSF)C8EFNhCa)c4xa)2kXVoa(fWVa(T1IFHnQjGFb8B7f)6c4xa)c432i(TsIVSFU8sZIgMeLoVBVhOi745z4FdmTS960blfIhcWLg)eyjkxlFVQxXa5zv9kixFhm8618jrVLm85ahBxBhNkpJnzEynfkgY1PsDNTUo6pg)DymwuIk5HVE2SKj)moJ1K5PEYeIULc6O4hfZMSv5F9005ju5QWBd6HhiiRjT0KYolc3ECXvGQxA4BuLw3(Wn32R3T94ANHCVXKjdtx8A8trZNxQSkkd)rA8ZH9(wW1pCF3NdxuW2G8L67zls6x0JEi5hevE0Uc(lfPZLruCH)DyjwQXL3e7HQlaZFNnc8IGu2tjalzxMxaNVcRlFYUlN4Cg97WsmIjSYASsGSgBKjhfWiUKPYNYin0EefiY4MgRAQzVY02SrSXqcZJGh2PgOeKRW2dOza2RGQ6sNIF(WB7(yqVR)63if21sXnSCDvDhKQY46O4gMg2QkIY3IRNQkZXZwzHSv2cu2rr(kRnL3bzOSmQVdszTP8ofhUEs7pshRlb8bFPFrXnvog2Xq5TuoYBHuuFeqs0VOy6Lcmc17BJgFkvC1TukMi2MZkd7KkIOPpmlpnMDQcs)9FItMTAqPcNpaR9uZrVZlzmDGoYN2r6wAunnRQzrRTrTvISSLEmSBnVN0HBUei1jE(EsKpNK5nzncBsTtl4xm2xUxWM2bPSp3sznqAy1fap8szfJaRg84K08vdEi51gf4AfNcA3C9xBmEGd45zNC5AECKijbwBI4LZN8ImhiVC0lke2gjp6xoXToCIBVuxDMguxoVWxniqvjpjRn3Qur3gfCFSmKOik71r2DkwDVnh5SMPhrZSmWNveP5arEG67W(TripfBjM6gZVJykruMigPzE63vnYYsRHSCxOXooABjKqmBj1YhHmT46TdE0yf800ECIcyEnEu0I0SnEHYqoSKuegNHdEVAqy)A6Y4z9Ijruh)6xyCkkPZqE450a5PUvxgSwwDNOl(8sFWIQJo6Yc8JUSFgooA2pIP)h(B(WO5zK)gxxVLmPG8uPFIk9sNZdB5XZoHgOzzVR8r6pT88549khwffoJZEJv775BJByR0tnRw1BILHRbWkOYK9wm(SpndJdrZOmQL)MDGPW1AKxMdCdlVskm2iDC2hywl1QzlHjrUZTKQzFPSLqSJE33FknkV40YG7ZK1E8zQE)xrZtSxKlAsw44RPAJNL9UAN6hbwLQKk0VqrKLkkmr000MXR)PaXUw9b2BKSAG8DwNtfj(aKWyBG7bqRetfzGfQdE0jGKvhA2pluxzTAq4nnlPWuxjtlrtLtbFxNRj3xtl3DZM(wPNXV8HrpsvZ2Kw0lLwoN0GDdy)LszuCnqwnGlpEQNpm4ELQNvjrE3vEKPWa57yy75B1X355rxHCVGetLRKVnGW(SyrWM3NYaptI(spRcTMofAn1tJ)gL8286)LPXFVvW3SzkJnQ6n3MQ()0ExT902(aX)eXKJDStYlBgRBi1PvbmT9QXcTbr16iO0uy8M9z)VpBNe74hAkG(p6gsivuC9JNVF31C)o7dFO(aqu)bam3xiQxugnpCrJoyT3)eqUIT9LTheaJA1nKocYiaKgJja2GidMdpKk)Gj)irwO8Ze0(a(9h1DxjuN89b)2rI2D46G4lfC6Jp5Sj5Za2s88dwB3I71pR9vW6dkxh3dH2yNQJ)D(8eaGP(Fzcyd0xGxhhwGP0F)9CXlU9vS0dyFEFfg9F0Fb())BcE8WOaSOmoNkwok2nLlfjq0LoFLkutxDDZx9mSRlLvtlOKtzeeHssWiwebNqyW7(HaHXAkfJtsqPim)pwAAeucebqEjXKmwmokIs5vlHPk5sEj0i(3NLgfriy4s5wuI)R4VMvAHrZ)HVOZf5rF0n6XiPMq0jjbGLgkIKrsqzXXuU1Q2Lg7UayOQDucDsEsbu02nLYWHnR4HQTnD3T8IdOjeYvm31oVPecrOBLCxmuJHPm6GdLUvLRxcb)VAXpC0poOQHqMNMqZYIjekdhLrYAxmuu3qJQFw8uXE4bJCCOrUX80ZAr7svt76Vki1yBvxyxMYiF0GWgp7tFrz2hlBfhXe3I)etAQRwSQ5HDKUdc1siY3sTs9qr3gZ)iM9Ls5VEpmCqI6Og1yK8n7UMlCkRBzXnWIetenfZQpzr1nZlwUSLMjflwa8DFAvT6IEVLussglm52BxVs2aI1gr)dXuUJG3dBqv)OZpCUBcI4GjvZmgwG8bKKnUldAxy6uSEo4OrUPzMlvINydOSUM8CFnCRVCngRkQ1tskqRg(wDxvCeSV2i(FYHWadefnlUEagVQLe(02z65ioIB3K5TCxeZTSY26uQ50xnP(0DL1xTU6(oxirQzMwBz39bNI6ZJnf3vUuopMY1VZO4iCm)FyrOuocGiNgCyq9ifMWLBV6QCL)V7IgsUp6vdtLrpwvKCS)4vC7DYSD4ZZ9fdWXCVMQryRHwVT220nbiz209YcAm4vrA84joNt5PqspGlyYVO2ky31sl1pv5sdrvo784kyiYl22uDwzZKTlxvXX3V5MY1cVwQHHb)b2xbUDLmztE3a0Okdf)DWwFeiHemnEGJFqbNHeLFR5EadWOfl)5jTezRKJlb5bXmWszUEE5OXVjHvhfCQcDbeC9PSIa4TLcvzHZpf(3Txd4n0az8YuUtwz4SugJ7HcoJH6ThJ0ZcgdwycTVwQG4p3xS0i2SJuUH3WUibMSUoOpLb5OevF3hlZBmxAKplCV670tcs(RCnHJd5GNQlAAZ1WUEZPiw5vcZaRyCjoKj2xJdCnzrV74l(GCdiStvNyIdidk3FCt0myN(8Y6tRUNdyHKpOLuzWU41DTNu7aWZb1dxkadW)WMTgj2qfHeBos8OUaji3y1xokAptqSb1ux3anovJq7F6bHLKO1snAAmymLBiLLLW4UPl0GtgEmA)e1uOb3n7EF6avKq7udQPzQQGS1us9MSDEXn015f23maVn2U(O0wgNHuUVpdSKE5aLPiCWu7ZR5Y8jNE27o)ZZVa6tGBWG75BRluCYnV)jGJFCRQcnpUnv5absg0(FgGpZuD6Kyx(gQRLsD4XGhv10xow2E(mSP)d4)l3uwuq9ttsGVJuK1hyJBNeAmTe8SP12QX5wXTh8N4WoOjqYUCXnWlTR5BF7)o]==] },
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
    if provider == "BLIZZARD" then
        if hasDetails then C_AddOns.DisableAddOn("Details", E.myguid) end
        print("|cFF8080FFthingsUI|r - Ingame Damage Meter selected" .. (hasDetails and ", Details! disabled." or ".") .. " |cFFFFFF00Reload required.|r")
    else
        if hasDetails then C_AddOns.EnableAddOn("Details", E.myguid) end
        print("|cFF8080FFthingsUI|r - Details! selected" .. (hasDetails and "." or " |cFFFF6060(not installed)|r.") .. " |cFFFFFF00Reload required.|r")
    end
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
            f.Desc1:SetText("Pick your damage meter. Details! gets anchored inside ElvUI's right chat panel; the Ingame meter is Blizzard's new built-in one.")
            f.Desc2:SetText(hasDetails and "Picking the Ingame meter disables the Details! addon." or "|cFFFF6060Details! is not installed - the Ingame meter is your option.|r")
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
            f.Option2:Show(); f.Option2:Enable(); f.Option2:SetText("Ingame Damage Meter")
            f.Option2:SetScript("OnClick", function()
                ns.SetDamageMeterProvider("BLIZZARD")
                StepDone("Ingame meter - reload after finishing")
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
