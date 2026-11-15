# Troubleshooting

### "Koi Android TV nahi mila"
- TV par **USB debugging** ON hai? (Xiaomi par "ADB debugging" bhi)
- TV par aaya "Allow USB debugging?" box -> **Always allow from this computer** + OK
- PC aur TV **ek hi Wi-Fi** par? (guest network par nahi)
- Router par **AP/client isolation** band karo
- IP pata ho to: `setup.bat 192.168.1.50`

### Connection bich-bich mein toot jata hai
TV ka Wi-Fi power saving. TV par ek baar YouTube chala ke wapas Home aao, ya `setup.bat` dobara chalao.
Script backup pehle hi le leta hai, dobara chalane se kuch kharab nahi hota.

### Home screen purana hi hai
- `setup.bat` dobara chalao (launcher step wapas chalega), ya
- remote se Home dabao / TV restart karo

### Koi app nahi khul raha
`restore.bat` chalao - sab wapas. Phir `lists\<brand>.txt` se shakki line hata ke dobara try karo.

### TV Settings nahi khul raha / keyboard nahi aa raha
Script settings, keyboard (IME) aur setup wizard ko kabhi disable nahi karta. Fir bhi aisa ho to
`restore.bat`, ya TV par: Settings -> Apps -> system apps dikhao -> app -> **Enable**.

### Play Store "authentication required" bolta hai
Kuch TVs par Play Store ka sign-in panel launcher ke recommendations par depend karta hai. `restore.bat`
chalao, sign-in karo, phir `setup.bat` dobara chalao.

### Firmware update nahi aa raha
Xiaomi list mein update service by default **comment** hai. Chahiye to `lists\xiaomi.txt` mein
`com.xiaomi.mitv.updateservice` ki line ka `#` hata do, ya adb se:
```
adb shell pm enable --user 0 com.xiaomi.mitv.updateservice
```

### "pm disable-user" fail ho raha hai
Kuch brands (realme/OPPO jaisa) `disable-user` block karte hain. Script us package ko chhod deti hai
aur "fail" dikhati hai - TV par koi asar nahi padta.

### Windows PowerShell script block
`setup.bat` already `-ExecutionPolicy Bypass` ke saath chalta hai. Manually chalane par:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```
