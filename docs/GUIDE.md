# Guide - TV par kya karna hai

## 1. Developer options ON karo (ek baar, har TV par alag raasta)

| Brand | Raasta |
|---|---|
| **Xiaomi / Redmi** | Settings -> Device Preferences -> About -> **Build** par 7 baar OK. Phir Settings -> Device Preferences -> **Developer options** -> **USB debugging** ON (aur "ADB debugging" bhi ON) |
| **TCL (Google TV)** | Settings -> System -> About -> **Android TV OS build** par 7 baar OK -> Settings -> System -> **Developer options** -> USB debugging |
| **Sony BRAVIA** | Settings -> Device Preferences -> About -> **Build** 7 baar -> Developer options -> USB debugging |
| **Hisense** | Settings -> System -> About -> **Build** 7 baar -> Developer options -> USB debugging |
| **Philips** | Settings -> Device Preferences -> About -> **Build** 7 baar -> Developer options -> USB debugging |
| **OnePlus TV** | Settings -> System -> About -> **Build** 7 baar -> Developer options -> USB debugging |
| **Google TV / Chromecast** | Settings -> System -> About -> **Android TV OS build** 7 baar -> Developer options -> **Wireless debugging** ON |

## 2. TV aur PC ek hi Wi-Fi par

Wi-Fi alag ho (guest network / 5 GHz alag SSID / extender ka apna network) to TV nahi milega.
Sabse safe: dono ko ek hi router ke same SSID par rakho.

## 3. setup.bat chalao

- Double click `setup.bat`
- Script TV dhoondhega ("found 192.168.x.x"), phir Enter dabane ko bolega
- 2-4 minute - progress dikhta rahega
- Aakhir mein TV par **Home** dabao

## 4. Agar TV na mile

1. TV par USB debugging sach mein ON hai? (toggle off/on karke dekho)
2. TV par "Allow USB debugging?" ka box aaya tha? **Always allow** + OK
3. PC ka firewall adb ko block kar raha ho sakta hai - pehli baar "Allow" karo
4. IP pata hai to seedha do: `setup.bat 192.168.1.50`
5. Router par "AP isolation" / "client isolation" ON hai to band karo

## 5. Wapas purana TV

`restore.bat` - jo bhi disable hua tha, wapas chalu ho jayega (backup se), animations 1x,
purana home screen wapas. TV restart karna.

## 6. Apni brand ki list banana

```powershell
.\scripts\inspect.ps1
```
Isse TV ke saare packages dikhte hain. Jo bekaar lage, `lists\<brand>.txt` mein likho (ek per line),
phir `setup.bat` dobara chalao. Kuch toota to line hata do.

## 7. Manually kuch karna ho

```powershell
.\scripts\setup.ps1 -DryRun           # sirf dikhao, kuch change na karo
.\scripts\setup.ps1 -NoLauncher       # sirf debloat + tuning
.\scripts\setup.ps1 -Compile          # apps ko AOT compile bhi karo (thoda slow, launch fast)
.\scripts\setup.ps1 -TvHost 192.168.1.50
```
