#!/bin/bash
# Clona a API .NET e aplica o titulo da pagina. A API nao fica neste repositorio.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
API_DIR="${ROOT}/ClyvoVet"
API_REPO="${API_REPO:-https://github.com/EnzoVazz/ClyvoVet.git}"

if [ ! -d "${API_DIR}/.git" ]; then
  rm -rf "${API_DIR}"
  git clone --depth 1 "${API_REPO}" "${API_DIR}"
fi

cp -f "${ROOT}/overlay/AppInfo.cs" "${API_DIR}/ClyvoVet.Api/AppInfo.cs"
cp -f "${ROOT}/overlay/Program.cs" "${API_DIR}/ClyvoVet.Api/Program.cs"
cp -f "${ROOT}/overlay/AppInfoTests.cs" "${API_DIR}/ClyvoVet.UnitTests/AppInfoTests.cs"

CSPROJ="${API_DIR}/ClyvoVet.UnitTests/ClyvoVet.UnitTests.csproj"
if ! grep -q "ClyvoVet.Api.csproj" "${CSPROJ}"; then
  awk '
    /<\/Project>/ && !done {
      print "  <ItemGroup>"
      print "    <ProjectReference Include=\"..\\ClyvoVet.Api\\ClyvoVet.Api.csproj\" />"
      print "  </ItemGroup>"
      done = 1
    }
    { print }
  ' "${CSPROJ}" > "${CSPROJ}.tmp"
  mv "${CSPROJ}.tmp" "${CSPROJ}"
fi

echo "API pronta em ${API_DIR}"
