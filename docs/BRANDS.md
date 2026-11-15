# Brands

FastUpTV har Android TV par chalta hai, par **debloat list** brand ke hisaab se hoti hai.

| Brand | List | Status |
|---|---|---|
| Xiaomi / Redmi (PatchWall) | `lists/xiaomi.txt` | **Tested** - Mi TV 4A, Android 9 |
| Google TV / Chromecast | `lists/google.txt` | Template - core list chalti hai |
| TCL | `lists/tcl.txt` | Template |
| Sony BRAVIA | `lists/sony.txt` | Template |
| Hisense | `lists/hisense.txt` | Template |
| Philips | `lists/philips.txt` | Template |
| OnePlus | `lists/oneplus.txt` | Template |
| Nokia / other | `lists/nokia.txt` | Template |

Template ka matlab: sirf **core** list (Google telemetry, ads rows, preloaded Google apps) chalti hai -
jo har Android TV par safe hai. Us brand ka apna bloat add karne ke liye `scripts/inspect.ps1` chalao.

## Nayi brand add karna (PR welcome)

1. `scripts/inspect.ps1` - packages ki list
2. Jo bekaar lage unhe `lists/<brand>.txt` mein daalo, upar comment mein model + Android version likho
3. `setup.bat` chala ke test karo
4. PR bhejo: list file + ye line README ke table mein

## Niyam

- Sirf wahi packages jo **safely** disable ho sakte hain (telemetry, ads, preloaded apps)
- Koi bhi `com.android.*`, keyboard, settings, setup wizard, ya Home owner - **kabhi nahi**
- Har line ke saath comment: kis model/firmware par test hua
