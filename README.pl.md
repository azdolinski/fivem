# FiveM / RedM — obraz Docker

Minimalny obraz Docker dla [Cfx.re FXServer](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/) — uruchamia zarówno FiveM, jak i RedM z jednego obrazu, z przełączaniem przez zmienną środowiskową `GAME`.

Oparty na Alpine Linux z tini jako init PID 1. Wieloetapowy build utrzymuje mały rozmiar końcowego obrazu.

## Szybki start

```bash
docker run -d \
  --name fxserver \
  -e LICENSE_KEY=cfxk_twoj_klucz_tutaj \
  -e GAME=fivem \
  -p 30120:30120/tcp \
  -p 30120:30120/udp \
  -v fivem-config:/config \
  ghcr.io/azdolinski/fivem:latest
```

Lub z Docker Compose:

```bash
cp .env.example .env
# edytuj .env — ustaw LICENSE_KEY
docker compose up -d
```

## Tagi obrazu

Obrazy są publikowane w `ghcr.io/azdolinski/fivem` z trzema typami tagów:

| Tag | Przykład | Opis |
|-----|----------|------|
| Pełny build | `28108-2f3d20c4168282a17737970708ccc1524951483a` | Dokładna wersja artefaktu FXServer |
| Numer buildu | `28108` | Krótki tag wskazujący na ten sam obraz |
| `latest` | `latest` | Najnowszy dostępny build FiveM |

Wszystkie dostępne tagi znajdziesz na [stronie GitHub Packages](https://github.com/azdolinski/fivem/pkgs/container/fivem).

## Zmienne środowiskowe

| Zmienna | Domyślna | Opis |
|---------|----------|------|
| `GAME` | `fivem` | Gra: `fivem` lub `redm` |
| `LICENSE_KEY` | *(wymagana)* | Klucz licencji serwera z [portal.cfx.re](https://portal.cfx.re) |
| `SV_HOSTNAME` | `My FXServer` | Nazwa wyświetlana serwera |
| `SV_MAXCLIENTS` | `32` | Maksymalna liczba graczy |
| `SV_ENFORCE_GAME_BUILD` | FiveM: `3407` / RedM: `1491` | Wymuszenie konkretnej wersji klienta gry |
| `SV_ENDPOINT_PORT` | `30120` | Port gry (TCP + UDP) |
| `TXADMIN_PORT` | `40120` | Port interfejsu webowego txAdmin |
| `RCON_PASSWORD` | *(losowo generowane)* | Hasło RCON (losowe przy pierwszym uruchomieniu) |
| `NO_LICENSE_KEY` | | Ustaw, aby pominąć wstrzykiwanie klucza z env (klucz w server.cfg) |
| `NO_DEFAULT_CONFIG` | | Ustaw na `1`, aby pominąć auto-generowany server.cfg (dla txAdmin) |
| `EXTRA_ARGS` | | Dodatkowe argumenty linii poleceń FXServer |

## Wolumeny

| Ścieżka | Opis |
|---------|------|
| `/config` | Konfiguracja serwera, zasoby i server.cfg |
| `/txData` | Dane txAdmin (tylko z `NO_DEFAULT_CONFIG=1`) |

## Porty

| Port | Protokół | Opis |
|------|----------|------|
| `30120` | TCP + UDP | Ruch gry |
| `40120` | TCP | Interfejs webowy txAdmin (aktywny tylko z włączonym txAdmin) |

## txAdmin

Aby użyć txAdmin zamiast domyślnego server.cfg:

```bash
docker run -d \
  --name fxserver \
  -e LICENSE_KEY=cfxk_twoj_klucz_tutaj \
  -e NO_DEFAULT_CONFIG=1 \
  -p 30120:30120/tcp \
  -p 30120:30120/udp \
  -p 40120:40120/tcp \
  -v fivem-config:/config \
  -v fivem-txdata:/txData \
  ghcr.io/azdolinski/fivem:latest
```

Następnie otwórz `http://localhost:40120`, aby dokończyć konfigurację txAdmin.

## CI/CD

Dwa workflowy GitHub Actions automatyzują budowę obrazów:

- **Check** (`check.yml`) — Uruchamiany codziennie o 06:17 UTC. Pobiera dostępne buildy FiveM z Cfx.re i uruchamia budowę obrazów dla wersji recommended i latest.
- **Build** (`build.yml`) — Reużywalny workflow budujący i publikujący obraz Docker w GHCR. Pomija build, jeśli obraz już istnieje (chyba że `force: true`). Dostępny też jako `workflow_dispatch` do ręcznych buildów.

### Ręczny build

Możesz uruchomić build ręcznie z zakładki **Actions** na GitHubie:

1. Wybierz workflow **Build Docker Image**
2. Kliknij **Run workflow**
3. Wpisz ciąg buildu (np. `28108-2f3d20c4168282a17737970708ccc1524951483a`)
4. Przełącz **Also tag as latest** i **Force rebuild** według potrzeby

## Budowanie lokalne

```bash
docker build \
  --build-arg FXSERVER_VER=28108-2f3d20c4168282a17737970708ccc1524951483a \
  -t fivem:local .
```

## Licencja

To repozytorium zawiera tylko konfigurację Docker/build. Sam FXServer podlega regulaminowi Cfx.re.
