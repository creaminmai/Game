#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
editor="${UNITY_EDITOR_CONTENTS:-/Applications/Unity/Hub/Editor/6000.6.9f1/Unity.app/Contents}"
sdk="$editor/Resources/Scripting/DotNetSdk"
work="$(mktemp -d /tmp/haetsal-tests.XXXXXX)"
trap 'rm -rf "$work"' EXIT
refs=()
for dll in "$sdk"/packs/Microsoft.NETCore.App.Ref/*/ref/net8.0/*.dll; do
  refs+=("-r:$dll")
done
for compiler in "$sdk"/sdk/*/Roslyn/bincore/csc.dll; do
  break
done
sources=(unity/Assets/Scripts/PatientVisit.cs unity/Assets/Scripts/DayRoutes.cs unity/Assets/Scripts/HospitalSave.cs unity/Assets/Scripts/HospitalNetwork.cs unity/Assets/Scripts/HospitalDay.StaffResearch.cs unity/Assets/Scripts/HospitalDay.Guide.cs tools/test-unity-hospital.cs tools/test-unity-hospital-save.cs)
"$sdk/dotnet" "$compiler" -nologo -noconfig -nostdlib -warnaserror "${refs[@]}" "-out:$work/HospitalChecks.dll" "${sources[@]}"
printf '%s\n' '{"runtimeOptions":{"tfm":"net8.0","framework":{"name":"Microsoft.NETCore.App","version":"8.0.0"}}}' > "$work/HospitalChecks.runtimeconfig.json"
"$sdk/dotnet" "$work/HospitalChecks.dll"
