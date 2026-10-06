# OpenUnbloat (v1.0)

Przejrzyste, bezpieczne i w 100% odwracalne narzędzie open-source do usuwania bloatware, wyłączania telemetrii, optymalizacji wydajności oraz konserwacji systemów Windows 11 (w tym 25H2 i 24H2) oraz Windows 10.

Aplikacja łączy natywny, lekki launcher C# z nowoczesnym interfejsem graficznym WPF oraz modułowym silnikiem PowerShell. Nie wymaga instalacji żadnych dodatkowych środowisk ani zależności – działa od razu na świeżym systemie.

---

## ⚡ Szybki start (Quick Start)

1. Pobierz repozytorium (jako ZIP z zakładki **Releases** lub za pomocą `git clone`).
2. Uruchom plik **`OpenUnbloat.exe`** w głównym katalogu (program automatycznie poprosi o uprawnienia administratora).
3. Wybierz jeden z gotowych profili u góry ekranu:
   - **🟢 Profil Zalecany:** bezpieczne usunięcie telemetrii, reklam i zbędnych usług bez ryzyka dla stabilności systemu.
   - **⚡ Profil Gracza:** minimalizacja opóźnień (DPC latency), wyłączenie Game DVR, blokada akceleracji wskaźnika myszy.
   - **🛡️ Profil Prywatność:** odcięcie telemetrii diagnostycznej, wyłączenie asystenta Copilot i funkcji Windows Recall.
   - **🔄 Przywróć Domyślne:** natychmiastowe wycofanie wszystkich wprowadzonych zmian i powrót do ustawień fabrycznych.
4. Kliknij przycisk **Zastosuj wybrane optymalizacje** na dolnym pasku.

> **Wskazówka:** Jeśli chcesz najpierw sprawdzić, jakie operacje zostaną wykonane, zaznacz pole **Tryb symulacji (Dry-Run)** w prawym górnym rogu. Wszystkie planowane kroki zostaną wypisane w Dzienniku Zdarzeń bez wprowadzania jakichkolwiek zmian na dysku czy w rejestrze.

---

## 🎯 Dlaczego powstał ten projekt?

W sieci dostępnych jest wiele skryptów i narzędzi do modyfikacji oraz odchudzania Windowsa. Choć większość z nich ma dobre założenia, w praktyce potrafią spowodować poważne problemy ze stabilnością systemu i działaniem aplikacji.

Tworząc **OpenUnbloat**, przeanalizowaliśmy najczęstsze błędy i awarie zgłaszane przez użytkowników takich rozwiązań, projektując architekturę tak, aby całkowicie wyeliminować typowe wpadki:

| Problem w innych narzędziach | Jak rozwiązano to w OpenUnbloat |
| :--- | :--- |
| **Zawieszanie się podczas usuwania aplikacji:** Próba deinstalacji pakietów UWP przy działających procesach w tle (OneDrive, Widgets, Copilot, Teams) kończy się blokadą plików, błędem `0x80073D02` i zacięciem skryptu w pętli. | Mechanizm *Pre-flight Process Termination* w `Apps.psm1` automatycznie i bezpiecznie zamyka powiązane procesy przed wywołaniem deinstalatora, zapobiegając blokowaniu plików. |
| **Psująca się wyszukiwarka w Menu Start:** Wyłączenie usługi indeksowania `WSearch` lub użycie nieaktualnego klucza `BingSearchEnabled` na Windows 11 (22H2–25H2) powoduje całkowite zablokowanie wpisywania tekstu w polu Start. | Narzędzie stosuje wyłącznie oficjalne zasady Explorer (`DisableSearchBoxSuggestions`), blokując zapytania do wyszukiwarki Bing, ale pozostawiając lokalne wyszukiwanie plików i programów w 100% sprawne. |
| **Powracający bloatware po aktualizacjach:** Usunięcie aplikacji wyłącznie z konta bieżącego użytkownika (`Remove-AppxPackage`) powoduje, że po utworzeniu nowego profilu lub po aktualizacji zbiorczej Windows Update instaluje je ponownie. | Zastosowano dwuetapowe czyszczenie: pakiety są usuwane ze wszystkich kont użytkowników oraz trwale wyrejestrowywane z obrazu instalacyjnego systemu (`Remove-AppxProvisionedPackage`). |
| **Brak odwracalności zmian ("One-Way Street"):** Wiele narzędzi modyfikuje setki kluczy rejestru bez zapamiętania ich stanu i bez procedury powrotnej. Przywrócenie domyślnych ustawień wymaga często reinstalacji systemu. | Każda z 50 reguł w pliku `data/tweaks.json` ma zdefiniowaną symetryczną parę operacji (`apply` i `revert`). Jednym kliknięciem można przywrócić fabryczny stan pojedynczej opcji lub całego systemu. |
| **Uszkodzenia Windows Update i magazynu DISM:** Agresywne playbooki gamingowe wycinają komponenty WinRE lub usługi WU, przez co kolejne łatki bezpieczeństwa kończą się błędem `0x80070643`. | OpenUnbloat optymalizuje Windows Update w bezpieczny sposób (odracza duże roczne kompilacje, blokuje wymuszone restarty podczas pracy), nie naruszając krytycznych plików w `WinSxS`. |
| **Brak odświeżenia zmiennej PATH po instalacji WinGet:** Po cichym zainstalowaniu narzędzi programistycznych czy CLI programy nie są widoczne w konsoli aż do restartu komputera. | Po zakończeniu instalacji moduł `Software.psm1` natychmiast przeładowuje zmienną środowiskową `$env:Path` w bieżącej sesji z gałęzi `Machine` i `User`. |
| **Fałszywe alarmy antywirusowe (False Positives):** Monolityczne pliki wykonywalne modyfikujące plik `hosts` i rejestr są blokowane przez Microsoft Defender i SmartScreen jako malware. | Przejrzysta architektura: lekki natywny launcher C# uruchamia w 100% otwarty, czytelny kod PowerShell. Zero obfuskacji, zero ukrytych pobrań z sieci. |

