function replaceInFiles {
  param(
    [Property (Mandatory=$true)][string] $filePattern,
    [Property (Mandatory=$true)][string] $findWhat,
    [Property (Mandatory=$true)][string] $replaceWith
  )

  $files = dir -recurse -include $filePattern | Select-String -SimpleMatch $findWhat | select -unique path | select -ExpandProperty path

  ForEach ($file in $files) {
    Write-Host ("Editing {0}"  -f $file) -ForegroundColor Yellow
    (Get-Content ($file)) | % { $_ -replace $findWhat, $replaceWith } | Out-File -Encoding "UTF8" -FilePath $file
  }
  Write-Host ("Finished with {0} files" -f $files.Count) -ForegroundColor Green
