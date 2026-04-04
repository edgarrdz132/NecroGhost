# NecroGhost 💀
### Anti-Ransomware Shield for Linux

```
.     .            +         .         .                 .  .
      .                 .                   .               .
              .    ,,o         .                  __.o+.
    .            od8^                  .      oo888888P^b           .
       .       ,".o'      .     .             `b^'""`b -`b   .
             ,'.'o'             .   .          t. = -`b -`t.    .
            ; d o' .        ___          _.--.. 8  -  `b  =`b
        .  dooo8<       .o:':__;o.     ,;;o88%%8bb - = `b  =`b.    .
    .     |^88^88=. .,x88/::/ | \`;;;;;;d%%%%%88%88888/%x88888
          :-88=88%%L8`%`|::|_>-<_||%;;%;8%%=;:::=%8;;\%%%%\8888
      .   |=88 88%%|HHHH|::| >-< |||;%;;8%%=;:::=%8;;;%%%%+|]88        .
          | 88-88%%LL.%.%b::Y_|_Y/%|;;;;`%8%%oo88%:o%.;;;;+|]88  .
          Yx88o88^^'"`^^%8boooood..-\H_Hd%P%%88%P^%%^'\;;;/%%88
         . `"\^\          ~"""""'      d%P """^" ;   = `+' - P
   .        `.`.b   .                       .   :  -   d' - P      . .
              .`.b     .        .    `      ,'-  = d' =.'
       .       ``.b.                           :..-  :'  P
            .   `q.>b         .               `^^^:::::,'       .


  [ ghost in the machine ] -- [ v1.0 ] -- [ ARMED ]
  [ unauthorized access will be traced ]
```

---

## ¿Qué es NecroGhost?

NecroGhost es un escudo de defensa contra ransomware para sistemas Linux. Monitorea tus directorios en tiempo real, crea honeypots inmutables, realiza backups automáticos firmados y activa un kill switch ante cualquier amenaza detectada.

---

## Características

- **Monitor en tiempo real** — Usa `inotifywait` para vigilar cambios en tus directorios
- **Detección de extensiones** — Más de 25 extensiones conocidas de ransomware detectadas
- **Detección de cambio masivo** — Alerta si más de 20 archivos cambian en menos de 10 segundos
- **Honeypots inmutables** — Archivos señuelo con `chattr +i` que ni root puede modificar
- **Backups automáticos** — Copias firmadas con SHA256 cada 10 minutos
- **Kill Switch** — Contención inmediata ante amenaza detectada
- **Logs de seguridad** — Registro completo en `/var/log/necroshield_ai.log`
- **Rutas absolutas** — Protección anti PATH-hijacking

---

## Requisitos

- Linux (Debian/Ubuntu recomendado)
- Bash 4+
- Permisos de root

### Dependencias

```bash
apt install inotify-tools e2fsprogs coreutils -y
```

---

## Instalación

```bash
# Clonar el repositorio
git clone https://github.com/tuusuario/necroghost.git
cd necroghost

# Dar permisos de ejecución
chmod +x necroghost.sh

# Mover a ruta global (opcional)
cp necroghost.sh /usr/local/bin/necroghost
```

---

## Uso

```bash
# Primera vez — configuración inicial
su -
necroghost setup

# Iniciar el monitor en background
necroghost start

# Ver estado del sistema
necroghost status

# Ver logs en tiempo real
tail -f /var/log/necroshield_ai.log

# Detener el monitor
necroghost stop
```

---

## ¿Cómo funciona?

### 1. Monitor en tiempo real
Vigila los directorios `Documentos`, `Descargas`, `Imágenes` y `Escritorio`. Si detecta una extensión sospechosa o un cambio masivo de archivos activa el Kill Switch.

### 2. Honeypots
Crea archivos señuelo con nombres tentadores como `contrasenas_banco.txt` o `backup_crypto_wallet.dat`. Son inmutables — si un ransomware los toca, alerta inmediata.

### 3. Backups firmados
Cada 10 minutos realiza un backup comprimido de tus directorios y lo firma con SHA256 para detectar manipulaciones. Mantiene los últimos 5 backups.

### 4. Kill Switch
Al detectar una amenaza:
- Alerta visual en terminal
- Notificación a todos los usuarios con `wall`
- Backup de emergencia inmediato
- Registro de procesos y conexiones de red activas

---

## Extensiones de ransomware detectadas

```
locked, encrypted, crypt, crypz, crypto, enc, aes,
zepto, cerber, locky, wnry, wncry, wcry, wncrypt,
petya, NotPetya, ryuk, maze, sodinokibi, revil,
conti, dharma, phobos, stop, djvu, pays
```

---

## Estructura de archivos

```
/var/log/necroshield_ai.log        — Log principal
/var/backups/necroshield_ai/       — Backups automáticos
/var/lib/necroshield_ai/honeypots/ — Archivos señuelo
/var/lib/necroshield_ai/backup.sha256 — Checksums
/var/run/necroshield_ai.pid        — PID del proceso
```

---

## Seguridad del script

- Todas las rutas son absolutas (anti PATH-hijacking)
- Logs en modo append-only (`chattr +a`)
- Honeypots inmutables (`chattr +i`)
- Backups firmados con SHA256
- Validación estricta de variables (`set -euo pipefail`)
- Solo ejecutable por root

---

## Advertencia

NecroGhost es una herramienta de **detección temprana**. No elimina ransomware, pero lo detecta en segundos y protege tus archivos antes de que cifre todo. Ante una detección real, desconecta el equipo de la red e investiga el log.

---

## Licencia

MIT License — libre para usar, modificar y distribuir.

---

## Autor

**NecroGhost Security**
> *ghost in the machine*
