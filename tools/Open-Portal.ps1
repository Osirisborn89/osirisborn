param([string]$Route = "#/home")
$ts = Get-Date -Format "yyyyMMddHHmmss"
$u  = "http://127.0.0.1:7780/index.html?sw=off&bust=$ts$Route"
Start-Process $u
