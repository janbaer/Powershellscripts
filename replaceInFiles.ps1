function replaceInFiles {
  param(
    [string] $filePattern,
    [string] $findWhat,
    [string] $replaceWith
  )

  $files = dir -recurse -include $filePattern

  ForEach ($file in $files) {
    Write-Host ("Editing {0}"  -f $file) -ForegroundColor Yellow
    (Get-Content $file) | % { $_ -replace $findWhat, $replaceWith } | Out-File -Encoding "UTF8" $file
  }

  Write-Host ("Finished with {0} files" -f $files.Count) -ForegroundColor Green
}
