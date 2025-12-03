Trend Micro Endpoint Sensor – Automated Uninstall Script

Een PowerShell-script voor het geautomatiseerd verwijderen van de Trend Micro Endpoint Sensor (V1ES), bedoeld voor gebruik in Microsoft Intune bij het offboarding-proces.
Dit script downloadt automatisch de officiële V1ESUninstallTool.zip vanuit jouw eigen OneDrive/SharePoint-omgeving, valideert de bestanden, en voert de uninstaller volledig silent uit met het juiste tokenbestand.

✨ Functionaliteit

Het PowerShell-script doet het volgende:
- Controleert of het script wordt uitgevoerd met administrator-rechten
- Downloadt automatisch de V1ESUninstallTool.zip vanaf een door jou ingestelde URL
- Verifieert of benodigde PowerShell-cmdlets aanwezig zijn (Invoke-WebRequest, Expand-Archive)
- Forceert TLS 1.2 (vereist voor OneDrive / SharePoint downloads)
- Extraheert de ZIP in %TEMP%

Detecteert automatisch:
- V1ESUninstall*.exe
- V1ESUninstallToken*.txt
- Controleert optioneel de Authenticode-handtekening

Voert de uninstaller silent uit:
- V1ESUninstall.exe /tokenfile:<token> /silent

Schrijft alle logging weg naar:
%APPDATA%\Trend Micro\V1ES\v1es_uninstall.log


Verwijdert na afloop alle tijdelijke bestanden

Perfect inzetbaar voor:
- Offboarding via Intune (Win32 app of remediation script)

⚙️ Configuratie

Open het script en wijzig de volgende variabele naar de directe download-link van jouw eigen .zip bestand:

$UninstallZipUrl = "https://<tenant>.sharepoint.com/...&download=1"


Let op:
- De URL moet eindigen op &download=1
- Gebruik het directe OneDrive/SharePoint download-adres
- Het ZIP-bestand moet de officiële V1ES-uninstaller bevatten

▶️ Handmatig uitvoeren
Start een verhoogde PowerShell:
powershell.exe -ExecutionPolicy Bypass -File .\UninstallSensor.ps1

🛠️ Inzet via Intune (Win32 app)
- Download dit script
- Pas de OneDrive/SharePoint URL aan
- Maak een map zoals:

UninstallSensor\
    UninstallSensor.ps1

- Converteer deze map naar een .intunewin met IntuneWinAppUtil.exe

  Invoke-WebRequest “https://raw.githubusercontent.com/microsoft/Microsoft-Win32-Content-Prep-Tool/master/IntuneWinAppUtil.exe” -OutFile IntuneWinAppUtil.exe

  IntuneWinAppUtil.exe -c "UninstallSensor" -s "UninstallSensor.ps1" -o .
  UninstallSensor.intunewin

- Upload UninstallSensor.intunewin naar Intune → Apps → Windows → Add → Win32 App
- Gebruik als install command:

powershell.exe -ExecutionPolicy Bypass -File "UninstallSensor.ps1"

- Gebruik als uninstall command, mits nodig, hetzelfde

Detection rule (recommendation):
- Custom detection script dat checkt of het Trend Micro V1ES-proces of service niet meer bestaat, bijv.:

if (-not (Get-Service -Name tmes* -ErrorAction SilentlyContinue)) {
    exit 0
}
exit 1
- Download eventueel het DetectSensor.ps1 script en laad het in bij de Detection gedeelte van Intune

Alle logs worden opgeslagen in:
%APPDATA%\Trend Micro\V1ES\v1es_uninstall.log


Handig voor troubleshooting.

🚧 Bekende Limitaties

- Het script kan alleen werken met de officiële Trend Micro uninstall ZIP.
- Een ongeldige of verlopen OneDrive-link zal een HTTP-fout veroorzaken.



💬 Support

Voor technische vragen over offboarding of Intune-deployment kun je contact opnemen via:

Joris Rooijackers – Security Consultant

Bechtle B.V.

Email: joris.rooijackers@bechtle.com