---

## 🛠️ Moduły i funkcje programu

### 1. Optymalizacje & Prywatność (50 reguł w 10 kategoriach)
* **Sztuczna inteligencja (AI):** Całkowite wyłączenie Microsoft Copilot z paska zadań oraz blokada Windows Recall (cyklicznych zrzutów ekranu AI) i telemetrii AI (zgodność z Win11 24H2/25H2).
* **Prywatność i diagnostyka:** Ograniczenie poziomu telemetrii diagnostycznej do minimum, wyłączenie Customer Experience Improvement Program (CEIP), Device Census oraz śledzenia aplikacji.
* **Ochrona Windows Defender (PUA/PUP):** Włączenie wbudowanego blokowania instalatorów adware, toolbarów i potencjalnie niechcianego oprogramowania.
* **Menu Start i Pasek zadań:** Usunięcie reklam i rekomendacji w menu Start, blokada integracji Bing, wyłączenie widżetów pogody/MSN oraz dodanie opcji "Zakończ zadanie" pod prawym przyciskiem myszy na pasku zadań.
* **Eksplorator i interfejs:** Przywrócenie klasycznego menu kontekstowego Windows 10 w Windows 11 (bez konieczności klikania "Pokaż więcej opcji"), włączenie rozszerzeń znanych typów plików, obsługa długich ścieżek (> 260 znaków) oraz szczegółowe komunikaty uruchamiania/zamykania (Verbose Status).
* **Wydajność i Gry (Gaming):** Wyłączenie nagrywania w tle i nakładki Game DVR (niższy input lag i wyższy 1% low FPS), wyłączenie akceleracji myszy, blokada skrótów klawiszy trwałych (Sticky Keys), aktywacja ukrytego planu zasilania "Najwyższa wydajność" (Ultimate Performance).
* **Aktualizacje Windows Update:** Profil bezpieczny – natychmiastowe instalowanie poprawek bezpieczeństwa przy jednoczesnym odroczeniu dużych rocznych kompilacji funkcjonalnych o 365 dni oraz blokada automatycznego restartu komputera przy zalogowanym użytkowniku.

### 2. Aplikacje Bloatware (42 zbadane pozycje)
* Precyzyjna klasyfikacja na pozycje **Bezpieczne do usunięcia** (reklamy, gry sponsorowane, Cortana, Feedback Hub, Porady, MSN News, pakiety Copilot Provider i WidgetsPlatformRuntime) oraz **Opcjonalne** (Paint, Notatnik, Xbox, Zdjęcia, Kalkulator).
* Wbudowana lista chronionych pakietów (`$script:ProtectedPackages`), uniemożliwiająca przypadkowe usunięcie Microsoft Store, bibliotek C++ VCLibs czy podstawowych bibliotek środowiska wykonawczego.

### 3. Instalator WinGet (26 wyselekcjonowanych programów)
* Katalog najpopularniejszych, bezpiecznych aplikacji podzielonych na kategorie (Przeglądarki, Narzędzia, Multimedia, Komunikacja, Programowanie).
* Błyskawiczna detekcja stanu na żywo: sprawdza obecność programów zainstalowanych tradycyjnie (EXE/MSI) oraz przez WinGet, blokując ponowną instalację istniejącego oprogramowania.

### 4. Konserwacja i Naprawa
* **Czyszczenie dysku:** Bezpieczne usuwanie plików tymczasowych użytkownika i systemu, opróżnianie kosza oraz czyszczenie cache aktualizacji.
* **Resetowanie sieci:** Czyszczenie pamięci podręcznej DNS, reset Winsock i protokołu TCP/IP.
* **Diagnostyka integralności systemu:** Automatyczne wykonanie naprawy obrazu DISM (`/Online /Cleanup-Image /RestoreHealth`) oraz skanowania plików chronionych SFC (`/scannow`).
* **Naprawa Windows Update:** Zatrzymanie usług, usunięcie uszkodzonych plików pobierania z `SoftwareDistribution` i `catroot2` oraz ponowny start usług.
* **Naprawa środowiska WinGet:** Resetowanie oficjalnych źródeł repozytoriów pakietów.
* **Szybki przełącznik bezpiecznego DNS:** Natychmiastowa konfiguracja sprawdzonych serwerów DNS (Cloudflare `1.1.1.1` lub chroniący przed złośliwymi domenami Quad9 `9.9.9.9`) z możliwością natychmiastowego powrotu do domyślnego DHCP dostawcy.
* **Kopia zapasowa rejestru (.reg):** Eksport kluczowych gałęzi systemowych do jednego pliku `.reg` na Pulpit użytkownika.

