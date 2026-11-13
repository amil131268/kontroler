# Kontroler 0.1

Przenośny program dla serwisanta drukarek na Windows 10 i 11. Interfejs po polsku, bez instalacji i zewnętrznych bibliotek. Wykorzystuje wbudowany Windows PowerShell 5.1 i Windows Forms. To wersja skryptowa, nie pojedynczy plik EXE.

## Uruchomienie

1. Skopiuj cały rozpakowany folder na komputer Windows lub pendrive.
2. Otwórz `Uruchom.cmd` dwuklikiem.
3. Wybierz drukarkę. Po zmianach użyj „Odśwież”.

Nie trzeba uruchamiać jako administrator. Ograniczenia dostępu są sygnalizowane w raporcie. Polityka firmowa może zablokować skrypty; plik startowy ustawia ExecutionPolicy Bypass wyłącznie dla uruchomionego procesu, bez zmiany ustawień systemowych. Program nie wymaga internetu.

## Funkcje

- Wszystkie drukarki widoczne dla bieżącego użytkownika, także sieciowe i wirtualne.
- Drukarka domyślna, port i rozpoznanie USB według nazwy portu USBxxx.
- Nazwa sterownika i wersja jego pliku, jeśli dostępna (nie numer modelu sterownika v3/v4).
- Status Windows, offline, wstrzymanie, zgłoszone błędy papieru/tonera i stan bufora.
- Kolejka i zgłaszane błędy zadań.
- Raport TXT UTF-8 ze wszystkimi drukarkami, czasem odczytu i błędami dostępu.
- Strona testowa Windows po wybraniu drukarki i potwierdzeniu. Powodzenie żądania oznacza przekazanie go do Windows, nie potwierdzenie fizycznego wydruku.

Raport zawiera nazwę komputera, użytkownika i dokumentów w kolejce. Wybierasz miejsce jego zapisu. Oprócz zlecenia strony testowej program nie zmienia ustawień, nie usuwa zadań i nie restartuje usług.

## Ograniczenia pierwszej wersji

Status zależy od sterownika. Brak zgłoszonego błędu nie dowodzi sprawności drukarki. Zainstalowany port USB nie potwierdza podłączenia kabla. Nie wszystkie urządzenia USB korzystają z portu o nazwie USBxxx — inne porty mogą pozostać nierozpoznane. Brak dostępnej informacji jest oznaczany jako niepełna diagnostyka. Domyślna drukarka dotyczy konta uruchamiającego program.

Odczyt działa w tle z limitem 90 sekund. Wysyłanie strony testowej może na krótko zablokować okno podczas odpowiedzi Windows.

## Weryfikacja

W Windows, z folderu projektu:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Sprawdz.ps1
```

Test sprawdza składnię oraz diagnostykę na kontrolowanych danych: USB, drukarka domyślna, offline i zadanie z błędem, przecinek w nazwie drukarki, brak drukarek i błędy dostępu. Nie wysyła wydruków.

Przed użyciem serwisowym sprawdź ręcznie na Windows 10 i 11: start z pendrive’a, brak drukarek, drukarkę USB podłączoną i odłączoną, kolejkę wstrzymaną, zatrzymany bufor, raport z polskimi znakami oraz fizyczny wydruk strony testowej. Testuj zmiany usług i kolejek wyłącznie na stanowisku testowym.

Wersja powstała w środowisku Linux bez Windows PowerShell. Nie wykonano tu testów Windows, interfejsu ani rzeczywistej drukarki.

## Źródła interfejsów Windows

- [Win32_Printer — pola statusu i metoda PrintTestPage](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-printer)
- [Win32_PrinterDriver](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-printerdriver)
