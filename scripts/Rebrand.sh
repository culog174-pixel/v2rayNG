#!/usr/bin/env bash
# Uso: bash scripts/rebrand.sh com.tuempresa.tuvpn "Mi VPN"
# Ejecutar desde la raíz del repo clonado (v2rayNG).
set -euo pipefail

NEW_ID="${1:?Falta applicationId (ej: com.tuempresa.tuvpn)}"
NEW_NAME="${2:?Falta el nombre de la app (ej: Mi VPN)}"

# Validar applicationId
if ! [[ "$NEW_ID" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
  echo "applicationId inválido: $NEW_ID" >&2; exit 1
fi
# Evitar caracteres que rompan sed/XML
if [[ "$NEW_NAME" =~ [\<\>\&\#\\\"] ]]; then
  echo "El nombre no puede contener < > & # \\ \"" >&2; exit 1
fi

APP_DIR="V2rayNG/app"
[ -d "$APP_DIR" ] || APP_DIR="app"
[ -d "$APP_DIR" ] || { echo "No encuentro la carpeta app/" >&2; exit 1; }

# 1) applicationId (Groovy o Kotlin DSL). No toca applicationIdSuffix.
GRADLE=""
for f in "$APP_DIR/build.gradle.kts" "$APP_DIR/build.gradle"; do
  [ -f "$f" ] && GRADLE="$f" && break
done
[ -n "$GRADLE" ] || { echo "No encuentro build.gradle" >&2; exit 1; }

sed -i -E "s/(applicationId[[:space:]]*=?[[:space:]]*)\"[^\"]*\"/\1\"$NEW_ID\"/" "$GRADLE"
echo "applicationId -> $NEW_ID ($GRADLE)"

# 2) Nombre visible (todas las traducciones)
find "$APP_DIR/src" -path "*res/values*" -name "strings.xml" -print0 |
  xargs -0 sed -i -E "s#(<string name=\"app_name\"[^>]*>)[^<]*(</string>)#\1$NEW_NAME\2#"
echo "app_name -> $NEW_NAME"

# 3) Verificar minSdk (Android 6 = 23)
MIN=$(grep -E "minSdk" "$GRADLE" | grep -oE "[0-9]+" | head -n1 || true)
if [ -n "$MIN" ]; then
  if [ "$MIN" -le 23 ]; then
    echo "minSdk = $MIN (OK para Android 6)"
  else
    echo "ADVERTENCIA: minSdk = $MIN, no instalará en Android 6. Usa un tag anterior." >&2
    exit 1
  fi
else
  echo "No pude leer minSdk; revísalo a mano en $GRADLE" >&2
fi

# 4) Referencias a com.v2ray.ang en strings/xml que dependan del applicationId
grep -rIl "com\.v2ray\.ang" "$APP_DIR/src/main/res" 2>/dev/null \
  | sed 's/^/Revisar manualmente: /' || true

echo "Listo."