---

## 💻 Tryb konsolowy (CLI / Bez interfejsu graficznego)

Narzędzie można uruchamiać bezpośrednio w skryptach wdrażania, konfiguracji po instalacji systemu lub przez SSH:

```powershell
# Uruchomienie pełnego okna graficznego:
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -GUI

# Szybki audyt stanu systemu (wyświetla tabelę ze stanem 50 tweaków):
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -Audit

# Zastosowanie zalecanego zestawu zmian w trybie symulacji (Dry-Run):
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -All -DryRun

# Cicha aplikacja zalecanego zestawu optymalizacji (bez pytań):
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -All

# Przywrócenie domyślnych ustawień fabrycznych Windows dla wszystkich tweaków:
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -RevertAll

# Wyczyszczenie dysku i plików tymczasowych:
powershell -ExecutionPolicy Bypass -File .\OpenUnbloat.ps1 -Cleanup
```

---

## 📂 Struktura repozytorium

```text
├── OpenUnbloat.exe           # Skompilowany, natywny launcher C# z ikoną i manifestem UAC
├── OpenUnbloat.ps1           # Główny punkt wejścia (CLI, obsługa parametrów, start GUI)
├── data\
│   ├── tweaks.json           # Baza 50 reguł z definicjami check, apply i revert
│   ├── bloat-apps.json       # Katalog 42 aplikacji bloatware (Safe / Optional)
│   └── software.json         # Katalog 26 programów WinGet ze wzorcami detekcji rejestru
├── modules\
│   ├── GUI.psm1              # Logika okna WPF (event handling, live search, progress bar)
│   ├── Tweaks.psm1           # Silnik sprawdzania, wdrażania i wycofywania tweaków
│   ├── Apps.psm1             # Dwuetapowe usuwanie UWP z pre-flight process termination
│   ├── Software.psm1         # Hybrydowa detekcja rejestru i cicha instalacja WinGet
│   ├── Maintenance.psm1      # Moduł czyszczenia, naprawy SFC/DISM/WU oraz przełącznik DNS
│   ├── Privacy.psm1          # Konfiguracja rejestru i usług telemetrii
│   ├── UI.psm1               # Modyfikacje interfejsu Eksploratora i paska zadań
│   └── Core.psm1             # Narzędzia bazowe, logowanie i punkty przywracania
├── ui\
│   ├── MainWindow.xaml       # Layout interfejsu WPF (Obsidian Dark / Azure accent)
│   └── app_icon.png          # Wzorzec ikony aplikacji
├── launcher\
│   ├── Program.cs            # Kod źródłowy natywnego launchera ze splash screenem
│   ├── app.manifest          # Wbudowany manifest UAC (requireAdministrator)
│   ├── app.ico               # Wielorozdzielczy plik ikony (.ico)
│   ├── Compile.ps1           # Skrypt kompilacji przy użyciu wbudowanego csc.exe
│   └── Make-Icon.ps1         # Skrypt generujący pliki ikon
└── tests\
    ├── test_full_suite.ps1   # Kompleksowy test walidacyjny 10/10 krytycznych komponentów
    └── ensure_bom.ps1        # Weryfikacja kodowania UTF-8 z BOM
```

---

## 🔨 Samodzielna kompilacja launchera

Pliki wykonywalne nie wymagają instalowania Visual Studio, MSBuild ani zewnętrznych narzędzi. Kompilacja korzysta z kompilatora C# wbudowanego w każdy system Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\launcher\Compile.ps1
```

Skrypt uruchomi kompilator `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe`, połączy kod z manifestem UAC oraz ikoną i wygeneruje `OpenUnbloat.exe`.

---

## 🔒 Wymagania systemowe

* **System operacyjny:**
  * Windows 11 (wersje 21H2, 22H2, 23H2, 24H2 oraz **25H2**) — Home, Pro, Enterprise, Education
  * Windows 10 (wersje 2004, 20H2, 21H1, 21H2, 22H2 — kompilacja 19041+) — Home, Pro, Enterprise, Education
* **Środowisko:** Windows PowerShell 5.1 (wbudowany domyślnie) lub PowerShell 7+.
* **Uprawnienia:** Administrator (wymagane do modyfikacji rejestru HKLM i zarządzania usługami systemowymi).

---

## 📄 Licencja

Projekt jest udostępniany na zasadach otwartej licencji **[MIT](LICENSE)**. Możesz go dowolnie modyfikować, używać prywatnie i w środowiskach komercyjnych.
