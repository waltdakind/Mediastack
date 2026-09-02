$containers = docker ps --format "{{.Names}}"
foreach ($c in $containers) {
    $nets = docker inspect $c --format "{{range `$k, `$v := .NetworkSettings.Networks}}{{`$k}} {{end}}"
    Write-Host ("{0,-45} : {1}" -f $c, $nets)
}
